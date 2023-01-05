include("julia_utilities.jl")
usingpkg("RemoteFiles, OpenSSH_jll")

include("ssh_login.jl")
cluster_home_path = "/home/users/$(username[1])/$username/"

local_utilities_path = normpath(string(@__DIR__,"/"))

# Little function to execute a commande using SSH on the cluster
@inline run_ssh(cmd) = run(`ssh $username$host $cmd`)
# Same but return consol as a string
@inline ssh(cmd) = readchomp(`ssh $username$host $cmd`)
# Same but print result
@inline ssh_print(cmd) =  println(ssh(cmd))

############### Useful command ###############
ssh_print_infogpus() = ssh_print("squeue --nodes=gpu[020-022,027-031]")
ssh_print_quota(user=username) = ssh_print("beegfs-get-quota-home-scratch.sh $user")

ssh_print_squeue(; username=username, opt="") = ssh_print("squeue -u "*string(username)*string(" ",opt))
ssh_print_seff(jobID) = ssh_print("seff $jobID")

ssh_scancel(num) = ssh_print("scancel "*string(num))

function ssh_print_out(jobID)
    pathout = ssh_get_pathout(jobID)
    pathout == "" ? nothing : ssh_print("cat $pathout")
end

ssh_print_lastout() = ssh_print_out(ssh_get_histjobids()[end])

function ssh_print_lastout(inc)
    hist = ssh_get_histjobids()
    l_hist = length(hist)
    inc > 0 ? inc *= -1 : nothing
    if -inc < l_hist
        println("Print the $(l_hist+inc)th (last $inc) job: JobID = $(hist[end+inc])")
        ssh_print_out(hist[end+inc])
    else
        println("Error: Trying to access to the $(l_hist+inc)th job")
    end
end

############### File Managment ###############
@inline ssh_readdir(cluster_directory_path) = split(ssh("ls $cluster_directory_path"), "\n", keepempty=false)

@inline ssh_findfile(filename, cluster_directory_path) = ssh("find $cluster_directory_path -name $filename")

@inline function ssh_isfile(cluster_file_path)
    try
        return ssh("""[[ -f $cluster_file_path ]] && echo "1" || echo "0" """)
    catch
        return "Issue"
    end
end

@inline function ssh_filesize(cluster_file_path)
    try
        return tryparse(Int, ssh(`stat --printf="%s" $cluster_file_path`))
    catch
        return 0
    end
end

@inline function ssh_mkdir(cluster_directory_path)
    if ssh("test -d $cluster_directory_path  && echo true || test ! -d $cluster_directory_path") == "true"
        println("$cluster_directory_path exists")
    else
        ssh("mkdir -p $cluster_directory_path")
        println("Create $cluster_directory_path")
    end
end

############### GET JobID ###############
@inline ssh_squeue(; username=username, opt="") = ssh("squeue -u "*string(username)*string(" ",opt))

@inline function ssh_get_jobids()
    jobIDs=[]
    for i in split(ssh_squeue(opt="--Format JobID"), keepempty=false)
        if length(string(i)) > 6
            b = tryparse(Int, string(i))
            b != nothing ? append!(jobIDs, b) :  nothing
        end
    end
    return jobIDs
end

function ssh_get_histjobids()
    today = string(Dates.today() - Dates.Month(1))
    jobIDs = Vector{Int}()
    for i in split(ssh("sacct -S $today -u $username --format=JobIDRaw"), keepempty=false)
        b = tryparse(Int, i)
        !isnothing(b) ? push!(jobIDs, b) : nothing
    end
    return jobIDs
end

############### GET .OUT ###############
@inline function ssh_get_pathout(jobID)
    pathout = split(ssh("sacct -j$jobID -u $username --format=WorkDir%100 -n"), keepempty=false)[1]*"/$jobID.out"
    if ssh_filesize(pathout) == 0
        println("No .out file")
        return ""
    else
        return pathout
    end
end

@inline function ssh_get_pathoutrunning(jobID)
    return splitpath(ssh_squeue(opt="-j$jobID --Format=STDOUT:100 -h"))[1]
end

function ssh_get_histout()
    today = string(Dates.today() - Dates.Month(1))
    st = filter!(x->(!endswith(x,"+") && !endswith(x,".0")), split(ssh("sacct -S $today -u $username --format=JobID,WorkDir%100 -n"), keepempty=false))
    jobs = st[1:2:end]
    pathout = st[2:2:end]
    # check if .out exists
    for i=1:length(jobs)
        path_out = string(pathout[i])*"/"*string(jobs[i])*".out"
        if ssh_filesize(path_out)!=0
            pathout[i] = path_out
        else 
            jobs[i]="0"
        end
    end
    filter!(x-> x!="0", jobs)
    filter_ext!(pathout, ".out")
    return jobs, pathout
end

@inline ssh_get_lastlineout(pathout::String) = split(ssh("cat $pathout"), "\n", keepempty=false)[end]

@inline function ssh_get_lastlineout(jobID::Int)
    pathout = ssh_findfile(string(jobID,".out"), cluster_home_path)
    return ssh_get_lastlineout(pathout)
end

############### Download/upload ###############
@inline scp_down(cluster_file_path, local_directory_path) = run(`scp -r $username$host:$cluster_file_path $local_directory_path`)

@inline scp_up(cluster_directory_path, local_file_path) = run(`scp -r $local_file_path $username$host:$cluster_directory_path`)

@inline scp_up_dir(cluster_directory_path, local_directory_path) = run(`scp """$local_directory_path""""*" $username$host:$cluster_directory_path`)

@inline scp_up_file(cluster_directory_path, local_file_path) = run(`scp $local_file_path $username$host:$cluster_directory_path`)

@inline function scp_up_ext(cluster_directory_path, local_directory_path, ext)
    for i in filter_ext!(readdir(local_directory_path), ext)
        scp_up_file(cluster_directory_path, local_directory_path*i)
    end
end

@inline scp_up_jl(cluster_directory_path, local_directory_path) = scp_up_ext(cluster_directory_path, local_directory_path, ".jl")

@inline function ssh_update_file(filename, cluster_directory_path, local_directory_path)
    if filename != "" && ssh_filesize(cluster_directory_path*filename) != filesize(local_directory_path*filename)
        println(" update $username$host:$(cluster_directory_path*filename) to $(local_directory_path*filename)")
        scp_down(cluster_directory_path*filename, local_directory_path)
    end
end

# Fonction that update file(s) of a specific ext (".something" file(s)) 
# of your local dir if the file on the cluster is different (in size)
function ssh_update_ext(cluster_directory_path, local_directory_path, ext=".out")
    for filename in filter_ext!(ssh_readdir(cluster_directory_path), ext)
       ssh_update_file(filename, cluster_directory_path, local_directory_path)
    end
end

# Recursive function that download files of cluster directory (cdir) on your computer (ldir)
# Only if the files on the computer do not exist
function ssh_download_dir(cluster_directory_path, local_directory_path)
    isfile(local_directory_path[1:end-1]) && return nothing
    isdir(local_directory_path) ? nothing : mkpath(local_directory_path)
    list_of_local_subdirectories = readdir(local_directory_path)
    list_of_subdirectories = ssh_readdir(cluster_directory_path)
    for subdirectory in list_of_subdirectories
        o = findfirst(subdirectory .== list_of_local_subdirectories)
        if o == nothing
            println(" Copy $username$host:$cluster_directory_path$subdirectory into $local_directory_path")
            scp_down(cluster_directory_path*subdirectory, local_directory_path)
        else
            ssh_download_dir(cluster_directory_path*subdirectory*"/", local_directory_path*subdirectory*"/")
        end
    end
end

# Call download_dir and upate_ext for specific extension
# This function needs to be edited according to your need
function ssh_download(cluster_directory="test/", local_directory_path="E:/test/")
    cluster_directory_path = cluster_directory[1:4] == "/hom" ? cluster_directory : cluster_home_path*cluster_directory
    println("Download $cluster_directory_path into $local_directory_path")
    mkpath(local_directory_path)
    ssh_update_ext(cluster_directory_path, local_directory_path, ".csv")
    ssh_update_ext(cluster_directory_path, local_directory_path, ".out")
    ssh_download_dir(cluster_directory_path, local_directory_path)
end