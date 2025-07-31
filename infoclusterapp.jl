include("using.jl")
using_pkg("Bonito, Electron, Observables")
import Bonito as B
# import Bonito.TailwindDashboard as D

global mem_jobIDs = Vector{Int}()
global mem_pathout = Vector{String}()
global mem_pathcluster = Vector{String}()
global mem_pathlocal = Vector{String}()

function get_jobsinfo()
    longstring = ""
    
    jobIDs = SSH.Get.jobids()

    longstring *= SSH.ssh("squeue --me --Format JobID,Name,Partition,NodeList,PendingTime,Reason,StartTime,State,TimeUsed | uniq")#--array-unique")
    longstring *= "\n"
    for jobID in jobIDs
        idx = findfirst(isequal(jobID), mem_jobIDs)
        st = ""
        if !isnothing(idx) # If jobId already known
            if mem_pathlocal[idx] == ""
                println(" Get and save all infos for: $jobID")
                pathcluster, pathlocal, lastline = get_infoout(mem_pathout[idx])
                if pathcluster*pathlocal*lastline == ""
                    println("In queue....")
                end
                mem_pathcluster[idx] = pathcluster
                mem_pathlocal[idx] = pathlocal
                st *= lastline*" \n"
            else
                println(" Read last line of the .out of job: $jobID")
                st *= SSH.Get.lastlineout(mem_pathout[idx])*" \n"
            end
        else # First time jobId
            println(" Get and save path of .out file for: $jobID")
            fout = SSH.Get.pathoutrunning(jobID)*string(jobID,".out")
            if length(fout)>1
                push!(mem_jobIDs, jobID)
                push!(mem_pathout, fout)
                println(" Get all infos for: $jobID")
                pathcluster, pathlocal, lastline = get_infoout(mem_pathout[end])
                push!(mem_pathcluster, pathcluster)
                push!(mem_pathlocal, pathlocal)
                st *= lastline*" \n"
            end
        end
        longstring *= st != "" ? st : string(jobID, " : waiting \n")
    end
    
    if length(mem_jobIDs) > 0 
        for idx = length(mem_jobIDs):-1:1
            if !any(isequal(mem_jobIDs[idx]), jobIDs)
                println(" Delete all infos about job: $(mem_jobIDs[idx])")
                deleteat!(mem_jobIDs, idx)
                deleteat!(mem_pathout, idx)
                deleteat!(mem_pathcluster, idx)
                deleteat!(mem_pathlocal, idx)
            end
        end
    end
    
    return longstring
end

function do_download(mem_pathcluster, mem_pathlocal)
   dir_tuple = unique!([(mem_pathcluster[i], mem_pathlocal[i]) for i=1:length(mem_jobIDs)])
    for i=1:length(dir_tuple)
        dir_clu = dir_tuple[i][1]
        dir_res = dir_tuple[i][2]
        dir_res *= (dir_res=="" || endswith(dir_res, "/")) ? "" : "/"
        dir_clu*dir_res == "" ? println(" Nothing to download") : nothing
        dir_clu*dir_res != "" ? SSH.SCP.download(dir_clu, dir_res) : nothing
    end
end

app = App(title="...") do 
    button_style = Styles(
        CSS("font-weight" => "500"),
        CSS(":hover", "background-color" => "silver"),
    )
    ui = Observable{Any}(DOM.div())
    infobutton = Bonito.Button("squeue --me", style=button_style)
    download_button = Bonito.Button("Download last job array", style=button_style)
    download_button_all = Bonito.Button("Download running job arrays", style=button_style)
    on(infobutton.value) do click::Bool
        @info "Sending squeue --me"
        ui[] = get_jobsinfo()
        @info " ... done"
    end
    on(download_button.value) do click::Bool
        download_lastjob(0)
    end
    on(download_button_all.value) do click::Bool
        do_download(mem_pathcluster, mem_pathlocal)
    end
    return DOM.div(B.Row(infobutton, download_button, download_button_all), ui)
end

Bonito.use_electron_display()
display(app)