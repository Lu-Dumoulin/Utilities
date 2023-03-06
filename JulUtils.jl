include("using.jl")
using_pkg("DelimitedFiles, CSV, DataFrames, Makie, Dates")

module JulUtils
export read_last_line, splitpath, get_all_ext, get_all_dir_ext, generate_dataframe, generate_csv, screensize, filter_ext, filter_ext!, make_code_back_up, automatic_back_up
# import .Main: import_pkg
using DelimitedFiles, CSV, DataFrames, Makie, Dates

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

function get_all_ext(dir; ext=".gif", hidden=false)
    path_to_exts = Vector{String}()
    for (root, dirs, files) in walkdir(dir)
        !hidden && contains(root, ".") && continue
        for file in files
            if endswith(file, ext)
                push!(path_to_exts, joinpath(root, file))
            end
        end
    end
    return path_to_exts
end

function get_all_dir_ext(dir="/home/"; ext=".gif", hidden=false)
    path_to_exts = Vector{String}()
    for (root, dirs, files) in walkdir(dir)
        !hidden && contains(root, ".") && continue
        for file in files
            if endswith(file, ext)
                push!(path_to_exts, joinpath(root))
                break
            end
        end
    end
    return path_to_exts
end

function make_code_back_up()
    back_up_path = joinpath(homedir(),".CODE_BACK_UP/")
    mkpath(back_up_path)
    dirname = string(Dates.today(),"/")
    
    # Remove oldest backup if more than 30 back up zip files
    in_dir = sort!(readdir(back_up_path))
    if length(in_dir) > 30
        println(" Remove oldest back up: ", in_dir[1])
        rm(back_up_path*in_dir[1], recursive = true)
    end
    
    println(" Make a back up of all julia files in a folder: ", back_up_path*dirname)
    if isfile(back_up_path*dirname)
        println("  Overwrite the back up of today")
        rm(back_up_path*dirname, recursive = true)
    end
    mkdir(back_up_path*dirname);
    path_to_jl = get_all_ext(homedir(), ext=".jl")
    new_names = similar(path_to_jl)
    for i=1:length(path_to_jl)
        tmp = Base.splitpath(path_to_jl[i])
        new_names[i] = tmp[end-1]*"_"*tmp[end]
        cp(path_to_jl[i], back_up_path*dirname*new_names[i])
    end
    println("Back up of all julia files in ",back_up_path*dirname)
end

function automatic_back_up()
    back_up_path = joinpath(homedir(),".CODE_BACK_UP/")
    println("Check if the back up of today is done")
    if !isdir(back_up_path)
        make_code_back_up()
    else
        dirname = string(Dates.today(),"/")
        if !isdir(back_up_path*dirname)
            make_code_back_up()
        else
            println("Back up of today is already done")
        end
    end
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

JulUtils.automatic_back_up()

# ZIP version
# function make_code_back_up()
#     back_up_path = joinpath(homedir(),".CODE_BACK_UP/")
#     mkpath(back_up_path)
#     namefile = string(Dates.today(),".zip")
    
#     # Remove oldest backup if more than 30 back up zip files
#     in_dir = sort!(readdir(back_up_path))
#     if length(in_dir) > 30
#         println(" Remove oldest back up: ", in_dir[1])
#         rm(back_up_path*in_dir[1])
#     end
    
#     println(" Make a back up of all julia files in a zip file: ", back_up_path*namefile)
#     if isfile(back_up_path*namefile)
#         println("  Overwrite the back up of today")
#         rm(back_up_path*namefile)
#     end
#     w = ZipFile.Writer(back_up_path*namefile);
#     path_to_jl = get_all_ext(homedir(), ext=".jl")
#     new_names = similar(path_to_jl)
#     for i=1:length(path_to_jl)
#         tmp = Base.splitpath(path_to_jl[i])
#         new_names[i] = tmp[end-1]*"_"*tmp[end]
#         cp(path_to_jl[i], back_up_path*new_names[i])
#         ZipFile.addfile(w, back_up_path*new_names[i])
#         rm(back_up_path*new_names[i])
#     end
#     close(w)
#     println("Back up of all julia file in ",back_up_path*namefile)
# end

# function automatic_back_up()
#     back_up_path = joinpath(homedir(),".CODE_BACK_UP/")
#     println("Check if the back up of today is done")
#     if !isdir(back_up_path)
#         make_code_back_up()
#     else
#         namefile = string(Dates.today(),".zip")
#         if !isfile(back_up_path*namefile)
#             make_code_back_up()
#         else
#             println("Back up of today is already done")
#         end
#     end
# end