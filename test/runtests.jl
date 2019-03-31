using Test
using CliOptions

@testset "CliOptions" begin

    include("internals.jl")
    include("namedoption.jl")
    include("positional.jl")
    include("parse_args.jl")

end
