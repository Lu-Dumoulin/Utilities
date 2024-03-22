  #####   #####  #     #    ######     #    ####### #     #   
 #     # #     # #     #    #     #   # #      #    #     #   
 #       #       #     #    #     #  #   #     #    #     #    
 #        #####  #     #    ######  #     #    #    #######   
 #             #  #   #     #       #######    #    #     #  
 #     # #     #   # #      #       #     #    #    #     #   
  #####   #####     #       #       #     #    #    #     #  

# Enter:
# Path to csv file
path_to_csv = "F:/noPQ/DF.csv"
# Choose where to display in: 
# 1 - web browser page
# 2 - a standalone window 
# 3 - vscode in the HTML plot panel / Notebook / Jupyterlab / Pluto
disp = 1


# ██████╗  ██████╗     ███╗   ██╗ ██████╗ ████████╗    ███╗   ███╗ ██████╗ ██████╗ ██╗███████╗██╗   ██╗    ██████╗ ███████╗██╗      ██████╗ ██╗    ██╗
# ██╔══██╗██╔═══██╗    ████╗  ██║██╔═══██╗╚══██╔══╝    ████╗ ████║██╔═══██╗██╔══██╗██║██╔════╝╚██╗ ██╔╝    ██╔══██╗██╔════╝██║     ██╔═══██╗██║    ██║
# ██║  ██║██║   ██║    ██╔██╗ ██║██║   ██║   ██║       ██╔████╔██║██║   ██║██║  ██║██║█████╗   ╚████╔╝     ██████╔╝█████╗  ██║     ██║   ██║██║ █╗ ██║
# ██║  ██║██║   ██║    ██║╚██╗██║██║   ██║   ██║       ██║╚██╔╝██║██║   ██║██║  ██║██║██╔══╝    ╚██╔╝      ██╔══██╗██╔══╝  ██║     ██║   ██║██║███╗██║
# ██████╔╝╚██████╔╝    ██║ ╚████║╚██████╔╝   ██║       ██║ ╚═╝ ██║╚██████╔╝██████╔╝██║██║        ██║       ██████╔╝███████╗███████╗╚██████╔╝╚███╔███╔╝
# ╚═════╝  ╚═════╝     ╚═╝  ╚═══╝ ╚═════╝    ╚═╝       ╚═╝     ╚═╝ ╚═════╝ ╚═════╝ ╚═╝╚═╝        ╚═╝       ╚═════╝ ╚══════╝╚══════╝ ╚═════╝  ╚══╝╚══╝ 

include("using.jl")
using_pkg("Makie, JLD, Printf, FixedPointNumbers, FileIO, Base64, Colors, Images, CSV, DataFrames, JSServe, Electron, Hyperscript, Observables")
import JSServe.TailwindDashboard as D
using_mod(".JulUtils")

dir, name_csv = JulUtils.splitpath(path_to_csv)

df = CSV.read(dir*name_csv, DataFrame)[:,1:end]
symb = Sys.iswindows() ? '\\' : '/'

all_dir = JulUtils.get_all_dir_ext(dir; ext=".png")
dir_names = Vector{String}()
for i in all_dir
    push!(dir_names, split(normpath(i), symb, keepempty=false)[end])
end
tab_fig_dir = unique(dir_names) .* "/"
dir_names = nothing
all_dir = nothing

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

app = App() do

    for i in 1:Ncol-1
        if length(tab_list[i]) > 1
            if isa((tab_list[i][1]), AbstractString)
                symbolname = Symbol("sl_$(var_list[i])")
                @eval $symbolname = $(D.Dropdown("$(var_list[i])", tab_list[i]) ) 
                @eval push!(sl_list, $symbolname )
                push!(sl_name, "sl_$(var_list[i])")
            else
                symbolname = Symbol("sl_$(var_list[i])")
                @eval $symbolname = $(D.Slider("$(var_list[i])", tab_list[i]))
                @eval push!(sl_list, $symbolname )
                push!(sl_name, "sl_$(var_list[i])")
            end
            symbolname = Symbol("check_$(var_list[i])")
            @eval $symbolname = $(D.Checkbox("", false))
            @eval push!(check_list, $symbolname)
            push!(check_name, "check_$(var_list[i])")
            push!(var_list_sl, "$(var_list[i])")
            global N_wid += 1
        end
    end

    global radio_dir = D.Dropdown("Directory:", tab_fig_dir )
    global radio_png = D.Dropdown("pngs or gif:", ["PNG", "GIF"]; index=2)
    global ui = Observable{Any}(DOM.div())
    global fn = Observable{Any}(string(df[1,:fn])*"/")
    global dirf = Observable(string(joinpath(dir,fn[]))*string(tab_fig_dir[1]))
    Nfiles = zeros(Nrow)
    for idx = 1:Nrow
        ifn = string(df[idx,:fn])*"/"
        idirf = string(joinpath(dir,ifn))*string(tab_fig_dir[1])
        isdir(idirf) ? Nfiles[idx] = length(joinpath.(idirf, filter!(endswith(".png"),readdir(idirf) ) )) : nothing
    end
    global Nt = Int(maximum(Nfiles))
    global sl = D.Slider("Time", 1:Nt)#length(filter!(endswith(".png"),readdir(dirf[]) )))
    global files = JSServe.Asset.(joinpath.(dirf[], filter!(endswith(".png"),readdir(dirf[]) ) ) )
    #length(files)
    global Npict = length(files)
    
    on(fn) do x
        dirf[] = string(dir,x,radio_dir.widget.value[])
    end
    
    on(radio_dir.widget.value) do x
        dirf[] = string(dir,fn[],x)
    end
    
    on(dirf) do x
        if !isdir(dirf[])
            ui[] = DOM.div()
        else
            if radio_png.widget.value[]=="PNG"
                global lpict = filter!(endswith(".png"),readdir(dirf[]))
                # global Nt = length(lpict)
                global Npict = length(lpict)
                global files = JSServe.Asset.(joinpath.(dirf[], lpict))
                id = sl.widget[]
                # if id <= Nt
                #     ui[] = DOM.div(DOM.img(src=files[id]), sl, "Simulation number $(fn[])")
                # else
                #     sl.widget[] = Nt
                #     ui[] = DOM.div(DOM.img(src=files[Nt]), sl, "Simulation number $(fn[])")
                # end
                if id <= Npict
                    ui[] = DOM.div(DOM.img(src=files[id]), sl, "Simulation number $(fn[])")
                else
                    # sl.widget[] = Npict
                    ui[] = DOM.div(sl, "Simulation number $(fn[])")#DOM.img(src=files[Nt]), sl, "Simulation number $(fn[])")
                end
            else
                gifpath = filter!(endswith(".gif"),readdir(dirf[]))
                if length(gifpath) == 0
                    ui[] = DOM.div()
                else
                    global files = JSServe.Asset.(joinpath.(dirf[], gifpath))
                    ui[] = DOM.div(DOM.img(src=first(files)), "Simulation number $(fn[])")
                end
            end
        end
    end
    
    on(sl.widget.value) do x
        if x<=Npict#t
            ui[] = DOM.div(DOM.img(src=files[x]), sl, "Simulation number $(fn[])")
        else
            ui[] = DOM.div(DOM.img(src=files[Npict]), sl, "Simulation number $(fn[])")
        end
    end

    for wid in 1:N_wid
        eval(quote
                on($(check_list[wid]).widget.value) do x
                    dist = zeros(Nrow)
                    for r=1:Nrow
                        for c=1:N_wid
                            dist[r] += Int(df[r, Symbol(var_list_sl[c])] == sl_list[c].widget.value[])*(1 + Int(check_list[c].widget.value[])*100)
                        end
                    end
                    idx = findmax(dist)[2]
                    for c=1:N_wid
                        if sl_list[c].widget.value[] != df[idx, Symbol(var_list_sl[c])]
                            if !isa(sl_list[c].widget.value[], AbstractString)
                                sl_list[c].widget[] = df[idx, Symbol(var_list_sl[c])]
                            else
                                sl_list[c].widget.value[] = df[idx, Symbol(var_list_sl[c])]
                            end
                        end
                    end
                    global fn[] = string(df[idx,:fn])*"/"
                end
            end)
    end

    for wid in 1:N_wid
        eval(quote
                on($(sl_list[wid]).widget.value) do x
                    dist = zeros(Nrow)
                    for r=1:Nrow
                        for c=1:N_wid
                            dist[r] += Int(df[r, Symbol(var_list_sl[c])] == sl_list[c].widget.value[])*(1 + Int(check_list[c].widget.value[])*100)
                        end
                    end
                    idx = findmax(dist)[2]
                    for c=1:N_wid
                        if sl_list[c].widget.value[] != df[idx, Symbol(var_list_sl[c])]
                            if !isa(sl_list[c].widget.value[], AbstractString)
                                sl_list[c].widget[] = df[idx, Symbol(var_list_sl[c])]
                            else
                                sl_list[c].widget.value[] = df[idx, Symbol(var_list_sl[c])]
                            end
                        end
                    end
                    global fn[] = string(df[idx,:fn])*"/"
                end
            end)
    end

    on(radio_png.widget.value) do x
        if x=="PNG"
            global lpict = filter!(endswith(".png"),readdir(dirf[]))
            global Npict = length(lpict)
            # global Nt = length(lpict)
            global files = JSServe.Asset.(joinpath.(dirf[], lpict))
            id = sl.widget[]
            # if id <= Nt
            #     ui[] = DOM.div(DOM.img(src=files[id]), sl, "Simulation number $(fn[])")
            # else
            #     sl.widget[] = Nt
            #     ui[] = DOM.div(DOM.img(src=files[Nt]), sl, "Simulation number $(fn[])")
            # end
            if id <= Npict
                ui[] = DOM.div(DOM.img(src=files[id]), sl, "Simulation number $(fn[])")
            else
                # sl.widget[] = Nt
                ui[] = DOM.div(sl, "Simulation number $(fn[])")#DOM.img(src=files[Nt]), sl, "Simulation number $(fn[])")
            end
        else
            gif_path = filter!(endswith(".gif"),readdir(dirf[]))
            if length(gif_path) == 0
                ui[] = DOM.div()
            else
                global files = JSServe.Asset.(joinpath.(dirf[], gif_path))
                ui[] = DOM.div(DOM.img(src=first(files)), "Simulation number $(fn[])")
            end
        end
    end
    
    sl.widget[] = 1

    return eval(Meta.parse(string(""" DOM.div( D.FlexRow( D.FlexCol(radio_dir, radio_png, """)*join([ " D.FlexRow( $(sl_name[i]), $(check_name[i]) ), " for i in 1:N_wid ])[1:end-1]*string(") , ui))")))
end
if disp == 1
    JSServe.browser_display()
    display(app)
elseif disp == 2   
    using Electron; 
    disp = JSServe.use_electron_display()
    Electron.toggle_devtools(disp.window) # devtools are open by default (should change this)
    display(disp, app)
else
    
end