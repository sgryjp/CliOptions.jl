using Test
using CliOptions

sorted_keys = sort ∘ collect ∘ keys
function Base.redirect_stdout(f::Function, stream::IOBuffer)
    backup = stdout
    rd, wr = redirect_stdout()
    try
        f()
    finally
        redirect_stdout(backup)
        close(wr)
        write(stream, read(rd))
        close(rd)
    end
end
function Base.redirect_stderr(f::Function, stream::IOBuffer)
    backup = stderr
    rd, wr = redirect_stderr()
    try
        f()
    finally
        redirect_stderr(backup)
        close(wr)
        write(stream, read(rd))
        close(rd)
    end
end

tests = [
    "internals.jl",
    "abstractoptiongroup.jl",
    "clioptionspec.jl",
    "parseresult.jl",
    "option.jl",
    "flagoption.jl",
    "counteroption.jl",
    "helpoption.jl",
    "positional.jl",
    "remainderoption.jl",
    "parse_args.jl",
    "usage.jl",
]

targets = String[]
let i = 1
    while i ≤ length(ARGS)
        if ARGS[i] == "-h" || ARGS[i] == "--help"
            println("Usage: julia \"$PROGRAM_FILE\" [TEST_NAME...]")
            println()
            println("Available Tests:")
            for test_filename in tests
                println("    " * test_filename[1:end-3])
            end
            exit()
        else
            for t in tests
                if startswith(t, ARGS[i])
                    push!(targets, t)
                end
            end
        end

        i += 1
    end
end
if length(targets) == 0
    append!(targets, tests)
end

@testset "CliOptions" begin
    foreach(t -> include(t), targets)
end
