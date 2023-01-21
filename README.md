# JuliaBenchmarker.jl

a https://perf.rust-lang.org/ like rest api for julia

primarily the goal is to measure 
1. precompile times
2. using times
3. TTFX
for a bunch of different julia packages and versions


make sure that you have juliaup installed 

run test/server.jl 
warning! endpoints delete .julia/environments/{channel} and .julia/registries/{channel}


a big thing to do is adding a bunch of different command line args to test, for instance, optlevel

## todo
* do something with https://github.com/JuliaPerf/LinuxPerf.jl
* async for looping `doit` calls