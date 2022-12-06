  #####   #####  #     #    ######     #    ####### #     #                            ### #     #    #     #####  #######                                        
 #     # #     # #     #    #     #   # #      #    #     #      ##   #    # #####      #  ##   ##   # #   #     # #          #    # ###### #  ####  #    # ##### 
 #       #       #     #    #     #  #   #     #    #     #     #  #  ##   # #    #     #  # # # #  #   #  #       #          #    # #      # #    # #    #   #   
 #        #####  #     #    ######  #     #    #    #######    #    # # #  # #    #     #  #  #  # #     # #  #### #####      ###### #####  # #      ######   #   
 #             #  #   #     #       #######    #    #     #    ###### #  # # #    #     #  #     # ####### #     # #          #    # #      # #  ### #    #   #   
 #     # #     #   # #      #       #     #    #    #     #    #    # #   ## #    #     #  #     # #     # #     # #          #    # #      # #    # #    #   #   
  #####   #####     #       #       #     #    #    #     #    #    # #    # #####     ### #     # #     #  #####  #######    #    # ###### #  ####  #    #   #   
                                                                                                                                                                                                                                                                                                                   
# Enter:
# Path to csv file
path_to_csv = "F:/2D_P_Q_PQ_3/DF.csv"
# # Height of the picture to show on your screen in px (Integer)
image_height = 2000

# ██████╗  ██████╗     ███╗   ██╗ ██████╗ ████████╗    ███╗   ███╗ ██████╗ ██████╗ ██╗███████╗██╗   ██╗    ██████╗ ███████╗██╗      ██████╗ ██╗    ██╗
# ██╔══██╗██╔═══██╗    ████╗  ██║██╔═══██╗╚══██╔══╝    ████╗ ████║██╔═══██╗██╔══██╗██║██╔════╝╚██╗ ██╔╝    ██╔══██╗██╔════╝██║     ██╔═══██╗██║    ██║
# ██║  ██║██║   ██║    ██╔██╗ ██║██║   ██║   ██║       ██╔████╔██║██║   ██║██║  ██║██║█████╗   ╚████╔╝     ██████╔╝█████╗  ██║     ██║   ██║██║ █╗ ██║
# ██║  ██║██║   ██║    ██║╚██╗██║██║   ██║   ██║       ██║╚██╔╝██║██║   ██║██║  ██║██║██╔══╝    ╚██╔╝      ██╔══██╗██╔══╝  ██║     ██║   ██║██║███╗██║
# ██████╔╝╚██████╔╝    ██║ ╚████║╚██████╔╝   ██║       ██║ ╚═╝ ██║╚██████╔╝██████╔╝██║██║        ██║       ██████╔╝███████╗███████╗╚██████╔╝╚███╔███╔╝
# ╚═════╝  ╚═════╝     ╚═╝  ╚═══╝ ╚═════╝    ╚═╝       ╚═╝     ╚═╝ ╚═════╝ ╚═════╝ ╚═╝╚═╝        ╚═╝       ╚═════╝ ╚══════╝╚══════╝ ╚═════╝  ╚══╝╚══╝ 

include("../Utilities/julia_utilities.jl")
usingpkg("PyPlot, JLD, Printf, FixedPointNumbers, FileIO, Base64, Colors, Images, CSV, DataFrames, Interact, Blink, WebIO")

dir, name_csv = splitpath(path_to_csv)

screen_size = displaysize()
maximal_size = minimum(screen_size)
he = string(image_height, "px")
hh = string(image_height+100, "px")
ww = floor(Int, image_height*1.25)
wh = floor(Int, image_height*1.1)

df = CSV.read(dir*name_csv, DataFrame)[:,1:end]
symb = Sys.iswindows() ? '\\' : '/'

all_dir = get_all_dir_ext(dir; ext=".png")
dir_names = Vector{String}()
for i in all_dir
    push!(dir_names, split(normpath(i), symb, keepempty=false)[end])
end
tab_fig_dir = unique(dir_names) .* "/"
dir_names = nothing
all_dir = nothing

function showpngb(filename; h=he)
    open(filename) do f
        base64f = base64encode(f)
        return HTML("""<img src="data:image/png;base64,$base64f" style=height:$h>""")
    end
end

function showgifb(filename; h=he)
    open(filename) do f
        base64_video = base64encode(f)
        return HTML("""<img src="data:image/gif;base64,$base64_video" style=height:$h>""")
    end
end

Ncol = ncol(df)
# var_list = names(df[:,2:end])
var_list = names(df[:,setdiff(names(df), ["fn"])])
tab_list = [ sort!(unique(df[:,i])) for i in var_list]

sl_list = []
sl_name = []
var_list_sl = []
N_sl = 0
for i in 1:Ncol-1
    if length(tab_list[i]) > 1
        symbolname = Symbol("sl_$(var_list[i])")
        @eval $symbolname = $(slider(tab_list[i], label="$(var_list[i])"))
        @eval push!(sl_list, $symbolname )
        push!(sl_name, "sl_$(var_list[i])")
        push!(var_list_sl, "$(var_list[i])")
        global N_sl += 1
    end
end

w = Window(Dict("width" => ww,"height" => wh))

radio_dir = Interact.radiobuttons( tab_fig_dir )
radio_png = Interact.togglebuttons( OrderedDict( "PNG"=> "PNG", "GIF"=> "GIF" ), value="PNG")
ui = Observable{Any}()
global fn = Observable{Any}(string(df[1,:fn])*"/")
fnpict = Observable{Any}("filename")
pict = Observable{Any}()
sl = slider(1:2, value=1)


function getpict(t)
    if t > Nt
        return showpngb(dirf*getindex(lpict, Nt))
    else
        return showpngb(dirf*getindex(lpict, t))
    end
end

for sll in sl_list
    eval(quote
            on($sll) do x
                df2 = CSV.read(dir*name_csv, DataFrame)[:,1:end]
                for i=1:N_sl
                    filter!(Symbol(var_list_sl[i]) => ==(sl_list[i][]),df2)
                end
                global fn[] = string(df2[1,:fn])*"/"
            end
        end)
end

function getui(fn, radio_dir, radio_png, sl)
    global dirf = joinpath(dir,fn)
    if isdir(dirf) && length(readdir(dirf*radio_dir)) > 0
        global dirf *= radio_dir
        if radio_png == "PNG"
            if isdir(dirf)
                global lpict = readdir(dirf)
                global Nt = length(lpict)
                id = sl[]
                global sl = Interact.slider(1:Nt, value=id, label="t")
                map!(getpict, pict, sl)
                return dom"div"(style = Dict("width" => he,
                                       "height" => hh), pict, sl)
            else
                return dom"div"()
            end
        else
            gif_path = filter!(endswith(".gif"),readdir(dirf))
            if length(gif_path) ==0
                return dom"div"()
            else
                return dom"div"(showgifb(dirf*gif_path[1]))
            end
        end
    else
        return dom"div"()
    end
end

map!(getui, ui, fn, radio_dir, radio_png, sl)

eval(Meta.parse(string("""body!(w, dom"div"(hbox( vbox(radio_dir, radio_png, """)*join([ " $(i)," for i in sl_name ])[1:end-1]*string("), ui)))")))
