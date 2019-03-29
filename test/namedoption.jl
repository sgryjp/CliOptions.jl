using Test
using CliOptions

@testset "NamedOption()" begin
    @test_throws CliOptionError NamedOption("")
    @test NamedOption("a").names == ["a"]
    @test NamedOption("a", "b").names == ["a", "b"]
end

@testset "consume(::NamedOption)" begin
names = ["-d", "--depth"]
test_cases = [
    (names, Vector{String}(), 1, AssertionError),
    (names, [""],             1, (-1, nothing)),
    (names, ["-a"],           1, (-1, nothing)),
    (names, ["-d"],           1, CliOptionError),
    (names, ["-d", "3"],      1, (3, ("d" => "3", "depth" => "3"))),
    (names, ["a", "-d"],      2, CliOptionError),
    (names, ["a", "-d", "3"], 2, (4, ("d" => "3", "depth" => "3"))),
]
for (names, arg, index, expected) in test_cases
    option = NamedOption(names...)
    ctx = Dict{Any,Int}(option => 0)
    if expected isa Type && expected <: Exception
        @test_throws expected CliOptions.consume!(ctx, option, arg, index)
    else
        @test CliOptions.consume!(ctx, option, arg, index) == expected
    end
end
end
