module JuliaBenchmarker

# using HTTP
using CSV, DataFrames
# , JSON3, JSONTables
# using Plots
using Pkg, InteractiveUtils

const DATADIR = joinpath(@__DIR__, "../data")
const TABLES_DF = CSV.read(joinpath(DATADIR, "tables.csv"), DataFrame)
# const OBJ_TABLE = objecttable(TABLES_DF)
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

function precomp_time_str_to_df(s)
    rs = precomp_time_nt(s)
    df = DataFrame(rs)
    sort!(df, :time; rev=true)
    df
end

function precomp_time_nt(s)
    s = strip(s)
    ss = strip.(split(s, "\n"))
    idx = findfirst(contains("dependencies"), ss)
    wall_time = split(ss[idx], " ")[end-1]
    parse_precomp_time_row.(ss[2:idx-1])
end

function parse_precomp_time_row(l)
    ms = collect(eachmatch(Base.ansi_regex, l))
    j = join(filter(x -> length(x) == 1, map(x -> x.match, ms)))
    xs = split(j)
    time, check = xs[[1, 3]]
    time = parse(Float64, time)
    if length(xs) == 6
        name, extname = xs[[4, 6]]
    else
        name = xs[4]
        extname = missing
    end
    (; time, check, name, extname)
end

function get_dfs(dir)
    s1, s2 = read.([joinpath(dir, "precomp.txt"), joinpath(dir, "using.txt")], String)
    precomp_time_str_to_df(s1), time_imports_str_to_df(s2)
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
    Pkg.activate(joinpath(@__DIR__, ".."))
    dir

end

function getdirpkgname(dir)
    fns = readdir(dir; join=true)
    filter!(x -> endswith(x, ".txt") && !endswith(x, "versioninfo.txt"), fns)
    x = only(fns)
    splitext(basename(x))[1]
end

"""give path of package in project, time precomp, using, and execute the script, generating a PProf"""
function time_bin(fn)
    p = abspath(fn)

    error()
end

function doit2(dir; c="1.10")
    # assume we have as little as possible compiled
    ENV["JULIA_PKG_PRECOMPILE_AUTO"] = false
    fs = ["compiled", "environments"]#, "artifacts"]
    for f in fs
        p = expanduser("~/.julia/$f/v$c")
        ispath(p) && rm(p; recursive=true)   # clear all precompiled files
    end
    io_ = IOBuffer()
    Pkg.activate(dir;io=io_)
    Pkg.resolve(;io=io_)
    Pkg.instantiate(;io=io_)
    io = IOBuffer()
    Pkg.precompile(; io, timing=true)
    s = String(take!(io))
    fn = joinpath(dir, "precomp.txt")
    write(fn, s)

    pkgs_str = join(collect(keys(Pkg.project().dependencies)), ", ")
    # is there a way to avoid starting a new julia process
    jl_cmd = """using Pkg, InteractiveUtils; Pkg.activate("$dir"; io = IOBuffer()); @time_imports using $pkgs_str"""
    cmd = `julia-nightly --startup=no -e $jl_cmd`

    s2 = read(cmd, String)
    fn2 = joinpath(dir, "using.txt")
    write(fn2, s2)
    Pkg.activate(dirname(@__DIR__))

    [fn, fn2]
end

export precompile_resp, time_imports_df, precomp_timing_table, time_channel, parse_at_time, time_imports_str_to_df

end # module JuliaBenchmarker
