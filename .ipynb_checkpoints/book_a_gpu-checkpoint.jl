include("Code2Cluster.jl")

function generate_do_nothing(local_code_path)
    txt = """
    using CUDA
    
    while true
        sleep(60)
    end
    
    """
    open(local_code_path*"do_nothing.jl", "w") do io
               write(io, txt)
           end;
end

function is_booked()
    return split(rsqueue(opt="--Format JobId --name book_gpu -h"), keepempty=false)
end
    

function book_a_gpu()
    local_code_path = normpath(string(@__DIR__,"/"))
    generate_bash(cluster_home_path*"Code/Utilities/", local_code_path, "do_nothing.jl", "0-12:00:00", sh_name="book_gpu.sh")
    generate_do_nothing(local_code_path)
    sleep(2)
    cluster_saving_directory = cluster_home_path*"BookGPU/"
    ssh_create_dir(cluster_saving_directory)
    println("""Upload .jl files from $local_code_path in $(cluster_home_path*"Code/Utilities/") """)
    scp_up_jl(cluster_home_path*"Code/Utilities/", local_code_path)
    println(" Upload book_gpu.sh from $local_code_path in $cluster_saving_directory ")
    scp_up_file(cluster_saving_directory, local_code_path*"book_gpu.sh")
    njob = ssh("cd $cluster_saving_directory && sbatch book_gpu.sh")[end-7:end]
    println("Job submitted, the id is: ", njob) # print job number
    sleep(2)
    rm(local_code_path*"book_gpu.sh")
    rm(local_code_path*"do_nothing.jl")
    return njob
end