include("Code2Cluster.jl")
usingpkg("Interact, Blink")#, Distributed
# addprocs(4)

global mem_jobIDs = Vector{Int}()
global mem_pathout = Vector{String}()
global mem_pathcluster = Vector{String}()
global mem_pathlocal = Vector{String}()

global longs = Observable{Any}("tessttt")

function getjobsinfo()
    longstring = ""
    
    jobIDs = getjobids()

    longstring *= ssh("squeue --me")
    longstring *= "\n"
    for jobID in jobIDs
        idx = findfirst(isequal(jobID), mem_jobIDs)
        st = ""
        if !isnothing(idx)
            if mem_pathlocal[idx] == ""
                println(" Get and save all infos for: $jobID")
                pathcluster, pathlocal, lastline = getinfoout(mem_pathout[idx])
                push!(mem_pathcluster, pathcluster)
                push!(mem_pathlocal, pathlocal)
                st *= lastline*" \n"
            else
                println(" Read last line of the .out of job: $jobID")
                st *= readlastlineout(mem_pathout[idx])*" \n"
            end
        else
            println(" Get and save path of .out file for: $jobID")
            fout = getpathout(jobID)
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
    # @distributed for i=1:length(mem_jobIDs) #Threads.@threads 
    for i=1:length(mem_jobIDs)
        dir_clu = mem_pathcluster[i]
        dir_res = mem_pathlocal[i]
        dir_clu*dir_res != "" ? println("Download $dir_clu into $dir_res") : println("Nothing to download")
        dir_clu*dir_res != "" ? downloadcl(dir_clu, dir_res) : nothing
    end
end

function getparentdir!(parent_dirs, pathclu, pathlocal)
    parent_clu = ""
    parent_loc = ""
    sl = length(pathlocal)
    sc = length(pathclu)
    s = minimum([sl, sc])
    idx = 0
    for i=0:s-1
        pathclu[end-i] != pathlocal[end-i] && break
        idx = i
    end
    idx -= findfirst(isequal('/'),pathlocal[end-idx+1:end])
    push!(parent_dirs, (pathclu[1:end-idx], pathlocal[1:end-idx]) )
end

function do_synch(mem_pathcluster, mem_pathlocal)
    parent_dirs = Vector{Tuple{String, String}}()
    for i=1:length(mem_jobIDs)
        getparentdir!(parent_dirs, mem_pathcluster[i], mem_pathlocal[i])
    end
    unique(parent_dirs)
    for i in parent_dirs
        println("  Synch $(i[1]) with $(i[2])  ")
    end
end

w = Window()
ui = Observable{Any}()
b = Interact.button("Get jobs info"; value = 1)
b2 = Interact.button("Dowmload files"; value = 1)
b3 = Interact.button("Synch parent directories"; value = 1)

map!(getui, ui, b)

on(b2) do b
     do_download(mem_pathcluster, mem_pathlocal)
end

on(b3) do b
    do_synch(mem_pathcluster, mem_pathlocal)
end

body!(w, dom"div"(hbox(b, b2, b3), ui))
