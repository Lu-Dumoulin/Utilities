  #####   #####  #     #    ######     #    ####### #     #   
 #     # #     # #     #    #     #   # #      #    #     #   
 #       #       #     #    #     #  #   #     #    #     #    
 #        #####  #     #    ######  #     #    #    #######   
 #             #  #   #     #       #######    #    #     #  
 #     # #     #   # #      #       #     #    #    #     #   
  #####   #####     #       #       #     #    #    #     #  

# Enter:
# Path to csv file
path_to_csv = "F:/2D_P_Q_PQ_5/DF.csv"

# ██████╗  ██████╗     ███╗   ██╗ ██████╗ ████████╗    ███╗   ███╗ ██████╗ ██████╗ ██╗███████╗██╗   ██╗    ██████╗ ███████╗██╗      ██████╗ ██╗    ██╗
# ██╔══██╗██╔═══██╗    ████╗  ██║██╔═══██╗╚══██╔══╝    ████╗ ████║██╔═══██╗██╔══██╗██║██╔════╝╚██╗ ██╔╝    ██╔══██╗██╔════╝██║     ██╔═══██╗██║    ██║
# ██║  ██║██║   ██║    ██╔██╗ ██║██║   ██║   ██║       ██╔████╔██║██║   ██║██║  ██║██║█████╗   ╚████╔╝     ██████╔╝█████╗  ██║     ██║   ██║██║ █╗ ██║
# ██║  ██║██║   ██║    ██║╚██╗██║██║   ██║   ██║       ██║╚██╔╝██║██║   ██║██║  ██║██║██╔══╝    ╚██╔╝      ██╔══██╗██╔══╝  ██║     ██║   ██║██║███╗██║
# ██████╔╝╚██████╔╝    ██║ ╚████║╚██████╔╝   ██║       ██║ ╚═╝ ██║╚██████╔╝██████╔╝██║██║        ██║       ██████╔╝███████╗███████╗╚██████╔╝╚███╔███╔╝
# ╚═════╝  ╚═════╝     ╚═╝  ╚═══╝ ╚═════╝    ╚═╝       ╚═╝     ╚═╝ ╚═════╝ ╚═════╝ ╚═╝╚═╝        ╚═╝       ╚═════╝ ╚══════╝╚══════╝ ╚═════╝  ╚══╝╚══╝ 

include("../Utilities/julia_utilities.jl")
usingpkg("Makie, JLD, Printf, FixedPointNumbers, FileIO, Base64, Colors, Images, CSV, DataFrames, Interact, Blink, WebIO")

dir, name_csv = splitpath(path_to_csv)

screen_size = displaysize()
hor_size = screen_size[1]
vert_size = screen_size[2]
hv = string(vert_size*0.85, "px")
hh = string(hor_size*0.75, "px")
wh = floor(Int, hor_size*0.9)
wv = floor(Int, vert_size*0.90)
buth = string(hor_size*(0.9-0.75),"px")


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

function showpngb(filename; h=hv)
    open(filename) do f
        base64f = base64encode(f)
        return HTML("""<img src="data:image/png;base64,$base64f" style=height:$h>""")
    end
end

function showgifb(filename; h=hv)
    open(filename) do f
        base64_video = base64encode(f)
        return HTML("""<img src="data:image/gif;base64,$base64_video" style=height:$h>""")
    end
end

Ncol = ncol(df)
Nrow = nrow(df)
var_list = names(df[:,setdiff(names(df), ["fn"])])
tab_list = [ sort!(unique(df[:,i])) for i in var_list]

sl_list = []
sl_name = []
var_list_sl = []
check_list =[] 
check_name = []
N_wid = 0
for i in 1:Ncol-1
    if length(tab_list[i]) > 1
        if isa((tab_list[i][1]), AbstractString)
            symbolname = Symbol("sl_$(var_list[i])")
            @eval $symbolname = $(togglebuttons(tab_list[i], label= "$(var_list[i])") ) 
            @eval push!(sl_list, $symbolname )
            push!(sl_name, "sl_$(var_list[i])")
        else
            symbolname = Symbol("sl_$(var_list[i])")
            @eval $symbolname = $(slider(tab_list[i], label= "$(var_list[i])") ) 
            @eval push!(sl_list, $symbolname )
            push!(sl_name, "sl_$(var_list[i])")
        end
        symbolname = Symbol("check_$(var_list[i])")
        @eval $symbolname = $(checkbox())
        @eval push!(check_list, $symbolname)
        push!(check_name, "check_$(var_list[i])")
        push!(var_list_sl, "$(var_list[i])")
        global N_wid += 1
    end
end

w = Window(Dict("width" => wh,"height" => wv))

radio_dir = Interact.radiobuttons( tab_fig_dir )
radio_png = Interact.togglebuttons( OrderedDict( "PNG"=> "PNG", "GIF"=> "GIF" ), value="PNG")
ui = Observable{Any}()
global fn = Observable{Any}(string(df[1,:fn])*"/")
pict = Observable{Any}()
sl = slider(1:2, value=1)

function getpict(t)
    if t > Nt
        return showpngb(dirf*getindex(lpict, Nt))
    else
        return showpngb(dirf*getindex(lpict, t))
    end
end

# for wid in 1:N_wid
#     eval(quote
#             onany($(sl_list[wid]), $(check_list[wid])) do x, y
#                 dist = zeros(Nrow)
#                 for r=1:Nrow
#                     for c=1:N_wid
#                         dist[r] += Int(df[r, Symbol(var_list_sl[c])] == sl_list[c][])*(1 + Int(check_list[c][])*100)
#                     end
#                 end
#                 idx = findmax(dist)[2]
#                 for c=1:N_wid
#                     if sl_list[c][] != df[idx, Symbol(var_list_sl[c])]
#                         sl_list[c][] = df[idx, Symbol(var_list_sl[c])]
#                     end
#                 end
#                 global fn[] = string(df[idx,:fn])*"/"
#             end
#         end)
# end

for wid in 1:N_wid
    eval(quote
            on($(check_list[wid])) do x
                dist = zeros(Nrow)
                for r=1:Nrow
                    for c=1:N_wid
                        dist[r] += Int(df[r, Symbol(var_list_sl[c])] == sl_list[c][])*(1 + Int(check_list[c][])*100)
                    end
                end
                idx = findmax(dist)[2]
                for c=1:N_wid
                    if sl_list[c][] != df[idx, Symbol(var_list_sl[c])]
                        sl_list[c][] = df[idx, Symbol(var_list_sl[c])]
                    end
                end
                global fn[] = string(df[idx,:fn])*"/"
            end
        end)
end

for wid in 1:N_wid
    eval(quote
            on($(sl_list[wid])) do x
                dist = zeros(Nrow)
                for r=1:Nrow
                    for c=1:N_wid
                        dist[r] += Int(df[r, Symbol(var_list_sl[c])] == sl_list[c][])*(1 + Int(check_list[c][])*100)
                    end
                end
                idx = findmax(dist)[2]
                for c=1:N_wid
                    if sl_list[c][] != df[idx, Symbol(var_list_sl[c])]
                        sl_list[c][] = df[idx, Symbol(var_list_sl[c])]
                    end
                end
                global fn[] = string(df[idx,:fn])*"/"
            end
        end)
end

function getui(fn, radio_dir, radio_png, sl)
    global dirf = joinpath(dir,fn) 
    dirf *= radio_dir
    if isdir(dirf) && length(readdir(dirf)) > 0
        if radio_png == "PNG"
            global lpict = filter!(endswith(".png"),readdir(dirf))
            global Nt = length(lpict)
            id = sl[]
            global sl = Interact.slider(1:Nt, value=id, label="t")
            map!(getpict, pict, sl)
            return dom"div"(style = Dict("width" => hh, "height" => hv), pict, sl)
        else
            gif_path = filter!(endswith(".gif"),readdir(dirf))
            if length(gif_path) == 0
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

eval(Meta.parse(string("""body!(w, dom"div"( hbox( vbox(radio_dir, radio_png, """)*join([ " hbox( $(sl_name[i]), $(check_name[i]) ), " for i in 1:N_wid ])[1:end-1]*string(") , ui)))")))

# eval(Meta.parse(string("""body!(w, dom"div"(hbox( vbox(radio_dir, radio_png, """)*join([ " hbox( $(sl_name[i]), $(check_name[i]) ), " for i in 1:N_wid ])[1:end-1]*string("), ui)))")))