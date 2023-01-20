# JuliaBenchmarker.jl

a https://perf.rust-lang.org/ like rest api for julia


make sure that you have juliaup installed 

run test/server.jl 
warning! endpoints delete .julia/environments/{channel} and .julia/registries/{channel}


a big thing to do is adding a bunch of different command line args to test, for instance, optlevel

## todo
* do something with https://github.com/JuliaPerf/LinuxPerf.jl
