using Oxygen, HTTP

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

serve()
