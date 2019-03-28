using Test
using CliOptions

@testset "NamedOption()" begin
    @test_throws CliOptionError NamedOption("")
    @test NamedOption("a").names == ("a",)
    @test NamedOption("a", "b").names == ("a", "b")
end
