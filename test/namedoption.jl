using Test
using CliOptions

@testset "NamedOption()" begin  #TODO: 空白を含む名前を拒否
    @testset "ctor" begin
        @test_throws ArgumentError NamedOption()
        @test_throws ArgumentError NamedOption("")
        @test_throws ArgumentError NamedOption("a")
        @test NamedOption("-a").names == ["-a"]
        @test NamedOption("-a", "-b").names == ["-a", "-b"]
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
            #(names, ["a", "-d=3"],    2, (3, ("d" => "3", "depth" => "3"))),  #TODO
        ]
        for (names, arg, index, expected) in test_cases
            option = NamedOption(names...)
            result = CliOptions.ParsedArguments()
            if expected isa Type && expected <: Exception
                @test_throws expected CliOptions.consume!(result, option, arg, index)
            else
                @test CliOptions.consume!(result, option, arg, index) == expected
            end
        end
    end
end
