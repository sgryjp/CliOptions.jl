using Test
using CliOptions
using CliOptions: consume!

@testset "FlagOption()" begin
    @testset "ctor" begin
        @test_throws ArgumentError FlagOption("")
        @test_throws ArgumentError FlagOption("starts_from_non_hyphen")
        @test_throws ArgumentError FlagOption("-a"; negators=[""])
        @test_throws ArgumentError FlagOption("-a"; negators=["starts_from_non_hyphen"])
        option = FlagOption("-a")
        @test option.names == ["-a"]
        @test option.negators == String[]
        option = FlagOption("-a", "-b", negators=["-c", "-d"])
        @test option.names == ["-a", "-b"]
        @test option.negators == ["-c", "-d"]
    end
end
