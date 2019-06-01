using Documenter

push!(LOAD_PATH, joinpath("..", "src"))
using CliOptions

makedocs(sitename = "CliOptions.jl",
         pages = Any[
             "Home" => "index.md",
             "reference.md",
         ])

if "--deploy" in ARGS
    deploydocs(repo = "github.com/sgryjp/CliOptions.git")
end
