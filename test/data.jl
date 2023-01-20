using Pkg
Pkg.precompile()
using CSV, DataFrames, JSON3, JSONTables
s = "273.081066 seconds (7.46 M allocations: 583.687 MiB, 0.10% gc time, 0.06% compilation time)\n"
"  1.338461 seconds (2.83 M allocations: 165.587 MiB, 3.62% gc time)\n"
parse_at_time(s)

run(`juliaup config channelsymlinks true`)
pkg = "OrdinaryDiffEq"


for c in ch
    ch_comp_dir = expanduser("~/.julia/compiled/v$c")
    ispath(ch_comp_dir) && rm(ch_comp_dir; recursive=true)
    ch_env_dir = expanduser("~/.julia/environments/v$c")
    ispath(ch_env_dir) && rm(ch_env_dir; recursive=true)
end

# x = @timed 2^23
# open("foo.txt", "w") do io
#     write(io, join(string.(keys(x)), ", ") * '\n')
# end
c = first(ch)


df = DataFrame(xs)
JSON3.write(df)

CSV.write("tables.csv", df)

PKG = "Tables"

Cmd


# runs
pkgs = ["Tables", "OrdinaryDiffEq", "DifferentialEquations", "ModelingToolkit", "Plots"]
c = channels[4]
pkg = pkgs[1]




doit("1.8", "OrdinaryDiffEq")
using JuliaBenchmarker
channels = "1." .* string.(6:8)
for c in channels
    JuliaBenchmarker.doit(c, "DataFrames")
end

JuliaBenchmarker.doit("1.8", "DataFrames")


d = Dict()
dfns = readdir(JuliaBenchmarker.DATADIR; join=true)
run_folders = filter(isdir, dfns)
for dir in run_folders
    pkg = getdirpkgname(dir)
    if !haskey(d, pkg)
        d[pkg] = dir
    else
        push!(d[pkg], dir)
    end
end