

# JuliaBenchmarker.doit("1.8", "DataFrames")


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