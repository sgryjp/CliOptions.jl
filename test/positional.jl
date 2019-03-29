using Test
using CliOptions

@testset "Positional()" begin
    @test_throws CliOptionError Positional("")
    @test Positional("a").names == ("a",)
    @test Positional("a", "b").names == ("a", "b")
end

@testset "consume(::Positional)" begin
test_cases = [
    ("file", "",      Vector{String}(), 1, AssertionError),
    ("file", "",      [""],             1, (2, ("file" => "",))),
    ("file", "",      ["-d"],           1, (2, ("file" => "-d",))),
    ("file", "files", ["-d"],           1, (2, ("file" => "-d", "files" => "-d"))),
]
for (singular, plural, arg, index, expected) in test_cases
    option = Positional(singular, plural)
    ctx = Dict{Any,Int}(option => 0)
    if expected isa Type && expected <: Exception
        @test_throws expected CliOptions.consume!(ctx, option, arg, index)
    else
        @test CliOptions.consume!(ctx, option, arg, index) == expected
    end
end
end
