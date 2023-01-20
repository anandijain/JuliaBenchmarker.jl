module JuliaBenchmarker

# using Oxygen, HTTP
using CSV, DataFrames
# , JSON3, JSONTables
# using Plots
using Pkg, InteractiveUtils

const DATADIR = joinpath(@__DIR__, "../data")
const TABLES_DF = CSV.read(joinpath(DATADIR, "tables.csv"), DataFrame)
const OBJ_TABLE = objecttable(TABLES_DF)
# const CHANNELS = ("1.4", "1.5", "1.6", "1.7", "1.8") #, "1.9")
CHANNELS = ("1.5", "1.6", "1.7", "1.8") #, "1.9")


function parse_at_time(s)
    parts = split(s, " ")
    secs = parts[1]
    alloc_count = join(parts[[3, 4]], " ")[2:end]
    alloc_amt = join(parts[[6, 7]], " ")[1:end-1]
    gc_pct = parts[8]
    # 1.5 hack
    if length(parts) == 10
        comp_pct = "missing"
    else
        comp_pct = parts[11]
    end
    (; secs, alloc_count, alloc_amt, gc_pct, comp_pct)
end

"""
i think my methodology may be wrong here. i think it might slant against CHANNELS[1] because i don't delete artifacts 
"""
function time_channel(c, pkg)
    # run(`juliaup add $c`) # this errors "Error: '1.6' is already installed."
    juliabin = "julia-" * c
    ch_comp_dir = expanduser("~/.julia/compiled/v$c")
    ispath(ch_comp_dir) && rm(ch_comp_dir; recursive=true)   # clear all precompiled files

    ch_env_dir = expanduser("~/.julia/environments/v$c")
    ispath(ch_env_dir) && rm(ch_env_dir; recursive=true)

    # we probably want to record versioninfo()
    # cmd = `$juliabin --startup=no -e 'using Pkg; x = @timed Pkg.add("SciMLBase"); open("foo.txt", "a") do io
    #     write(io, "join(string.(keys(x)), ", ") * "\n")
    #     end'`
    # cmd = `$juliabin --startup=no -e 'using Pkg; Pkg.activate(;temp=true); @time Pkg.add("Tables")'`
    # jl_cmd = """using Pkg; Pkg.activate(;temp=true); @time Pkg.add(\"$pkg\")"""
    jl_cmd = """using Pkg; io = IOBuffer(); @time Pkg.add(\"$pkg\";io=io)"""

    cmd = `$juliabin --startup=no -e $jl_cmd`
    s = read(cmd, String)
    # @info "timing result str" s
    nt = parse_at_time(strip(s))
    row = (; version=c, nt...)
    @info row
    row
end


function precomp_timing_table(pkg; ch=CHANNELS)
    xs = []
    for c in ch
        row = time_channel(c, pkg)
        push!(xs, row)
    end
    xs
end
function time_imports_str(c, pkg)
    juliabin = "julia-" * c

    jl_cmd = """using InteractiveUtils, Pkg; Pkg.activate(;temp=true); Pkg.add("$pkg"); @time_imports using $pkg"""
    cmd = `$juliabin --startup=no -e $jl_cmd`
    read(cmd, String)
end

function time_imports_df(c, pkg)
    s = time_imports_str(c, pkg)
    time_imports_str_to_df(s)
end

function time_imports_str_to_df(s)
    s = strip(s)
    ls = strip.(split(s, "\n"))
    cols = split.(ls, "  ")
    df = DataFrame(time=Float64[], unit=String[], pkg=String[], comp=Union{Missing,String}[])
    for (i, col) in enumerate(cols)
        time = first(col)
        time, unit = split(time, " ")
        time = parse(Float64, time)
        pkg_and_comp = last(col)
        foo = split(pkg_and_comp, " "; limit=2)
        length(foo) == 1 ? (pkg, comp) = (foo[1], missing) : (pkg, comp) = foo
        row = vec([time unit pkg comp])
        push!(df, row)
    end
    sort!(df, :time; rev=true)
    df
end

function precompile_resp(req, pkg)
    q = queryparams(req)
    @info q
    xs = precomp_timing_table(pkg)
    df = DataFrame(xs)
    if get(q, "plot", nothing) == "true"
        plt = plot(df.version, parse.(Float64, df.secs); xaxis="julia_version", yaxis="precompilation time [s]", legend=false, title="$pkg precompilation time")
        io = IOBuffer()
        png(plt, io)
        HTTP.Response(200, ["Content-Type" => "image/png"]; body=take!(io))
    else
        JSONTables.objecttable(df)
    end
end

"should we assume /compiled/ is empty for c? right now i dont"
function doit(c, pkg)
    ch_comp_dir = expanduser("~/.julia/compiled/v$c")
    ispath(ch_comp_dir) && rm(ch_comp_dir; recursive=true)   # clear all precompiled files

    juliabin = "julia-" * c
    vn = VersionNumber(c)

    rundir = joinpath(JuliaBenchmarker.DATADIR, "runs")
    !ispath(rundir) && mkpath(rundir)
    ch_dir = replace(c, "." => "_")
    # str = pkg * "_" * replace(c, "." => "_")
    dir = joinpath(rundir, pkg, ch_dir)
    mkpath(dir)
    Pkg.activate(dir)
    proj = Pkg.project()
    ptoml = proj.path
    id = basename(dirname(proj.path))

    jl_vinfo = """using Pkg, InteractiveUtils; Pkg.activate("$ptoml";io = IOBuffer()); versioninfo()"""
    cmd = `$juliabin --startup=no -e $jl_vinfo`
    s = read(cmd, String)
    write(joinpath(dir, "versioninfo.txt"), s)

    # im getting suspicious results here (~0.3 seconds for DataFrames)
    # jl_cmd = """using Pkg; Pkg.activate("$ptoml";io = IOBuffer()); io = IOBuffer(); Pkg.add("$pkg"; io=IOBuffer(), preserve=PRESERVE_ALL); @time Pkg.precompile(;io=io)"""
    jl_cmd = """using Pkg; Pkg.activate("$ptoml";io = IOBuffer()); io = IOBuffer(); @time Pkg.add("$pkg"; io=IOBuffer(), preserve=PRESERVE_ALL)"""
    cmd = `$juliabin --startup=no -e $jl_cmd`
    s = read(cmd, String)
    write(joinpath(dir, "$pkg.txt"), s)
    # touch(joinpath(dir, "$(pkg)_$c"))

    if vn >= v"1.8.0"
        jl_cmd = """using Pkg, InteractiveUtils; Pkg.activate("$ptoml"; io = IOBuffer()); @time_imports using $pkg"""
        cmd = `$juliabin --startup=no -e $jl_cmd`
        s = read(cmd, String)
        df = time_imports_str_to_df(s)
        CSV.write(joinpath(dir, "time_imports.csv"), df)
    end
    # run(`mv $dir $rundir`)
    newp = joinpath(rundir, id)
    @assert ispath(newp)
    Pkg.activate(joinpath(@__DIR__, ".."))
    newp

end

function getdirpkgname(dir)
    fns = readdir(dir; join=true)
    filter!(x -> endswith(x, ".txt") && !endswith(x, "versioninfo.txt"), fns)
    x = only(fns)
    splitext(basename(x))[1]
end

export precompile_resp, time_imports_df, precomp_timing_table, time_channel, parse_at_time, time_imports_str_to_df

end # module JuliaBenchmarker
