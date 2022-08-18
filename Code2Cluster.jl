include("ssh-utilities.jl")
usingpkg("JSON, Markdown, Dates")

# It is necessary to use SSH key login, which removes the need for a password for each login, thus ensuring a password-less, automatic login process
# To do that use
# `$ ssh-keygen` to generate public and private key files stored in the ~/.ssh directory
# Then copy the public key in the ~/.ssh/authorized_keys file, on ubuntu you can use
# `ssh-copy-id -i ~/.ssh/id_rsa.pub user@remote_host`
# or (if ssh-copy-id not installed)
# `cat ~/.ssh/id_rsa.pub | ssh username@remote_host "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys" `
# Eventually, for Windows users, you can manually copy your public key
# open `~/.ssh/id_rsa.pub` and copy the public key, connect to the remote server using ssh
# `echo past >> ~/.ssh/authorized_keys` with past the ssh key (Is it also possible to do it by hand with the GUI of FileZilla

# Convert notebook file in ".ext" file (stop conversion at #STOP in notebook cell)
# ext = optional kwarg ! ex: call `ipnyb2jl(tmpdir, ipynfile, ext=".py")` for python file
function ipnyb2jl(ipynfile; ext=".jl")
    jlfile = replace(ipynfile, r"(\.ipynb)?$" => ext)
    nb = open(JSON.parse, ipynfile, "r")
    open(jlfile, "w") do f
        for cell in nb["cells"]
            if cell["source"][1][1:5] == "#STOP" #STOP conversion
                break;
            end
            if cell["cell_type"] == "code"
                print.(Ref(f), cell["source"])
                print(f, "\n\n")
            elseif cell["cell_type"] == "markdown"
                md = Markdown.parse(join(cell["source"]))
                println(f, "\n\n# ", replace(repr("text/plain", md), '\n' => "\n# "))
            end
        end
    end
    return jlfile
end

# Change the saving directory from local to cluster
# The saving directory have to be declare `dir = ...` 
# "dir =" is the key string necessary to change the directory
function change_saving_directory(local_directory_path, jlfile, sdir)
    check = false
    jlfilec = string(jlfile[1:end-3],"-copie",jlfile[end-2:end])
    cp(local_directory_path*jlfile, local_directory_path*jlfilec, force = true)
    nb = open(local_directory_path*jlfilec, "r")
    open(local_directory_path*jlfile, "w") do io
        for line in eachline(nb)
            if !check && length(line) >= 5 && line[1:5] == "dir ="
                check = true
                println(io, sdir)
            else
                println(io, line)
            end
        end
    end
    close(nb)
    rm(local_directory_path*jlfilec)
end

# Read the last line of a `.out` file
# Read only the last line, speed independant of the number of lines !
function read_last_line(file)
    open(file) do io
        seekend(io) #add if Char(peek(io))== '\n' pos -2 otherwise pos -1
        seek(io, position(io) - 2)
        while Char(peek(io)) != '\n' && position(io)>=1
            seek(io, position(io) - 1)
        end
        read(io, Char)
        read(io, String)
    end
end

# Generate the bash file
# You have to fill the important lines first
# By default execute julia file on one DP Ampere GPU with optimize compilation
function generate_bash(cluster_saving_directory_path, local_directory_path, julia_file_path, time; partitions="private-kruse-gpu,shared-gpu", mem="3000", constraint="DOUBLE_PRECISION_GPU")
    bsh1 = """
    #!/bin/env bash
    #SBATCH --partition=$partitions
    #SBATCH --time=$time
    #SBATCH --gpus=ampere:1
    #SBATCH --constraint=$constraint
    #SBATCH --output=%J.out
    #SBATCH --mem=3000

    module load Julia

    cd """

    bsh2 = "srun julia --optimize=3 "
    bsh = bsh1*cluster_saving_directory_path*"\n"*bsh2*julia_file_path

    open(local_directory_path*"C2C.sh", "w") do io
               write(io, bsh)
           end;
end

# Call the other functions to
# 1. Generate bash
# 2. Copy everything on the cluster
# 3. Submit job and get the Job ID
function run_on_cluster(filename; cluster_directory="test/", local_code_directory="E:/test/", stime="0-00:30:00", partitions="private-kruse-gpu,shared-gpu", mem="3000", constraint="DOUBLE_PRECISION_GPU")

    cluster_full_directory = cluster_home_path*cluster_directory
    sdir = """ dir = "$cluster_saving_directory" """
    
    # Get jl file with right directory
    if filename[end-3:end] == ".jl"
        jlfile = filename
    else
        jlfile = ipnyb2jl(local_code_directory, ipynfile, ext=".jl")
    end
    change_saving_directory(local_code_directory, jlfile, sdir)
    
    # Generate bash file with custom time
    generate_bash(cluster_full_directory, local_code_directory, jlfile, stime, partitions=partitions)
    
    # Copy bash and jl file on cluster
    f1 = local_code_directory*jlfile   # path+name of julia file
    f2 = local_code_directory*"C2C.sh" # path+name of bash file
    # run(`ssh $username$host mkdir -p $dir`)
    runssh("mkdir -p $cluster_full_directory")
    run(`scp $f1 $username$host:$cluster_full_directory`)
    run(`scp $f2 $username$host:$cluster_full_directory`)
    
    # Connect to cluster using SSH and submit job
    njob = readchomp(`ssh $username$host "cd $cluster_full_directory && sbatch C2C.sh"`)[end-7:end]
    println("Job id: ", njob) # print job number
end

function jobsinfo(cluster_directory, local_saving_directory)
    longstring = ""
    mkpath(local_saving_directory)
    cluster_full_directory = cluster_home_path*cluster_directory
    update_ext(cluster_full_directory, local_saving_directory, ".out")
    jobIDs = getjobids()

    longstring *= rsqueue()
    longstring *= "\n"
    for jobID in sort!(jobIDs)
        fout = string(local_saving_directory, jobID, ".out")
        longstring *= isfile(fout) ? string(jobID," : ",read_last_line(fout)) : string(jobID, " : waiting \n")
    end
    return longstring
end

function jobsinfo(local_saving_directory)
    longstring = rsqueue()
    longstring *= "\n"
    mkpath(local_saving_directory)
    jobIDs = getjobids()
    for jobID in sort!(jobIDs)
        pathout = findfile(string(jobID,".out"), cluster_home_path)
        dircl, fn = splitpath(pathout)
        update_file(fn, dircl, local_saving_directory)
        fout = string(local_saving_directory, jobID, ".out")
        longstring *= isfile(fout) ? string(jobID," : ",read_last_line(fout)) : string(jobID, " : waiting \n")
    end 
    println(longstring)
end


function splitpath(pathfn)
    pospoint = findfirst(x->x=='.', pathfn)
    path = ""
    fn = ""
    if pospoint != nothing
        endpath = findlast(x->x=='/', pathfn)
        path *= pathfn[1:endpath]
        fn *= pathfn[endpath+1:end]
    else
        path *= pathfn
        
    end
    return path, fn
end

function copylocalcode(dirc, ldir)
    scp_up(dirc, ldir)
end


function getinfoout(pathout::String)
    sp = split(ssh("cat $pathout"), "\n", keepempty=false)
    sp2 = filter(startswith("path_"), sp)
    if length(sp)==0
        return "", "", ""
    else
        if length(sp2) == 0
            return "", "", sp[1]
        elseif length(sp2) == 1
            return sp2[1], "", sp[1]
        elseif length(sp2) ==2 && length(sp)>0
            return sp2[1], sp2[2], sp[end]
        end
    end
end

function runmycode(local_code_path="D:/Code/.../", julia_filename="something.jl", cluster_code_dir = "Code/Protrusions/PQ/", cluster_save_directory="test/",  stime="0-00:30:00"; partitions="private-kruse-gpu")
    
    cluster_saving_directory = cluster_home_path*cluster_save_directory
    cluster_code_directory = cluster_home_path*cluster_code_dir
    create_dir(cluster_code_directory)
    create_dir(cluster_saving_directory)
    cluster_julia_file_path = cluster_code_directory*julia_filename
    
    sdir = """ dir = "$cluster_saving_directory" """
    change_saving_directory(local_code_path, "InputParameters.jl", sdir)
    
    generate_bash(cluster_saving_directory, local_code_path, cluster_julia_file_path, stime, partitions=partitions)
    scp_up_dir(cluster_code_directory, local_code_path)
    scp_up_file(cluster_saving_directory, local_code_path*"C2C.sh")
    njob = ssh("cd $cluster_saving_directory && sbatch C2C.sh")[end-7:end]
    println("Job id: ", njob) # print job number
end
