include("showpngs-Mux.jl")
include("infocluster-Mux.jl")

println("Connect to $(string(Sockets.getipaddrs()[2])):8000/jobs/ for job infos")
println("Connect to $(string(Sockets.getipaddrs()[2])):8000/pngs/ for pngs")

global MUX_SERVER_TASK = WebIO.webio_serve(Mux.stack(page("/jobs/", dom"div"(hbox(b, b2, b3), ui_jobs), 8000), page("/pngs/", dom"div"(fn, ui_pngs), 8000)))