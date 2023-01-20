using JuliaBenchmarker
using Oxygen, HTTP
using CSV, DataFrames, JSON3, JSONTables
using Plots

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
@get "/precompile/{pkg}" precompile_resp


@get "/time_imports/{c}/{pkg}" function (req, c, pkg)
    JSONTables.objecttable(time_imports_df(c, pkg))
end


# @macroexpand @staticfiles("../data/", "static") 

serve()
