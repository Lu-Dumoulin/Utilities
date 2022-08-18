include("julia_utilities.jl")
usingpkg("RemoteFiles, OpenSSH_jll")

# Username and host for ssh connection
# the host is the remote server name, I added the '@' for simplicity
username = "dumoulil"; host ="@baobab2.hpc.unige.ch"
cluster_home_path = "/home/users/$(username[1])/$username/"

local_utilities_path = normpath(string(@__DIR__,"/"))

# Little function to execute a commande using SSh on the cluster
@inline function runssh(cmd)
    return run(`ssh $username$host $cmd`)
end
# Same but return consol as a string
@inline function ssh(cmd)
    return readchomp(`ssh $username$host $cmd`)
end
# Same but print result
@inline function printssh(cmd)
    println(readchomp(`ssh $username$host $cmd`))
end

@inline function squeue(; username=username)
    printssh("squeue -u "*string(username))
end

@inline function rsqueue(; username=username)
    ssh("squeue -u "*string(username))
end

@inline function scancel(num)
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
    run(`scp """$local_directory_path""""*.jl" $username$host:$cluster_directory_path`)
end

@inline function scp_up_file(cluster_directory_path, local_file_path)
    run(`scp $local_file_path $username$host:$cluster_directory_path`)
end

@inline function ssh_create_dir(cluster_directory_path)
    if ssh("test -d $cluster_directory_path  && echo true || test ! -d $cluster_directory_path") == "true"
        println("$cluster_directory_path exists")
    else
        ssh("mkdir -p $cluster_directory_path")
        println("Create $cluster_directory_path")
    end
end

@inline function create_dir(cluster_directory_path)
    printssh("mkdir -p $cluster_directory_path")
end

@inline function getjobids()
    jobIDs=[]
    for i in split(rsqueue(), keepempty=false)
        if length(string(i)) > 6
            b = tryparse(Int, string(i))
            b != nothing ? append!(jobIDs, b) :  nothing
        end
    end
    return jobIDs
end

@inline function findfile(filename, cluster_directory_path)
    return ssh("find $cluster_directory_path -name $filename")
end

@inline function get_size(cluster_file_path)
    try
        return tryparse(Int, ssh(`stat --printf="%s" $cluster_file_path`))
    catch
        return 0
    end
end

# Fonction that update file(s) of a specific ext (".something" file(s)) 
# of your local dir if the file on the cluster is different (in size)
function update_ext(cluster_directory_path, local_directory_path, ext=".out")
    list_of_filenames = filter!(x->endswith(x, ext), split(ssh("ls $cluster_directory_path"), "\n", keepempty=false) )
    for filename in list_of_filenames
       if filesize(local_directory_path*filename) != tryparse(Int, readchomp(`ssh $username$host stat --printf="%s" $(cluster_directory_path*filename)`))
            println("update $username$host:$(cluster_directory_path*filename) to $(local_directory_path*filename)")
            run(`scp -r $username$host:$(cluster_directory_path*filename) $local_directory_path`)
        end
    end
end

@inline function update_file(filename, cluster_directory_path, local_directory_path)
    if fn != "" && get_size(cluster_directory_path*filename) != filesize(local_directory_path*filename)
        println("update $username$host:$(cluster_directory_path*filename) to $(local_directory_path*filename)")
        scp_down(cluster_directory_path*filename, local_directory_path)
    end
end

# Recursive function that download files of cluster directory (cdir) on your computer (ldir)
# Only if the files on the computer do not exist
function download_dir(cluster_directory_path, local_directory_path)
    isfile(local_directory_path[1:end-1]) && return nothing
    isdir(local_directory_path) ? nothing : mkpath(local_directory_path)
    list_of_local_subdirectories = readdir(local_directory_path)
    list_of_subdirectories = split(ssh("ls $cluster_directory_path"), "\n", keepempty=false)
    Threads.@threads for subdirectory in list_of_subdirectories
        o = findfirst(subdirectory .== list_of_local_subdirectories)
        if o == nothing
            # isdefined(Main, :IJulia) ? IJulia.clear_output(true) : nothing
            println("Thread $(Threads.threadid()) copy $username$host:$cluster_directory_path$subdirectory into $local_directory_path")
            run(`scp -r $username$host:$cluster_directory_path$subdirectory $local_directory_path`)
        else
            download_dir(cluster_directory_path*subdirectory*"/", local_directory_path*subdirectory*"/")
        end
    end
end

# Call download_dir and upate_ext for specific extension
# This function needs to be edited according to your need
function downloadcl(cluster_directory="test/", local_directory_path="E:/test/")
    cluster_directory_path = cluster_directory[1:4] == "/hom" ? cluster_directory : cluster_home_path*cluster_directory
    mkpath(local_directory_path)
    update_ext(cluster_directory_path, local_directory_path, ".csv")
    update_ext(cluster_directory_path, local_directory_path, ".out")
    download_dir(cluster_directory_path, local_directory_path)
end

function history_IDs()
    today = string(Dates.today() - Dates.Month(1))
    jobIDs = Vector{Int}()
    for i in split(ssh("sacct -S $today -u $username --format=JobID"), keepempty=false)
        b = tryparse(Int, i)
        !isnothing(b) ? push!(jobIDs, b) : nothing
    end
    return jobIDs
end

function readout(jobID)
    pathout = findfile(string(jobID,".out"), cluster_home_path)
    # dircl, fn = splitpath(pathout)
    pathout == "" ? nothing : printssh("cat $pathout")
end

function readlastout()
    jobid = history_IDs()[end]
    readout(jobid)
end

function readlastout(inc)
    jobid = history_IDs()[end+inc]
    readout(jobid)
end

@inline function readlastlineout(jobID::Int)
    pathout = findfile(string(jobID,".out"), cluster_home_path)
    return split(ssh("cat $pathout"), "\n", keepempty=false)[end]
end

@inline function getpathout(jobID)
    return findfile(string(jobID,".out"), cluster_home_path)
end

@inline function readlastlineout(pathout::String)
    return split(ssh("cat $pathout"), "\n", keepempty=false)[end]
end

function info_gpus()
    printssh("squeue --nodes=gpu[020-022,027-031]")
end

function info_gpus_kruse()
    printssh("squeue -partition=private-kruse-gpu")
end