include("julia_utilities.jl")
usingpkg("FixedPointNumbers, FileIO, Base64")

import .JulUtils

module PictUtils
export showpng, showgif, pngstogif
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
    a = size(load(string(dirpngs,list[1])))
    l = length(list)
    if l>Nimg
        rang = Int.(floor.(range(1, l, Nimg)))
        global l = Nimg
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
end