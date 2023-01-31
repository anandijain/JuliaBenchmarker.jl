using InteractiveUtils
@time_imports using JuliaBenchmarker, Oxygen, HTTP, CSV, DataFrames, JSON3, JSONTables, Plots
@info "usings"

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
@get "/precompile/{c}/{pkg}" function precompile_resp(req, c, pkg)
    q = queryparams(req)
    @info q
    xs = time_channel(c, pkg)
    df = DataFrame(xs)
    @info df
    if get(q, "plot", nothing) == "true"
        plt = plot(df.version, parse.(Float64, df.secs); xaxis="julia_version", yaxis="precompilation time [s]", legend=false, title="$pkg precompilation time")
        io = IOBuffer()
        png(plt, io)
        HTTP.Response(200, ["Content-Type" => "image/png"]; body=take!(io))
    else
        JSONTables.objecttable(df)
    end
end


@get "/time_imports_objtable/{c}/{pkg}" function (req, c, pkg)
    JSONTables.objecttable(time_imports_df(c, pkg))
end

@get "/time_imports/{c}/{pkg}" function (req, c, pkg)
    JSONTables.arraytable(time_imports_df(c, pkg))
end


# @macroexpand @staticfiles("../data/", "static") 

serve()
