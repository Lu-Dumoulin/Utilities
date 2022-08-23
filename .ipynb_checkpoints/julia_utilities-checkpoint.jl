using Pkg

@inline function usingpkg(st)
    listofpkg = split(st, ", ")
    for package in listofpkg
        try 
            @eval using $(Symbol(package))
        catch
            println("Installing $package ...")
            Pkg.add(package)
        end
    end
end

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

# # Move .ext from one dir to another one
# for (root, dirs, files) in walkdir("N:/2D-corr/")
#     for dir in dirs
#         mkpath(replace(joinpath(root, dir), "N:/" => "F:/"))
#     end
#     for file in files
#         if endswith(file, ".csv")
#             from = joinpath(root, file)
#             to = replace(from, "N:/" => "F:/")
#             mv(from, to, force=true)
#         end
#     end
# end