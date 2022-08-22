include("Code2Cluster.jl")
usingpkg("Telegram")
using Telegram.API
    
    
chat_idd = "1102324370"
bot_token = "1157189386:AAH3nbZo2XgYoSMmpMc_4FXWXEX8IQHwQ6U"

tg = TelegramClient(bot_token, chat_id = chat_idd)

function telegram_interaction()
    if length(getUpdates(tg))>0 && getUpdates(tg)[end].message.text == "Book"
        # sendMessage(text  = string("Book a gpu"))
        return "Book"
    elseif length(getUpdates(tg))>0 && getUpdates(tg)[end].message.text == "Free"
        # sendMessage(text  = string("Free a gpu"))
        return "Free"
    elseif length(getUpdates(tg))>0 && getUpdates(tg)[end].message.text == "Squeue"
        return "squeue"
    else
        # sendMessage(text  = string("No information"))
    end
    return nothing
end

function generate_do_nothing()
    txt = """
    using CUDA
    
    while true
        sleep(60)
    end
    
    """
    open("do_nothing.jl", "w") do io
               write(io, txt)
           end;
end

function is_booked()
    return split(rsqueue(opt="--Format JobId --name book_gpu -h"), keepempty=false)
end
    

function book_a_gpu()
    local_code_path = normpath(string(@__DIR__,"/"))
    generate_bash(cluster_home_path, local_code_path, "do_nothing.jl", "0-12:00:00", sh_name="book_gpu.sh")
    generate_do_nothing()
    cluster_saving_directory = cluster_home_path*"BookGPU/"
    ssh_create_dir(cluster_saving_directory)
    println("""Upload .jl files from $local_code_path in $(cluster_home_path*"Code/Utilities/") """)
    scp_up_jl(cluster_home_path*"Code/Utilities/", local_code_path)
    println(" Upload book_a_gpu.sh from $local_code_path in $cluster_saving_directory ")
    scp_up_file(cluster_saving_directory, local_code_path*"book_gpu.sh")
    njob = ssh("cd $cluster_saving_directory && sbatch book_gpu.sh")[end-7:end]
    println("Job submitted, the id is: ", njob) # print job number
    sendMessage(text = string("GPU booked for 12h, the id is: ", njob) )
    rm("book_gpu.sh")
    rm("do_nothing.jl")
end

while true
    jobID_booked = split(rsqueue(opt="--Format JobId --name book_gpu.sh -h"), keepempty=false)
    if isempty(jobID_booked) && telegram_interaction() == "Book"
        book_a_gpu()
    else
        if telegram_interaction() == "Free"
            for i in jobID_booked
                sendMessage(text = string("scancel ", i) )
                println(string("scancel ", i))
                scancel(i)
            end
        end
    end
    if telegram_interaction() == "squeue"
        sendMessage(text = rsqueue(opt="-h"))
    end
    sleep(30)
end
    