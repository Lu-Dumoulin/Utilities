include("using.jl")
using_pkg("JSON, Markdown, Dates, DelimitedFiles, CSV, DataFrames")
using_mod(".SSH, .JulUtils")
using .SSH.Print

# Change the saving directory from local to cluster
# The saving directory have to be declare `dir = ...` 
# "dir =" is the key string necessary to change the directory
function change_saving_directory(local_directory_path, jlfile, sdir, ldir; jobarray=false)
    jlfilec = string(jlfile[1:end-3],"-copie",jlfile[end-2:end])
    cp(local_directory_path*jlfile, local_directory_path*jlfilec, force = true)
    nb = open(local_directory_path*jlfilec, "r")
    open(local_directory_path*jlfile, "w") do io
        println(io, sdir)
        println(io, ldir)
        jobarray ? println(io, """idx = Base.parse(Int, ENV["SLURM_ARRAY_TASK_ID"])
                                  @show fn = "\$idx/" 
                                  file = joinpath(dir, fn) 
                                  mkpath(file) """) : nothing
        println(io, """println("path_c = ", dir)
                       println("path_l = ", localpath)""")
        jobarray ? println(io, "println(idx) ") : nothing
        for line in eachline(nb)
            if startswith(line, "idx") || startswith(line, "file") || startswith(line, "mkpath(file)") || startswith(line, """println("path""") || startswith(line, "println(idx)") || startswith(line, "@show fn")
                nothing
            else
                mline = Meta.parse(line)
                if !isnothing(mline) && mline.head == :(=) 
                    if typeof(mline.args[2]) == String && (ispath(mline.args[2]) || lookslikepath(mline.args[2]))
                        nothing
                    else
                        println(io, line)
                    end
                else
                    println(io, line)
                end
            end
        end
    end
    close(nb)
    rm(local_directory_path*jlfilec)
end

# Generate the bash file
# By default execute julia file on one DP Ampere GPU with optimize compilation
function generate_bash(cluster_saving_directory_path, local_directory_path, julia_file_path, time; partitions="private-kruse-gpu,shared-gpu", mem="3000", constraint="DOUBLE_PRECISION_GPU", sh_name="C2C.sh")
    local bsh0 = """
    #!/bin/env bash
    #SBATCH --partition=$partitions
    #SBATCH --time=$time
    #SBATCH --output=%J.out
    #SBATCH --mem=$mem """
    if occursin("gpu", partitions)
        bsh0 *= """ 
        #SBATCH --gpus=1 
        #SBATCH --constraint=$constraint
        """
    else
        if !occursin("GPU", constraint)
            bsh0 *= """ #SBATCH --constraint=$constraint """
        end
    end
    
    bsh1 = """
    
    module load Julia

    cd """
    bsh2 = "srun julia --optimize=3 "
    bsh = bsh0*bsh1*cluster_saving_directory_path*"\n"*bsh2*julia_file_path

    open(local_directory_path*sh_name, "w") do io
               write(io, bsh)
           end;
end

function generate_bash_array(cluster_saving_directory_path, local_directory_path, julia_file_path, time, Njob; partitions="private-kruse-gpu,shared-gpu", mem="3000", constraint="DOUBLE_PRECISION_GPU,COMPUTE_TYPE_AMPERE", sh_name="C2C_array.sh", npara=20)
    local bsh0 = """
    #!/bin/env bash
    #SBATCH --array=1-$Njob%$npara
    #SBATCH --partition=$partitions
    #SBATCH --time=$time
    #SBATCH --output=%J.out
    #SBATCH --mem=$mem """
    if occursin("gpu", partitions)
        bsh0 *= """ 
        #SBATCH --gpus=1 
        #SBATCH --constraint=$constraint
        """
    else
        if !occursin("GPU", constraint)
            bsh0 *= """ #SBATCH --constraint=$constraint """
        end
    end
    
    bsh1 = """
    
    module load Julia

    cd """
    bsh2 = "srun julia --optimize=3 "
    bsh = bsh0*bsh1*cluster_saving_directory_path*"\n"*bsh2*julia_file_path

    open(local_directory_path*sh_name, "w") do io
               write(io, bsh)
           end;
end

function generate_inst_package_julia()
    jlfile = """
    using Pkg
    Pkg.add("CUDA")
    using CUDA
    CUDA.versioninfo()
    pkg_list = ["FFTW", "FileIO", "Distributions", "Printf", "JLD", "Statistics", "JSON", "Markdown", "Dates", "DelimitedFiles", "CSV", "DataFrames"]
    [Pkg.add(i) for i in pkg_list]
        
    using FFTW, FileIO, Distributions, Printf, JLD, Statistics
    using JSON, Markdown, Dates, DelimitedFiles, CSV, DataFrames
    
    println("Remove installation folder")
    
    rm( "$cluster_home_path"*"Code/install_pack/", force=true, recursive=true)
    """
   
    folder_path = joinpath(@__DIR__,"install_pack/")
    mkpath(folder_path)
    open(folder_path*"install_packages.jl", "w") do io
               write(io, jlfile)
           end;
    return folder_path
end


function get_infoout(pathout::String)
    if SSH.File.isfile(pathout)
        sp = split(SSH.ssh("cat $pathout"), "\n", keepempty=false)
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

function download_job(JobID)
    fout = SSH.Get.pathout(JobID)
    if fout==""
        println("Nothing to download")
    else
        cluster_directory, local_directory, _ = get_infoout(fout)
        SSH.SCP.download(cluster_directory, local_directory)
    end
end

function download_lastjobs(n=0)
    nn = 0
    if n < 0 
        println("arg have to be positive: last-arg"); return nothing 
    end
    jobIDs = SSH.Get.histjobids()
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
        download_job(i)
    end
end

function download_lastjob(n=0)
    nn = 0
    if n < 0 
        println("arg have to be positive: last-arg"); return nothing 
    end
    jobIDs = SSH.Get.histjobids()
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
    download_job(jobID)
end
    
function install_julia_packages()
    println("It will remove your .julia/ folder after creating a backup.")
    println("The duration of the installation is about 1 hour.")
    println("Are you sure to be in one of these cases:")
    println(" - You want to install the necessary packages for the first time")
    println(" - You want to reset the previous installation")
    println(" Yes / No ?")
    
    if readline() ∉ ["Y", "Yes", "yes", "y"]
        println(" Installation canceled !")
        return nothing
    end
    
    println("Check if .julia/ exist")
    if SSH.File.isdir(".julia/")
        println(" Check if old backup exist")
        if SSH.File.isdir(".juliaold/")
            println("  Remove old backup ...")
            SSH.run_ssh("rm -rf $cluster_home_path"*".juliaold/")
        end
        println(" Create backup folder .juliaold/ ")
        SSH.run_ssh("cd $cluster_home_path & mv .julia{,old}")
    end
    
    println("Create temporal folder install_pack/ ")
    folder_path = generate_inst_package_julia()
    
    run_one_sim(folder_path, "install_packages.jl", "install_pack/", "Code/install_pack/", "0-01:00:00"; partitions="private-kruse-gpu,shared-gpu", sh_name="install_pkg.sh", input_param_namefile = "install_packages.jl", constraint="", scratch=false)
    println("Remove temporal folder install_pack/ ")
    rm(folder_path, force = true, recursive = true)
    println("The installation will be over when the job will be over")
end

function run_one_sim(local_code_path="D:/Code/.../", julia_filename="something.jl", cluster_code_dir = "Protrusions/PQ/", cluster_save_directory="test/", stime="0-00:30:00"; partitions="private-kruse-gpu,shared-gpu", mem="3000", sh_name="C2C.sh", input_param_namefile = "InputParameters.jl", constraint="DOUBLE_PRECISION_GPU,COMPUTE_TYPE_AMPERE", scratch = true, download_path="/")
    
    local_code_path *= endswith(local_code_path, "/") ? "" : "/"
    cluster_code_dir *= endswith(cluster_code_dir, "/") ? "" : "/"
    cluster_save_directory *= endswith(cluster_save_directory, "/") ? "" : "/"
    
    cluster_saving_directory = scratch ? cluster_home_path*"scratch/"*cluster_save_directory : cluster_home_path*"scratch/"*cluster_save_directory    
    cluster_code_directory = cluster_home_path*"Code/"*cluster_code_dir
    
    SSH.File.mkdir(cluster_home_path*"Code/")
    SSH.File.mkdir(cluster_code_directory)
    SSH.File.mkdir(cluster_saving_directory)
    SSH.File.mkdir(cluster_home_path*"Code/Utilities/")
    
    cluster_julia_file_path = cluster_code_directory*julia_filename
    
    sdir = """dir = "$cluster_saving_directory" """
    ldir = """localpath = "$download_path" """
    println("Change saving directory: $sdir")
    println("Change path where the data will be download: $ldir")
    change_saving_directory(local_code_path, input_param_namefile, sdir, ldir)
    
    println("Generate bash file")
    generate_bash(cluster_saving_directory, local_code_path, cluster_julia_file_path, stime, partitions=partitions, mem=mem, sh_name=sh_name, constraint=constraint)
    println("""Upload .jl files from $local_utilities_path to $(cluster_home_path*"Code/Utilities/") """)
    SSH.SCP.up_jl(cluster_home_path*"Code/Utilities/", local_utilities_path)
    println("Upload .jl files from $local_code_path to $cluster_code_directory")
    SSH.SCP.up_jl(cluster_code_directory, local_code_path)

    println("Upload C2C.sh from $local_code_path to $cluster_saving_directory")
    SSH.SCP.up_file(cluster_saving_directory, local_code_path*sh_name)
    njob = SSH.ssh("cd $cluster_saving_directory && sbatch $sh_name")[end-7:end]
    println("Job submitted, the id is: ", njob) # print job number
end

# npara is the maximal number of CPUs/GPUs allowed to run simultaneously in order to not use the whole cluster
function run_array_DF(local_code_path="D:/Code/", julia_filename="something.jl", cluster_code_dir = "Protrusions/PQ/", cluster_save_directory="test/", stime="0-00:30:00"; df_name="DF.csv", partitions="private-kruse-gpu,shared-gpu", mem="3000", sh_name="C2C_array.sh", input_param_namefile = "InputParameters.jl", npara=20, constraint="DOUBLE_PRECISION_GPU,COMPUTE_TYPE_AMPERE", scratch = true, download_path="/")
    
    local_code_path *= endswith(local_code_path, "/") ? "" : "/"
    cluster_code_dir *= endswith(cluster_code_dir, "/") ? "" : "/"
    cluster_save_directory *= endswith(cluster_save_directory, "/") ? "" : "/"
    download_path *= endswith(download_path, "/") ? "" : "/"
    
    @show Njob = nrow(CSV.read(joinpath(local_code_path,df_name), DataFrame))
    
    cluster_saving_directory = scratch ? cluster_scratch_path*cluster_save_directory : cluster_home_path*cluster_save_directory
    cluster_code_directory = cluster_home_path*"Code/"*cluster_code_dir
    
    SSH.File.mkdir(cluster_home_path*"Code/")
    SSH.File.mkdir(cluster_code_directory)
    SSH.File.mkdir(cluster_saving_directory)
    SSH.File.mkdir(cluster_home_path*"Code/Utilities/")
    
    cluster_julia_file_path = cluster_code_directory*julia_filename
    
    sdir = """dir = "$cluster_saving_directory" """
    ldir = """localpath = "$download_path" """
    println("Change saving directory: $sdir")
    println("Change path where the data will be download: $ldir")
    change_saving_directory(local_code_path, input_param_namefile, sdir, ldir, jobarray=true)
    
    println("Generate bash file")
    generate_bash_array(cluster_saving_directory, local_code_path, cluster_julia_file_path, stime, Njob, partitions=partitions, mem=mem, sh_name=sh_name, npara=npara, constraint=constraint)
 
    println("""Upload .jl files from $local_utilities_path to $(cluster_home_path*"Code/Utilities/") """)
    SSH.SCP.up_jl(cluster_home_path*"Code/Utilities/", local_utilities_path)
    println("Upload .jl files from $local_code_path to $cluster_code_directory")
    SSH.SCP.up_jl(cluster_code_directory, local_code_path)
    println("Upload .csv file from $local_code_path to $cluster_code_directory")
    SSH.SCP.up_ext(cluster_code_directory, local_code_path, "csv")
    println("Upload .csv file from $local_code_path to $cluster_saving_directory")
    SSH.SCP.up_ext(cluster_saving_directory, local_code_path, "csv")

    println("Upload $sh_name from $local_code_path to $cluster_saving_directory")
    SSH.SCP.up_file(cluster_saving_directory, local_code_path*sh_name)
    njob = SSH.ssh("cd $cluster_saving_directory && sbatch $sh_name")[end-7:end]
    println("Job submitted, the id is: ", njob) # print job number
end

infocluster() = include(joinpath(@__DIR__,"infoclusterapp.jl"))

# Examples
# run_array_DF("../FFT_2D_P/", "2D.jl", "FFT_2D_P_sat/", "Data/P-series/sat/", "0-12:00:00", npara = 40, download_path = "Z:/sat/", sh_name="sat.sh")
# run_array_DF("../Ella_adaptive_mesh/", "main.jl", "Ella_adaptive_mesh1/", "Data/Ella/deb4/", "0-12:00:00", npara = 40, download_path = "D:/Ella/deb4/", sh_name="el.sh", mem="8000", scratch=false)
# run_array_DF("../Ella_w_PARS/", "main.jl", "Ella_PARs2/", "Data/Ella_PARs2/", "7-0:00:00", partitions="private-kruse-gpu", npara = 1, download_path = "D:/Ella/Cu_PARs2/", sh_name="7d.sh", mem="8000")
