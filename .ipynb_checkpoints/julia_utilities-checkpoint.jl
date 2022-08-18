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

usingpkg("FixedPointNumbers, FileIO, Base64")

function showpng(filename)
    open(filename) do f
        base64f = base64encode(f)
        display("text/html", """<img src="data:image/png;base64,$base64f">""")
    end
end

function showgif(filename)
    open(filename) do f
        base64_video = base64encode(f)
        display("text/html", """<img src="data:image/gif;base64,$base64_video">""")
    end
end

# Convert pngs into gif file
function pngstogif(dirpngs, dirgif, name, fps)
    list = readdir(dirpngs)
    a = size(load(string(dirpngs,list[1])))
    l = length(list)
    if l>250
        rang = Int.(floor.(range(1, l, 201)))
        global l = 201
    else
        rang = 1:l
    end
    imgs = rand(RGB{N0f8}, a[1], a[2], l)
    for i in 1:l
        imgs[:,:,i] = load(string(dirpngs,list[i]))
        imgs[:,:,i] = load(string(dirpngs,list[rang[i]]))
    end
    FileIO.save(string(dirgif, name, ".gif"), imgs; fps = fps)
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