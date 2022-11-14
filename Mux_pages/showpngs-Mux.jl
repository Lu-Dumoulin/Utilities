include("../julia_utilities.jl")
usingpkg("PyPlot, JLD, Printf, FixedPointNumbers, FileIO, Base64, Colors, Images, CSV, DataFrames, Interact, Mux, TableView, Sockets")

function showpngb(filename; h="800px")
    open(filename) do f
        base64f = base64encode(f)
        return HTML("""<img src="data:image/png;base64,$base64f" style=height:$h>""")
    end
end

function showgifb(filename; h="800px")
    open(filename) do f
        base64_video = base64encode(f)
        return HTML("""<img src="data:image/gif;base64,$base64_video" style=height:$h>""")
    end
end

my_root = "F:/Asters/"

ui_pngs = Observable{Any}()
options = get_all_dir_ext(my_root; ext=".png") .* "/"
fn = dropdown(options, label="Select path of pngs") #autocomplete(options, label="Enter the path to pngs"; value="")#options[1])
pict = Observable{Any}()
sl = slider(1:10, value=1)

function getpict(t)
    if t > Nt
        return showpngb(dirf*"/"*getindex(lpict, Nt))
    else
        return showpngb(dirf*"/"*getindex(lpict, t))
    end
end


function getui_pngs(fn, sl)
    global dirf = string(fn)
    if isdir(dirf)
        if isdir(dirf)
            global lpict = readdir(dirf)
            global Nt = length(lpict)
            id = sl[]
            global sl = Interact.slider(1:Nt, value=id, label="t")
            map!(getpict, pict, sl)
            return dom"div"(style = Dict("width" => "1000px",
                                   "height" => "1000px"), pict, sl)
        else
            return dom"div"()
        end
    else
        return dom"div"()
    end
end
map!(getui_pngs, ui_pngs, fn, sl)

# @async Base.throwto(MUX_SERVER_TASK, InterruptException())
# while !(istaskdone(MUX_SERVER_TASK) || istaskfailed(MUX_SERVER_TASK))
#     yield()
# end