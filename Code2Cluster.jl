include("ssh_utilities.jl")
usingpkg("JSON, Markdown, Dates, DelimitedFiles, CSV, DataFrames")

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

# Generate the bash file
# You have to fill the important lines first
# By default execute julia file on one DP Ampere GPU with optimize compilation
function generate_bash(cluster_saving_directory_path, local_directory_path, julia_file_path, time; partitions="private-kruse-gpu,shared-gpu", mem="3000", constraint="DOUBLE_PRECISION_GPU", sh_name="C2C.sh")
    bsh1 = """
    #!/bin/env bash
    #SBATCH --partition=$partitions
    #SBATCH --time=$time
    #SBATCH --gpus=ampere:1
    #SBATCH --constraint=$constraint
    #SBATCH --output=%J.out
    #SBATCH --mem=$mem

    module load Julia

    cd """

    bsh2 = "srun julia --optimize=3 "
    bsh = bsh1*cluster_saving_directory_path*"\n"*bsh2*julia_file_path

    open(local_directory_path*sh_name, "w") do io
               write(io, bsh)
           end;
end

function generate_bash_array(cluster_saving_directory_path, local_directory_path, julia_file_path, time, Njob; partitions="private-kruse-gpu,shared-gpu", mem="3000", constraint="DOUBLE_PRECISION_GPU", sh_name="C2C_array.sh")
    bsh1 = """
    #!/bin/env bash
    #SBATCH --array=1-$Njob%20
    #SBATCH --partition=$partitions
    #SBATCH --time=$time
    #SBATCH --gpus=ampere:1
    #SBATCH --constraint=$constraint
    #SBATCH --output=%J.out
    #SBATCH --mem=$mem

    module load Julia

    cd """
    bsh2 = "srun julia --optimize=3 "
    bsh = bsh1*cluster_saving_directory_path*"\n"*bsh2*julia_file_path

    open(local_directory_path*sh_name, "w") do io
               write(io, bsh)
           end;
end

function getinfoout(pathout::String)
    if ssh_isfile(pathout) == "1"
        sp = split(ssh("cat $pathout"), "\n", keepempty=false)
        sp2 = filter(startswith("path_"), sp)
        if length(sp)==0
            return "", "", ""
        else
            if length(sp2) == 0
                return "", "", sp[1]
            elseif length(sp2) == 1
                return sp2[1][10:end], "", sp[1]
            elseif length(sp2) ==2 && length(sp)>0
                return sp2[1][10:end], sp2[2][10:end], sp[end]
            end
        end
    else
        return "", "", ""
    end
end

function download_JobID(JobID)
    fout = ssh_getpathout(JobID)
    if fout==""
        println("Nothing to download")
    else
        cluster_directory, local_directory, _ = getinfoout(fout)
        ssh_download(cluster_directory, local_directory)
    end
end

function download_last_jobs(n=0)
    nn = 0
    if n < 0 
        println("arg have to be positive: last-arg"); return nothing 
    end
    jobIDs = ssh_history_IDs()
    njobs = length(jobIDs)
    if njobs == 0 
        println("No job this past month")
        return nothing
    elseif njobs <= n
        nn=njobs-1
    else 
        nn= n 
    end
    for i in jobIDs[end-nn:end]
        println("For job: $i")
        download_JobID(i)
    end
end

function download_last_job(n=0)
    nn = 0
    if n < 0 
        println("arg have to be positive: last-arg"); return nothing 
    end
    jobIDs = ssh_history_IDs()
    njobs = length(jobIDs)
    if njobs == 0 
        println("No job this past month")
        return nothing
    elseif njobs <= n
        nn=njobs-1
    else 
        nn= n 
    end
    jobID = jobIDs[end-nn]
    println("For job: $jobID")
    download_JobID(jobID)
end
    

function run_one_sim(local_code_path="D:/Code/.../", julia_filename="something.jl", cluster_code_dir = "Protrusions/PQ/", cluster_save_directory="test/", stime="0-00:30:00"; partitions="private-kruse-gpu", mem="3000", sh_name="C2C.sh", input_param_namefile = "InputParameters.jl")
    
    cluster_saving_directory = cluster_home_path*cluster_save_directory
    cluster_code_directory = cluster_home_path*"Code/"*cluster_code_dir
    
    ssh_mkdir(cluster_home_path*"Code/")
    ssh_mkdir(cluster_code_directory)
    ssh_mkdir(cluster_saving_directory)
    cluster_julia_file_path = cluster_code_directory*julia_filename
    
    sdir = """dir = "$cluster_saving_directory" """
    println("Change saving directory: $sdir")
    change_saving_directory(local_code_path, input_param_namefile, sdir)
    
    println("Generate bash file")
    generate_bash(cluster_saving_directory, local_code_path, cluster_julia_file_path, stime, partitions=partitions, mem=mem, sh_name=sh_name)
    println("""Upload .jl files from $local_utilities_path to $(cluster_home_path*"Code/Utilities/") """)
    scp_up_jl(cluster_home_path*"Code/Utilities/", local_utilities_path)
    println("Upload .jl files from $local_code_path to $cluster_code_directory")
    scp_up_jl(cluster_code_directory, local_code_path)

    println("Upload C2C.sh from $local_code_path to $cluster_saving_directory")
    scp_up_file(cluster_saving_directory, local_code_path*sh_name)
    njob = ssh("cd $cluster_saving_directory && sbatch $sh_name")[end-7:end]
    println("Job submitted, the id is: ", njob) # print job number
end

function run_array_DF(local_code_path="D:/Code/.../", julia_filename="something.jl", cluster_code_dir = "Protrusions/PQ/", cluster_save_directory="test/", stime="0-00:30:00", df_name="DF.csv"; partitions="private-kruse-gpu", mem="3000", sh_name="C2C_array.sh", input_param_namefile = "InputParameters.jl")
    
    @show Njob = nrow(CSV.read(joinpath(local_code_path,df_name), DataFrame))
    
    cluster_saving_directory = cluster_home_path*cluster_save_directory
    cluster_code_directory = cluster_home_path*"Code/"*cluster_code_dir
    
    ssh_mkdir(cluster_home_path*"Code/")
    ssh_mkdir(cluster_code_directory)
    ssh_mkdir(cluster_saving_directory)
    cluster_julia_file_path = cluster_code_directory*julia_filename
    
    sdir = """dir = "$cluster_saving_directory" """
    println("Change saving directory: $sdir")
    change_saving_directory(local_code_path, input_param_namefile, sdir)
    
    println("Generate bash file")
    generate_bash_array(cluster_saving_directory, local_code_path, cluster_julia_file_path, stime, Njob, partitions=partitions, mem=mem, sh_name=sh_name)
 
    println("""Upload .jl files from $local_utilities_path to $(cluster_home_path*"Code/Utilities/") """)
    scp_up_jl(cluster_home_path*"Code/Utilities/", local_utilities_path)
    println("Upload .jl files from $local_code_path to $cluster_code_directory")
    scp_up_jl(cluster_code_directory, local_code_path)
    println("Upload .csv file from $local_code_path to $cluster_code_directory")
    scp_up_ext(cluster_code_directory, local_code_path, "csv")
    println("Upload .csv file from $local_code_path to $cluster_saving_directory")
    scp_up_ext(cluster_saving_directory, local_code_path, "csv")

    println("Upload $sh_name from $local_code_path to $cluster_saving_directory")
    scp_up_file(cluster_saving_directory, local_code_path*sh_name)
    njob = ssh("cd $cluster_saving_directory && sbatch $sh_name")[end-7:end]
    println("Job submitted, the id is: ", njob) # print job number
end