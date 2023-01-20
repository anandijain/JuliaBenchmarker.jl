using Pkg

for v in ("1.6", "1.7", "1.8", "1.9")   # customize these to the versions you have and how you launch them

    # rm(expanduser("~/.julia/compiled/"); recursive=true)   # clear all precompiled files
    
    run(`$juliabin -e 'using Pkg; @time Pkg.precompile("ThePkgIWantToPrecompile")'`)
end

