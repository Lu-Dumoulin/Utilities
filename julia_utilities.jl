using Pkg

@inline function usingpkg(st)
    listofpkg = split(st, ", ")
    for package in listofpkg
        try 
            @eval using $(Symbol(package))
        catch
            println("Installing $package ...")
            Pkg.add(package)
            @eval using $(Symbol(package))
        end
    end
end

usingpkg("DelimitedFiles, CSV, DataFrames, Makie")

# Read the last line of a (`.out`) file
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

# Split a file path into path, filename
function splitpath(pathfn)
    return dirname(pathfn)*"/", basename(pathfn)
end

function get_all_ext(dir; ext=".gif")
    path_to_exts = Vector{String}()
    for (root, dirs, files) in walkdir(dir)
        for file in files
            if endswith(file, ext)
                push!(path_to_exts, joinpath(root, file))
            end
        end
    end
    return path_to_exts
end

function get_all_dir_ext(dir="/home/"; ext=".gif")
    path_to_exts = Vector{String}()
    for (root, dirs, files) in walkdir(dir)
        for file in files
            if endswith(file, ext)
                push!(path_to_exts, joinpath(root))
                break
            end
        end
    end
    return path_to_exts
end

function generate_dataframe(listname, listtab; fn="")
    println("Generate DataFrame")
    ntab = length(listtab)
    nsim = 1
    for i=1:ntab
        nsim *= length(listtab[i])
    end
    tabid = 1:nsim
    
    df = DataFrame([[listtab[i][1] for _ in 1:nsim ] for i = 1:length(listname)] , listname)
    
    count = 1

    for i=1:length(listtab)
        if length(listtab[i]) == 1
            df[!, listname[i]] .= listtab[i][1]
        else
            for j=1:Int(nsim/count)
                df[(j-1)*count+1:j*count, listname[i]] .= listtab[i][(j-1)%length(listtab[i])+1]
            end
            count *= length(listtab[i])
        end
    end
    if fn != "NO"
        insertcols!(df, 1, :fn => fn.*string.(tabid))
    end
    println("   Number of rows: $nsim")
    return df
end

function generate_csv(dir, listname, listtab, name="DF"; fn="")
    isdir(dir) ? nothing : mkpath(dir)
    df = generate_dataframe(listname, listtab, fn=fn)
    println("Right DataFrame")
    CSV.write(joinpath(dir,name*".csv"), df)
end

function displaysize()
    size = Vector{Int}()
    if Sys.iswindows()
        for i in split(readchomp(`wmic path Win32_VideoController get CurrentHorizontalResolution,CurrentVerticalResolution`))
            isnothing(tryparse(Int, i)) ? nothing : push!(size, parse(Int,i))
        end
        return size
    else
        return [Makie.primary_resolution()[1], Makie.primary_resolution()[2]]
    end
end

## ONLY IF EXPLICITLY QUOTED EXPRESSIONS
function concatenate_expressions(e1, e2)
    return Base.remove_linenums!(Meta.parse(string(Base.remove_linenums!(e1))[1:end-3]*string(Base.remove_linenums!(e2))[6:end]))
end

# For indexing GPU kernel: @indexing_XD with X the dimension of your grid
macro indexing_1D() 
    esc(quote
        i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
    end)
end

macro indexing_2D() 
    esc(quote
        i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
        j = (blockIdx().y - 1) * blockDim().y + threadIdx().y
    end)
end

macro indexing_3D() 
    esc(quote
        i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
        j = (blockIdx().y - 1) * blockDim().y + threadIdx().y
        k = (blockIdx().z - 1) * blockDim().z + threadIdx().z
    end)
end