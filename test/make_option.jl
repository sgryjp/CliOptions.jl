using Test
using CliOptions

@testset "make_option()" begin
    option = make_option("filename")
    @test option isa CliOptions.Positional
    @test option.names == ("filename",)

    option = make_option("-i", "--ignore-case")
    @test option isa CliOptions.NamedOption
    @test Set(option.names) == Set(["-i", "--ignore-case"])
end
