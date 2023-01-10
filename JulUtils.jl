include("using.jl")
using_pkg("DelimitedFiles, CSV, DataFrames, Makie")

module JulUtils
export read_last_line, splitpath, get_all_ext, get_all_dir_ext, generate_dataframe, generate_csv, screensize, filter_ext, filter_ext!
# import .Main: import_pkg
using DelimitedFiles, CSV, DataFrames, Makie

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

    df = DataFrames.DataFrame([[listtab[i][1] for _ in 1:nsim ] for i = 1:length(listname)] , listname)

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
        DataFrames.insertcols!(df, 1, :fn => fn.*string.(tabid))
    end
    println("   Number of rows: $nsim")
    return df
end

function generate_csv(saving_directory, list_col_name, list_tab; name="DF", fn="")
    isdir(saving_directory) ? nothing : mkpath(saving_directory)
    df = generate_dataframe(list_col_name, list_tab, fn=fn)
    println("Write DataFrame")
    CSV.write(joinpath(saving_directory,name*".csv"), df)
end

function screensize()
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

@inline filter_ext!(list_of_file, ext) = filter!(endswith(ext), list_of_file)
@inline filter_ext(list_of_file, ext) = filter(endswith(ext), list_of_file)

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

end
