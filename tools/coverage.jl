using Coverage

const OUTDIR = "report"
const OUTFILE = joinpath(OUTDIR, "coverage.info")

function using_color()
    try
        return Base.JLOptions().color == 1  # Works in Julia 0.7-1.1 at least
    catch
        return false
    end
end

function clean(keep_intermediates)
    if !keep_intermediates
        clean_folder("test")
        clean_folder("src")
    end
end

# Check options
keep_intermediates = false
let i = 1
    global keep_intermediates
    while i ≤ length(ARGS)
        if ARGS[i] == "-k" || ARGS[i] == "--keep-intermediates"
            keep_intermediates = true
        end
        i += 1
    end
end

clean_folder(".")
try
    # CD to project root directory
    cd(dirname(dirname(@__FILE__)))

    # Regenerate coverage data
    @info "Start unit tests using Coverage.jl..."
    color = using_color() ? "yes" : "auto"
    run(`julia -O0 --project --color=$color --code-cover=user test/runtests.jl`)
    coverage = process_folder("src")

    # Print summary
    covered_lines, total_lines = get_summary(coverage)
    print("# of covered lines: ")
    printstyled(covered_lines, color=Base.info_color())
    println()
    print("# of total lines:   ")
    printstyled(total_lines, color=Base.info_color())
    println()
    print("Line Coverage:      ")
    printstyled(floor(covered_lines / total_lines * 100, sigdigits=3), "%", color=:green)
    println()

    # Save the stat
    @info "Writing \"$OUTFILE\"..."
    LCOV.writefile(OUTFILE, coverage)

    # Generate HTML report if LCOV is available
    @info "Generating coverage report into \"$OUTDIR/\"..."
    try
        run(`genhtml $OUTFILE -o $OUTDIR`)
    catch ex
        @info ex
    end

    clean(keep_intermediates)
    exit(0)
catch ex
    @error ex
    clean(keep_intermediates)
    exit(1)
end
