using Test
using CliOptions

sorted_keys = sort ∘ collect ∘ keys

@testset "CliOptions" begin

    include("internals.jl")
    include("namedoption.jl")
    include("flagoption.jl")
    include("counteroption.jl")
    include("positional.jl")
    include("parse_args.jl")
    include("usage.jl")

end
