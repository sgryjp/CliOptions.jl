using Test
using CliOptions

@testset "make_option()" begin
    option = make_option("filename")
    @test option isa CliOptions.Positional
    @test option.singular_name == "filename"
    @test option.plural_name == ""

    option = make_option("-i", "--ignore-case")
    @test option isa CliOptions.NamedOption
    @test Set(option.names) == Set(["-i", "--ignore-case"])
end
