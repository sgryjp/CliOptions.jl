using Test
using CliOptions

sorted_keys = sort ∘ collect ∘ keys

tests = [
    "internals.jl",
    "parseresult.jl",
    "option.jl",
    "flagoption.jl",
    "counteroption.jl",
    "positional.jl",
    "parse_args.jl",
    "usage.jl",
]
targets = [lowercase(a) * ".jl" for a in ARGS]

if "-h" in ARGS || "--help" in ARGS
    println("Usage: julia \"$PROGRAM_FILE\" [TEST_NAME...]")
    println()
    println("Available Tests:")
    for test_filename in tests
        println("    " * test_filename[1:end-3])
    end
    exit()
end

@testset "CliOptions" begin
    for test_filename in tests
        if length(targets) == 0 || test_filename in targets
            include(test_filename)
        end
    end
end
