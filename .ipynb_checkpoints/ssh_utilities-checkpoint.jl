include("julia_utilities.jl")
usingpkg("RemoteFiles, OpenSSH_jll")

# Username and host for ssh connection
# the host is the remote server name, I added the '@' for simplicity
username = "dumoulil"; host ="@baobab2.hpc.unige.ch"
cluster_home_path = "/home/users/$(username[1])/$username/"

local_utilities_path = normpath(string(@__DIR__,"/"))

# Little function to execute a commande using SSh on the cluster
@inline function run_ssh(cmd)
    return run(`ssh $username$host $cmd`)
end
# Same but return consol as a string
@inline function ssh(cmd)
    return readchomp(`ssh $username$host $cmd`)
end
# Same but print result
@inline function print_ssh(cmd)
    println(readchomp(`ssh $username$host $cmd`))
end

@inline function print_ssh_squeue(; username=username, opt="")
    print_ssh("squeue -u "*string(username)*string(" ",opt))
end

@inline function ssh_squeue(; username=username, opt="")
    ssh("squeue -u "*string(username)*string(" ",opt))
end

@inline function ssh_scancel(num)
    println(ssh("scancel "*string(num)))
end

@inline function scp_down(cluster_file_path, local_directory_path)
    run(`scp -r $username$host:$cluster_file_path $local_directory_path`)
end

@inline function scp_up(cluster_directory_path, local_file_path)
    run(`scp -r $local_file_path $username$host:$cluster_directory_path`)
end

@inline function scp_up_dir(cluster_directory_path, local_directory_path)
    run(`scp """$local_directory_path""""*" $username$host:$cluster_directory_path`)
end

@inline function scp_up_jl(cluster_directory_path, local_directory_path)
    if Sys.isapple()
        scp_up_jl_MOS(cluster_directory_path, local_directory_path)
    else
        run(`scp """$local_directory_path""""*.jl" $username$host:$cluster_directory_path`)
    end
end

@inline function scp_up_jl_MOS(cluster_directory_path, local_directory_path)
    run(`scp """$local_directory_path""""\*.jl" $username$host:$cluster_directory_path`)
end

@inline function scp_up_file(cluster_directory_path, local_file_path)
    run(`scp $local_file_path $username$host:$cluster_directory_path`)
end

@inline function ssh_mkdir(cluster_directory_path)
    if ssh("test -d $cluster_directory_path  && echo true || test ! -d $cluster_directory_path") == "true"
        println("$cluster_directory_path exists")
    else
        ssh("mkdir -p $cluster_directory_path")
        println("Create $cluster_directory_path")
    end
end

# @inline function create_dir(cluster_directory_path)
#     print_ssh("mkdir -p $cluster_directory_path")
# end

@inline function ssh_getjobids()
    jobIDs=[]
    for i in split(ssh_squeue(), keepempty=false)
        if length(string(i)) > 6
            b = tryparse(Int, string(i))
            b != nothing ? append!(jobIDs, b) :  nothing
        end
    end
    return jobIDs
end

@inline function ssh_findfile(filename, cluster_directory_path)
    return ssh("find $cluster_directory_path -name $filename")
end

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

# Fonction that update file(s) of a specific ext (".something" file(s)) 
# of your local dir if the file on the cluster is different (in size)
function ssh_update_ext(cluster_directory_path, local_directory_path, ext=".out")
    list_of_filenames = filter!(x->endswith(x, ext), split(ssh("ls $cluster_directory_path"), "\n", keepempty=false) )
    for filename in list_of_filenames
       if filesize(local_directory_path*filename) != tryparse(Int, readchomp(`ssh $username$host stat --printf="%s" $(cluster_directory_path*filename)`))
            println(" update $username$host:$(cluster_directory_path*filename) to $(local_directory_path*filename)")
            run(`scp -r $username$host:$(cluster_directory_path*filename) $local_directory_path`)
        end
    end
end

@inline function ssh_update_file(filename, cluster_directory_path, local_directory_path)
    if fn != "" && ssh_filesize(cluster_directory_path*filename) != filesize(local_directory_path*filename)
        println("update $username$host:$(cluster_directory_path*filename) to $(local_directory_path*filename)")
        scp_down(cluster_directory_path*filename, local_directory_path)
    end
end

# Recursive function that download files of cluster directory (cdir) on your computer (ldir)
# Only if the files on the computer do not exist
function ssh_download_dir(cluster_directory_path, local_directory_path)
    isfile(local_directory_path[1:end-1]) && return nothing
    isdir(local_directory_path) ? nothing : mkpath(local_directory_path)
    list_of_local_subdirectories = readdir(local_directory_path)
    list_of_subdirectories = split(ssh("ls $cluster_directory_path"), "\n", keepempty=false)
    for subdirectory in list_of_subdirectories #Threads.@threads 
        o = findfirst(subdirectory .== list_of_local_subdirectories)
        if o == nothing
            # isdefined(Main, :IJulia) ? IJulia.clear_output(true) : nothing
            # println("Thread $(Threads.threadid()) copy $username$host:$cluster_directory_path$subdirectory into $local_directory_path")
            println(" Copy $username$host:$cluster_directory_path$subdirectory into $local_directory_path")
            run(`scp -r $username$host:$cluster_directory_path$subdirectory $local_directory_path`)
        else
            download_dir(cluster_directory_path*subdirectory*"/", local_directory_path*subdirectory*"/")
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

function ssh_history_IDs()
    today = string(Dates.today() - Dates.Month(1))
    jobIDs = Vector{Int}()
    for i in split(ssh("sacct -S $today -u $username --format=JobID"), keepempty=false)
        b = tryparse(Int, i)
        !isnothing(b) ? push!(jobIDs, b) : nothing
    end
    return jobIDs
end

function ssh_readout(jobID)
    pathout = ssh_getpathout(jobID)
    # dircl, fn = splitpath(pathout)
    pathout == "" ? nothing : print_ssh("cat $pathout")
end

function ssh_readlastout()
    jobid = ssh_history_IDs()[end]
    ssh_readout(jobid)
end

function ssh_readlastout(inc)
    jobid = ssh_history_IDs()[end+inc]
    ssh_readout(jobid)
end

@inline function ssh_readlastlineout(jobID::Int)
    pathout = ssh_findfile(string(jobID,".out"), cluster_home_path)
    return split(ssh("cat $pathout"), "\n", keepempty=false)[end]
end

@inline function ssh_getpathout(jobID)
    pathout = split(ssh("sacct -j$jobID -u $username --format=WorkDir%100 -n"), keepempty=false)[1]*"/$jobID.out"
    if ssh_filesize(pathout) == 0
        println("No .out file")
        return ""
    else
        return pathout
    end
end

@inline function ssh_getpathoutrunning(jobID)
    return splitpath(ssh_squeue(opt="-j$jobID --Format=STDOUT:100 -h"))[1]
end

@inline function ssh_readlastlineout(pathout::String)
    return split(ssh("cat $pathout"), "\n", keepempty=false)[end]
end

function ssh_info_gpus()
    print_ssh("squeue --nodes=gpu[020-022,027-031]")
end

function ssh_info_gpus_kruse()
    print_ssh("squeue --nodes=gpu[020,030-031]")
end

function ssh_get_history_fout()
    today = string(Dates.today() - Dates.Month(1))
    st = filter!(x->(!endswith(x,"+") && !endswith(x,".0")),split(ssh("sacct -S $today -u $username --format=JobID,WorkDir%100 -n"), keepempty=false))
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
    filter!(endswith(".out"), pathout)
    return jobs, pathout
end

function ssh_disk(user=username)
    print_ssh("beegfs-get-quota-home-scratch.sh $user")
end