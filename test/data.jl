using Pkg
Pkg.precompile()
using CSV, DataFrames, JSON3, JSONTables
s = "273.081066 seconds (7.46 M allocations: 583.687 MiB, 0.10% gc time, 0.06% compilation time)\n"

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