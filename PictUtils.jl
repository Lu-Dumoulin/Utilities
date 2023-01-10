include("using.jl")
using_pkg("FixedPointNumbers, FileIO, Base64, Colors")
using_mod(".JulUtils")

module PictUtils
export showpng, showgif, pngstogif
import ..JulUtils
using FixedPointNumbers, FileIO, Base64, Colors

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
function pngstogif(dirpngs, dirgif, name, fps; Nimg = 201)
    list = JulUtils.filter_ext(readdir(dirpngs),".png")
    a = size(FileIO.load(string(dirpngs,list[1])))
    l = length(list)
    if l>Nimg
        rang = Int.(floor.(range(1, l, Nimg)))
        global l = Nimg
    else
        rang = 1:l
    end
    imgs = rand(Colors.RGB{N0f8}, a[1], a[2], l)
    for i in 1:l
        imgs[:,:,i] = FileIO.load(string(dirpngs,list[i]))
        imgs[:,:,i] = FileIO.load(string(dirpngs,list[rang[i]]))
    end
    FileIO.save(string(dirgif, name, ".gif"), imgs; fps = fps)
end
end