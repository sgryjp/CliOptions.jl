using Test
using CliOptions

testfiles = [ent for ent in readdir(dirname(@__FILE__))
             if endswith(ent, ".jl") && ent != basename(@__FILE__)]

targets = String[]
let i = 1
    while i ≤ length(ARGS)
        if ARGS[i] == "-h" || ARGS[i] == "--help"
            println("Usage: julia \"$PROGRAM_FILE\" [TEST_NAME...]")
            println()
            println("Available Tests:")
            for testfile in testfiles
                println("    " * testfile[1:end-3])
            end
            exit()
        else
            for t in testfiles
                if startswith(t, ARGS[i])
                    push!(targets, t)
                end
            end
        end

        i += 1
    end
end
if length(targets) == 0
    append!(targets, testfiles)
end

@testset "CliOptions" begin
    foreach(t -> include(t), targets)
end
