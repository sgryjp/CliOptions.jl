using Test
using CliOptions

@testset "CliOptions" begin

@test_throws CliOptionError CliOptions.throw_error("hi")

include("internals.jl")
include("namedoption.jl")
include("positional.jl")
include("make_option.jl")
include("parse_args.jl")

end
