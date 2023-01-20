using Oxygen, HTTP
using CSV, DataFrames, JSON3, JSONTables
using Plots

const DATADIR = joinpath(@__DIR__, "../data")
const TABLES_DF = CSV.read(joinpath(DATADIR, "tables.csv"), DataFrame)
const OBJ_TABLE = objecttable(TABLES_DF)
const CHANNELS = ("1.6", "1.7", "1.8") #, "1.9")

function parse_at_time(s)
    parts = split(s, " ")
    secs = parts[1]
    alloc_count = join(parts[[3, 4]], " ")[2:end]
    alloc_amt = join(parts[[6, 7]], " ")[1:end-1]
    gc_pct = parts[8]
    comp_pct = parts[11]
    (; secs, alloc_count, alloc_amt, gc_pct, comp_pct)
end

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
    jl_cmd = """using Pkg; Pkg.activate(;temp=true); @time Pkg.add(\"$pkg\")"""

    cmd = `$juliabin --startup=no -e $jl_cmd`
    s = read(cmd, String)
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



for ep in [:code_llvm, :code_lowered, :code_native, :code_typed, :code_warntype]
    @get "/$ep/{fstr}/{args}" function (req, fstr, args)
        ex = Meta.parse(fstr)
        tup = Meta.parse(args)
        # @info ex, tup
        @assert tup.head == :tuple
        tt = tuple(typeof.(tup.args)...)
        f = @eval $ex
        io = IOBuffer()
        c_f = getproperty(InteractiveUtils, ep)
        c_f(io, f, tt)
        String(take!(io))
    end
end

@get "/versioninfo" function (req)
    io = IOBuffer()
    versioninfo(io)
    String(take!(io))
end

@get "/tables" function (req)
    JSON3.write(OBJ_TABLE)
end

# todo add queryparams for which juliaup channels to use 
@get "/precompile/{pkg}" function (req, pkg)
    q = queryparams(req)
    @info q
    xs = precomp_timing_table(pkg)
    df = DataFrame(xs)
    if get(q, "plot", nothing) == "true"
        plt = plot(df.version, parse.(Float64, df.secs))
        io = IOBuffer()
        png(plt, io)
        HTTP.Response(200, ["Content-Type"=>"image/png"]; body=take!(io))
    else
        JSONTables.objecttable(df)
    end
end

# @macroexpand @staticfiles("../data/", "static")

serve()
