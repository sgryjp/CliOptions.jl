using Coverage

# CD to project root directory
cd(dirname(dirname(@__FILE__)))

# Generate coverage data
if length([fn for fn in readdir("src") if endswith(fn, ".cov")]) == 0
    @info "No '.cov' file found. Generating..."
    function use_color()
        try
            return Base.JLOptions().color == 1
        catch
            return false
        end
    end
    color = use_color() ? "yes" : "auto"
    run(`julia -O0 --project --color=$color --code-cover=user test/runtests.jl`)
end
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

# Save the stat and remove coverage data
LCOV.writefile("coverage.info", coverage)
clean_folder(".")
