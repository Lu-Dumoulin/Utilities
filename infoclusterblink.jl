include("Code2Cluster.jl")
usingpkg("Interact, Blink")

global mem_jobIDs = Vector{Int}()
global mem_pathout = Vector{String}()
global mem_pathcluster = Vector{String}()
global mem_pathlocal = Vector{String}()

global longs = Observable{Any}("tessttt")

function getjobsinfo()
    longstring = ""
    
    jobIDs = ssh_getjobids()

    longstring *= ssh("squeue --me --Format JobID,Name,Partition,NodeList,PendingTime,Reason,StartTime,State,TimeUsed --array-unique")
    longstring *= "\n"
    for jobID in jobIDs
        idx = findfirst(isequal(jobID), mem_jobIDs)
        st = ""
        if !isnothing(idx) # If jobId already known
            if mem_pathlocal[idx] == ""
                println(" Get and save all infos for: $jobID")
                pathcluster, pathlocal, lastline = getinfoout(mem_pathout[idx])
                if pathcluster*pathlocal*lastline == ""
                    println("In queue....")
                end
                mem_pathcluster[idx] = pathcluster
                mem_pathlocal[idx] = pathlocal
                st *= lastline*" \n"
            else
                println(" Read last line of the .out of job: $jobID")
                st *= ssh_readlastlineout(mem_pathout[idx])*" \n"
            end
        else # First time jobId
            println(" Get and save path of .out file for: $jobID")
            fout = ssh_getpathoutrunning(jobID)*string(jobID,".out")
            if length(fout)>1
                push!(mem_jobIDs, jobID)
                push!(mem_pathout, fout)
                println(" Get all infos for: $jobID")
                pathcluster, pathlocal, lastline = getinfoout(mem_pathout[end])
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


function getui(b)
    map!(getjobsinfo, longs)
    return dom"div"(split(String(longs[]), "\n", keepempty=false))
end

function do_download(mem_pathcluster, mem_pathlocal)
   dir_tuple = unique!([(mem_pathcluster[i], mem_pathlocal[i]) for i=1:length(mem_jobIDs)])
    for i=1:length(dir_tuple)
        dir_clu = dir_tuple[i][1]
        dir_res = dir_tuple[i][2]
        dir_clu*dir_res == "" ? println(" Nothing to download") : nothing
        dir_clu*dir_res != "" ? ssh_download(dir_clu, dir_res) : nothing
    end
end

w = Window()
ui = Observable{Any}()
b = Interact.button("Get jobs info"; value = 1)
b2 = Interact.button("Download files"; value = 1)
b3 = Interact.button("Download last job"; value = 0)

map!(getui, ui, b)

on(b2) do b
     do_download(mem_pathcluster, mem_pathlocal)
end

on(b3) do b
    download_last_job()
end


body!(w, dom"div"(hbox(b, b2, b3), ui))