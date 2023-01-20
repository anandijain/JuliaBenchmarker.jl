using JuliaBenchmarker
using Test

# run(pipeline(`curl -fsSL https://install.julialang.org`, `sh -s -- -y`))
# run(`juliaup config channelsymlinks true`)
run(`source /home/runner/.bash_profile`)

pkgs = ["Tables", "OrdinaryDiffEq", "DifferentialEquations", "ModelingToolkit", "Plots"]
pkgs = ["CSV", "DataFrames", "Plots"]
channels = "1." .* string.(6:9)

# seems like this loop fails w @async
# for c in channels[1:end-1] # dont do 1.9 cuz it fucks up my env
for c in channels # on ci, i dont care
    # run(`juliaup add $c`)
    for pkg in pkgs
        JuliaBenchmarker.doit(c, pkg)
    end
    # JuliaBenchmarker.doit(c, "DataFrames")
end

d = joinpath(JuliaBenchmarker.DATADIR, "runs", "DataFrames", "1_8")
@test isdir(d)
@test !isempty(readdir(d))
