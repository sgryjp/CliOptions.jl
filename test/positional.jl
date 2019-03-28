using Test
using CliOptions

@testset "Positional()" begin
    @test_throws CliOptionError Positional("")
    @test Positional("a").names == ("a",)
    @test Positional("a", "b").names == ("a", "b")
end
