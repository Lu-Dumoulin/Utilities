include("book_a_gpu.jl")
usingpkg("Telegram")
using Telegram.API
using Sockets
    
    
chat_idd = "1102324370"
bot_token = "1157189386:AAH3nbZo2XgYoSMmpMc_4FXWXEX8IQHwQ6U"

tg = TelegramClient(bot_token, chat_id = chat_idd)
global last_message_id = length(getUpdates(tg))> 0 ? getUpdates(tg)[end].message.message_id : 0

function telegram_interaction(last_message_id=last_message_id)
    if length(getUpdates(tg))>0
        if getUpdates(tg)[end].message.message_id == last_message_id
            return nothing
        else
            global last_message_id = getUpdates(tg)[end].message.message_id
            if getUpdates(tg)[end].message.text == "Book"
                return "Book"
            elseif getUpdates(tg)[end].message.text == "Free"
                return "Free"
            elseif getUpdates(tg)[end].message.text == "Squeue"
                return "squeue"
            elseif getUpdates(tg)[end].message.text == "Http"
                return "http"
            elseif getUpdates(tg)[end].message.text == "Kill http"
                return "close_http"
            else
            end
        end
    end
    return nothing
end

while true
    jobID_booked = split(rsqueue(opt="--Format JobId --name book_gpu.sh -h"), keepempty=false)
    messagetext = telegram_interaction()
    if isempty(jobID_booked) && messagetext == "Book"
        njob = book_a_gpu()
        sendMessage(text = string("GPU booked for 12h, the id is: ", njob) )
    else
        if messagetext == "Free"
            for i in jobID_booked
                sendMessage(text = string("scancel ", i) )
                println(string("scancel ", i))
                scancel(i)
            end
        end
    end
    if messagetext == "squeue"
        sendMessage(text = string("squeue: \n", rsqueue(opt="-h")))
    end
    if messagetext == "http"
        sendMessage(text = "Create Mux server")
        include("../all-plot-http.jl")
        sendMessage(text = "Connect to $(string(Sockets.getipaddrs()[2])):8000/MitoAndAsters/ for Asters plots")
        sendMessage(text = "Connect to $(string(Sockets.getipaddrs()[2])):8000/PQ/ for protrusion plots")
        sendMessage(text = "Connect to $(string(Sockets.getipaddrs()[2])):8000/Ella/ for Ella's plots")
    end
    if messagetext == "close_http"
        @async Base.throwto(MUX_SERVER_TASK, InterruptException())
        sendMessage(text = "Kill http")
    end
    sleep(30)
end
    