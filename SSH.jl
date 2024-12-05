include("using.jl")
using_pkg("RemoteFiles, OpenSSH_jll")
using_mod(".JulUtils")

module SSH
export ssh, run_ssh, ssh_print, cluster_home_path, local_utilities_path, username, host, cluster_scratch_path

include("ssh_login.jl")
const cluster_home_path = "/home/users/$(username[1])/$username/"
const cluster_scratch_path = "/srv/beegfs/scratch/users/$(username[1])/$username/"

const local_utilities_path = normpath(string(@__DIR__,"/"))

# Little function to execute a commande using SSH on the cluster
@inline run_ssh(cmd) = run(`ssh $username$host $cmd`)
# Same but return consol as a string
@inline ssh(cmd) = readchomp(`ssh $username$host $cmd`)
# Same but print result
@inline ssh_print(cmd) =  println(ssh(cmd))


############### File Managment ###############
module File
using ..SSH

@inline readdir(cluster_directory_path) = split(ssh("ls $cluster_directory_path"), "\n", keepempty=false)

@inline findfile(filename, cluster_directory_path) = ssh("find $cluster_directory_path -name $filename")

@inline function isfile(cluster_file_path)
    local answ;
    try
        answ = ssh("""[[ -f $cluster_file_path ]] && echo "1" || echo "0" """)
    catch
        answ = "Issue"
    end
    answ == "1" ? (return true) : nothing
    if answ == "0"
        return false
    else 
        println(" ERROR while looking for $cluster_file_path")
        return false
    end
end

@inline function isdir(dir_name)
    full_path = cluster_home_path*dir_name
    full_path *= endswith("/", full_path) ? "" : "/"
    local answ;
    try
        answ = ssh(""" [ -d $full_path ]  && echo "1" || echo "0" """)
    catch
        answ = "Issue"
    end
    answ == "1" ? (return true) : nothing
    if answ == "0"
        return false
    else 
        println(" ERROR while looking for $full_path")
        return false
    end
end

@inline function filesize(cluster_file_path)
    try
        return tryparse(Int, ssh(`stat --printf="%s" $cluster_file_path`))
    catch
        return 0
    end
end

@inline function mkdir(cluster_directory_path)
    if ssh("test -d $cluster_directory_path  && echo true || test ! -d $cluster_directory_path") == "true"
        println("$cluster_directory_path exists")
    else
        ssh("mkdir -p $cluster_directory_path")
        println("Create $cluster_directory_path")
    end
end
end

############### Get informations ###############
module Get
using ..SSH, .SSH.File, ...JulUtils, Dates
@inline squeue(; username=username, opt="") = ssh("squeue -u "*string(username)*string(" ",opt))

@inline function jobids()
    jobIDs=[]
    for i in split(squeue(opt="--Format JobID"), keepempty=false)
        if length(string(i)) > 4
            b = tryparse(Int, string(i))
            b != nothing ? append!(jobIDs, b) :  nothing
        end
    end
    return jobIDs
end

function histjobids()
    today = string(Dates.today() - Dates.Month(1))
    jobIDs = Vector{Int}()
    for i in split(ssh("sacct -S $today -u $username --format=JobIDRaw"), keepempty=false)
        b = tryparse(Int, i)
        !isnothing(b) ? push!(jobIDs, b) : nothing
    end
    return jobIDs
end

@inline function pathout(jobID)
    path = split(ssh("sacct -j$jobID -u $username --format=WorkDir%100 -n"), keepempty=false)[1]*"/$jobID.out"
    if File.filesize(path) == 0
        println("No .out file")
        return ""
    else
        return path
    end
end

@inline function pathoutrunning(jobID)
    return JulUtils.splitpath(squeue(opt="-j$jobID --Format=STDOUT:100 -h"))[1]
end

function histout()
    today = string(Dates.today() - Dates.Month(1))
    st = filter!(x->(!endswith(x,"+") && !endswith(x,".0")), split(ssh("sacct -S $today -u $username --format=JobID,WorkDir%100 -n"), keepempty=false))
    jobs = st[1:2:end]
    pathout = st[2:2:end]
    # check if .out exists
    for i=1:length(jobs)
        path_out = string(pathout[i])*"/"*string(jobs[i])*".out"
        if File.filesize(path_out)!=0
            pathout[i] = path_out
        else 
            jobs[i]="0"
        end
    end
    filter!(x-> x!="0", jobs)
    filter_ext!(pathout, ".out")
    return jobs, pathout
end

@inline lastlineout(pathout::String) = split(ssh("cat $pathout"), "\n", keepempty=false)[end]

@inline function lastlineout(jobID::Int)
    pathout = File.findfile(string(jobID,".out"), cluster_home_path)
    return lastlineout(pathout)
end
end

############### Print informations ###############
module Print
export quota, infogpus, seff, squeue, scancel, out, lastout, get_list_nodes, infonodes
using ..SSH, .SSH.Get

quota(user=SSH.username) = ssh_print("beegfs-get-quota-home-scratch.sh $user")

squeue(; username=SSH.username, opt="") = ssh_print("squeue -u "*string(username)*string(" ",opt))
seff(jobID) = ssh_print("seff $jobID")

scancel(num) = ssh_print("scancel "*string(num))

function get_list_nodes(constraints=["AMPERE","DOUBLE","CAPABILITY_8"])
    lnodes = split(SSH.ssh("""sinfo --Format nodehost:20,features_act:80 |grep -v '(null)' |awk 'NR == 1; NR > 1 {print \$0 | "sort -n"}'"""), "\n", keepempty=false)
    res = ""
    for i in lnodes
        sum(Int.([occursin(j, i) for j in constraints])) == length(constraints) ? (res*= length(res)>0 ? string(",",split(i)[1]) : string(split(i)[1]) ) : nothing
    end
    return res
end

infonodes(constraints=["AMPERE","DOUBLE","CAPABILITY_8"]) = ssh_print(string("squeue --nodes=",get_list_nodes(constraints)))
infogpus(constraints=["AMPERE","DOUBLE","CAPABILITY_8"]) = ssh_print(string("squeue --nodes=",get_list_nodes(constraints)))

function out(jobID)
    path = Get.pathout(jobID)
    path == "" ? nothing : ssh_print("cat $path")
end

lastout() = out(Get.histjobids()[end])

function lastout(inc)
    hist = Get.histjobids()
    l_hist = length(hist)
    inc > 0 ? inc *= -1 : nothing
    if -inc < l_hist
        println("Print the $(l_hist+inc)th (last $inc) job: JobID = $(hist[end+inc])")
        out(hist[end+inc])
    else
        println("Error: Trying to access to the $(l_hist+inc)th job")
    end
end
end


############### Download/upload ###############
module SCP
using ..SSH, .SSH.File, ...JulUtils

@inline down(cluster_file_path, local_directory_path) = run(`scp -r $username$host:$cluster_file_path $local_directory_path`)

@inline up(cluster_directory_path, local_file_path) = run(`scp -r $local_file_path $username$host:$cluster_directory_path`)

@inline up_dir(cluster_directory_path, local_directory_path) = run(`scp """$local_directory_path""""*" $username$host:$cluster_directory_path`)

@inline up_file(cluster_directory_path, local_file_path) = run(`scp $local_file_path $username$host:$cluster_directory_path`)

@inline function up_ext(cluster_directory_path, local_directory_path, ext)
    for i in filter_ext!(readdir(local_directory_path), ext)
        up_file(cluster_directory_path, local_directory_path*i)
    end
end

@inline up_jl(cluster_directory_path, local_directory_path) = up_ext(cluster_directory_path, local_directory_path, ".jl")

@inline function update_file(filename, cluster_directory_path, local_directory_path)
    if filename != "" && File.filesize(cluster_directory_path*filename) != filesize(local_directory_path*filename)
        println(" update $username$host:$(cluster_directory_path*filename) to $(local_directory_path*filename)")
        down(cluster_directory_path*filename, local_directory_path)
    end
end

# Fonction that update file(s) of a specific ext (".something" file(s)) 
# of your local dir if the file on the cluster is different (in size)
function update_ext(cluster_directory_path, local_directory_path, ext=".out")
    for filename in filter_ext!(File.readdir(cluster_directory_path), ext)
       update_file(filename, cluster_directory_path, local_directory_path)
    end
end

# Recursive function that download files of cluster directory (cdir) on your computer (ldir)
# Only if the files on the computer do not exist
function download_dir(cluster_directory_path, local_directory_path)
    isfile(local_directory_path[1:end-1]) && return nothing
    isdir(local_directory_path) ? nothing : mkpath(local_directory_path)
    list_of_local_subdirectories = readdir(local_directory_path)
    list_of_subdirectories = File.readdir(cluster_directory_path)
    for subdirectory in list_of_subdirectories
        o = findfirst(subdirectory .== list_of_local_subdirectories)
        if o == nothing
            println(" Copy $username$host:$cluster_directory_path$subdirectory into $local_directory_path")
            down(cluster_directory_path*subdirectory, local_directory_path)
        else
            download_dir(cluster_directory_path*subdirectory*"/", local_directory_path*subdirectory*"/")
        end
    end
end

# Call download_dir and upate_ext for specific extension
# This function needs to be edited according to your need
function download(cluster_directory, local_directory_path)
    cluster_directory_path = (startswith(cluster_directory, "/home/") || startswith(cluster_directory, "/srv")) ? cluster_directory : cluster_home_path*cluster_directory
    println("Download $cluster_directory_path into $local_directory_path")
    mkpath(local_directory_path)
    update_ext(cluster_directory_path, local_directory_path, ".csv")
    update_ext(cluster_directory_path, local_directory_path, ".out")
    download_dir(cluster_directory_path, local_directory_path)
end
end
end
