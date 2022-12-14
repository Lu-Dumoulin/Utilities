# How to use Code to Cluster

## Intro

### The files
- **using.jl**: contains
1. The `using_pkg()` function that install the packages if not installed yet.
2. The `using_mod()` function to load and define the module if not already defined.
Example:
```julia
include("using.jl")
using_pkg("CUDA, JLD")
using_mod(".SSH, .JulUtils")
```
- **JulUtils.jl**: contains the `JulUtils` module with useful functions.

Example:
```julia
JulUtils.screensize() # return the screen size in pxl
JulUtils.generate_dataframe(listname, listtab) # generate a DataFrame with all permutaions of parameters
```

- **PictUtils.jl**: `PictUtils` module with:
    1. 
    2.

example
```julia
include("PictUtils.jl")
PictUtils.pngstogif(...) # Convert all the .png of a folder in a .gif
```

- **SSH.jl**: Contains the `SSH` module with:
    1. basic `ssh()` function
    2. `File` module to create directory, check if a file exists, ...
    3. `Print` module 
    4. `Get` module
    5. `SCP` module
    
example


- **Code2Cluster.jl**
- **infoclusterblink.jl**
- **scan_param_pngs.jl**
- **ssh_login.jl**

### Login
In ssh_login.jl, you have to enter your username
```julia
# Username and host for ssh connection
# the host is the remote server name, I added the '@' for simplicity
const username = "..."; const host ="@login2.baobab.hpc.unige.ch"
```
Then the path of your home directory will be automatically saved in `cluster_home_path`:
```julia 
# In ssh_utilities.jl
const cluster_home_path = "/home/users/$(username[1])/$username/"
```
and, in order to run an ssh command, you just have to use the function `ssh()` of ssh_utilies.jl:
```julia
# In ssh_utilities.jl
ssh(cmd) = readchomp(`ssh $username$host $cmd`)
```

## General command
If you want to run a ssh command on the cluster you can use the function `ssh("command")`. If you want to run a ssh command and want to print the result in the console you can use `ssh_print("commande")`. For example if you want to check the status of the gpus:
```julia 
SSH.ssh_print("squeue --nodes=gpu[020-022,027-031]")
```

Some general commands are already written:
```julia
SSH.Print.infogpus() # Print gpu status
SSH.Print.quota(user=username) # Print disk quota

SSH.Print.squeue(; username=username, opt="") # As squeue
SSH.Print.seff(jobID) # Print efficiency of your job

SSH.Print.scancel(jobID) # scancel

SSH.Print.out(jobID) # Print the .out of the job of id jobID
SSH.Print.lastout() # Print the .out of the last job
SSH.Print.lastout(inc) # Print the .out of the (last+inc)th job
```
If you `include("Code2Cluster.jl")` then `SSH.Print.` is not needed.

## Run a simulation on the cluster
You have to `include("Code2Cluster.jl")` in console with julia.

### Input Parameters

In order to run your simulation on the cluster using only one line of code, the name of the variable indicating the name of the directory where you want to save data have to be `dir =` .

```julia
dir = "/home/jupyter-ludo/Data/Asters/sim1/" 
mkpath(dir)
```

If you want to download the data generated by your job you have to specify where you want to download the data on your computer `localpath`.
The two `println("... ` lines are mandatory with this exact syntax.

```julia
localpath = "I:/DATA_TEMP/Asters/sim1/"

println("path_c = ", dir)
println("path_l = ", localpath)
```

### run_one_sim() function

The function is:
```julia
run_one_sim(local_code_path, julia_filename, cluster_code_dir, cluster_save_directory, stime; partitions="private-kruse-gpu", mem="3000", sh_name="C2C.sh", input_param_namefile = "InputParameters.jl")
```
One example:
```julia
run_one_sim("D:/Code/mycode/", "something.jl", "mycode/", "Data/test/", "0-00:30:00"; partitions="private-kruse-gpu,shared-gpu")
```
It is also possible to define a "shortcut" function, example:
```julia
cd("D:/Code/")
include("Utilities/Code2Cluster.jl")

# Shortcut to run Mathieu DPD sim on all gpus
runMat_allgpus(dir_clu, stime) = run_one_sim("Mathieu/", "main.jl", "Mathieu/", "Data/Mathieu/"*dir_clu, stime, partitions="private-kruse-gpu,shared-gpu")

# An other shortcut to run Mathieu DPD sim on private gpus
runMat_privategpus(dir_clu, stime) = run_one_sim("Mathieu/", "main.jl", "Mathieu/", "Data/Mathieu/"*dir_clu, stime)

```
and then call it, the data will be save on the cluster in "Data/Mathieu/sim1/", duration of sim 12h:
```julia
runMat_allgpus("sim1/", "0-12:00:00")
```

## Scan a parameter space

### Generate a DataFrame

#### Direct way

Call function:
```julia 
JulUtils.generate_csv(saving_directory, list_col_name, list_tab; name="DF", fn="")
```

#### For specific use
```julia
...
## Rho
tar = [5.0, 7.0, 9.0]
## Friction
txi = [1.0, 10.0, 100.0]

ttype = ["P", "Q", "PQ"]

listname = ["rho0", "rhocr", "ap", "nu", "gamma", "kp", "aq", "lambda", "Gamma", "kq", "zetap", "zetaq", "a", "ar", "xi", "ttype"]
listtab = [t??0, t??cr, tap, t??, t??, tkp, taq, t??, t??, tkq, t??p, t??q, ta, tar, txi, ttype];

df = generate_dataframe(listname, listtab; fn="NO");
for i=1:nrow(df)
    df[i, :lambda] = df[i, :nu]
    df[i, :Gamma] = df[i, :gamma]
    if df[i,:ttype]=="Q"
        df[i, :ap] = 0.0
        df[i, :kp] = 0.0
        df[i, :zetap] = 0.0
        df[i, :nu1] = 0.0
        df[i, :gamma] = 0.0
    elseif df[i,:ttype]=="P"
        df[i, :aq] = 0.0
        df[i, :kq] = 0.0
        df[i, :zetaq] = 0.0
        df[i, :lambda] = 0.0
        df[i, :Gamma] = 0.0
    end
end
unique!(df)
insertcols!(df, 1, :fn => 1:nrow(df))
CSV.write(joinpath(dir,"DF.csv"), df)

println("Number of sims :", nrow(df))
```

### How to enter your Input Parameters

#### Input Parameters to explore
```julia
include("../Utilities/julia_utilities.jl")

dir = @__DIR__

# Non-dimensionalized parameters
t??0 = [0.8, 1.0, 1.2]
t??cr = [0.2]

## Polar
tap = [1.0]
# P - v, h, ????P
t??1 = [-1.0]
t?? = [1.0]
tkp = [1.0e-3]

## Nematic
taq = [1.0]
# Q - v, H, ????Q
t?? = [-1.0]
t?? = [1.0]
tkq = [1.0e-3]

## Stress
# Active Polar/Nematic ??pP_zP_z, ??qQ
t??p=[0.0, 0.5, 1.0]
t??q=[0.0, 0.5]
ta = [5.0, 7.0, 9.0]

## Rho
tar = [5.0]
## Friction
txi = [1.0, 10.0, 100.0]

ttype = ["P", "Q", "PQ"]

listname = ["rho0", "rhocr", "ap", "nu1", "gamma", "kp", "aq", "lambda", "Gamma", "kq", "zetap", "zetaq", "a", "ar", "xi", "ttype"]
listtab = [t??0, t??cr, tap, t??1, t??, tkp, taq, t??, t??, tkq, t??p, t??q, ta, tar, txi, ttype];

generate_csv(dir, listname, listtab, name="DF")
```

#### Common Input Parameters
The InputParameters.jl file
```julia
include("../Utilities/julia_utilities.jl")
usingpkg("FFTW, Distributions, DelimitedFiles, CSV, DataFrames, Dates, Printf, JLD, CUDA")

idx = Base.parse(Int, ENV["SLURM_ARRAY_TASK_ID"])

dir = "..." 
@show fn = "$idx/"
file = joinpath(dir, fn)
# path to save Data on computer
localpath = "F:/Serie-9/"
mkpath(file)

dir_df = @__DIR__
df = CSV.read(joinpath(dir_df,"DF.csv"), DataFrame)[idx,:]

Tf = Float64

??x = 4e-3; ??z = 4e-3
??x2 = ??x*??x; ??z2 = ??z*??z
??t = Tf(1e-4)
L = 10.0
N = L / ??x

WrapsT = 16
Bx = ceil(Int, N/WrapsT)
Bz = ceil(Int, N/WrapsT)
block_dim = (WrapsT, WrapsT)
grid_dim = (Bx, Bz)
gridFFT_dim = (div(Bx,2)+1, Bz)

...

## Polar
ap=Tf(df[:ap])
# P - v, h, ????P
??=Tf(df[:nu]); 
??=Tf(df[:gamma])
kp=Tf(df[:kp])

## Nematic
aq=Tf(df[:aq])
# Q - v, H, ????Q
??=Tf(df[:lambda]) 
??=Tf(df[:Gamma])
kq=Tf(df[:kq])

...

println("path_c = ", dir)
println("path_l = ", localpath)
println(idx)

```

### run_arra_DF() function
```julia
run_array_DF(local_code_path, julia_filename, cluster_code_dir, cluster_save_directory, stime; df_name="DF.csv", partitions="private-kruse-gpu,shared-gpu", mem="3000", sh_name="C2C_array.sh", input_param_namefile = "InputParameters.jl")
```
example:
```julia
run_array_DF("D:/Code/mycode/", "something.jl", "mycode/", "mydata/", "0-12:00:00")
```

### Make your plots and explore the parameter space

# Job info with Blink


```julia

```

# How to use the JupyterHub

### Create your password and first login

1. Type  `jupyter-kruse.unige.ch` in your web browser.
2. Enter your first name and choose your password

### Add IJulia with optimized kernel
1. Open a terminal
2. Type `julia`
3. copy past
```julia 
using Pkg; 
Pkg.add("IJulia"); 
using IJulia; 
installkernel("Julia opt", "-O3", env=Dict("FOO"=>"yes"))
```

### Restart your server

1. Clic on `File` (top left)
2. Clic on `Hub Control Panel`
3. `Stop my server`
4. `Start my server`

### Install CUDA for Julia

1. Open a Julia opt console
2. Copy paste
```julia
using Pkg
Pkg.add("CUDA")
using CUDA
CUDA.versioninfo()
```

### Create your Code folder and download Utilities
1. Copy this link `https://github.com/Lu-Dumoulin/Utilities` , to easily copy-paste you can press shift during the right-clic in order to have the usual option 
2. Right-clic -> `New Folder`
3. Name your folder
4. Select it in order to have it open
5. Clic on the Git icon and on `Clone a Repository`
6. Paste the link
7. If the Utilities folder is not at the right place you can drag and drop it in the right folder

### Configure the access to the cluster from the jupyter-hub
It is necessary to use SSH key login, which removes the need for a password for each login, thus ensuring a password-less, automatic login process:
1. Open a terminal
2. Type `ssh-keygen` and follow instruction to generate public and private key files stored in the ~/.ssh directory
(do not enter un phrase-pass)
3. Then copy the public key in the ~/.ssh/authorized_keys file, on ubuntu you can use
 `ssh-copy-id -i ~/.ssh/id_rsa.pub user@remote_host`

# In case of error:

## Handler error:
1. In a terminal get the list of the kernel: `jupyter kernelspec list`
2. Remove the julia kernels: `jupyter kernelspec uninstall julia-*`
3. Install the new kernel:
` julia `

```julia 
using Pkg; 
Pkg.add("IJulia"); 
using IJulia; 
installkernel("Julia", "-O3", env=Dict("FOO"=>"yes"))
```
