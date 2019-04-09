using Test
using CliOptions

@testset "NamedOption()" begin
    @testset "ctor" begin
        @test_throws ArgumentError NamedOption()
        @test_throws ArgumentError NamedOption("")
        @test_throws ArgumentError NamedOption("a")
        #@test_throws ArgumentError NamedOption("a b")  #TODO
        @test NamedOption("-a").names == ["-a"]
        @test NamedOption("-a", "-b").names == ["-a", "-b"]
    end

    @testset "consume(::NamedOption)" begin
        names = ["-d", "--depth"]
        test_cases = [
            (names, Vector{String}(), 1, AssertionError, nothing),
            (names, [""],             1,             -1, nothing),
            (names, ["-a"],           1,             -1, nothing),
            (names, ["-d"],           1, CliOptionError, nothing),
            (names, ["-d", "3"],      1,              3, Dict("d" => "3", "depth" => "3")),
            (names, ["a", "-d"],      2, CliOptionError, nothing),
            (names, ["a", "-d", "3"], 2,              4, Dict("d" => "3", "depth" => "3")),
            #(names, ["a", "-d=3"],    2,              3, Dict("d" => "3", "depth" => "3")),  #TODO
        ]
        for (names, arg, index, xret, xresult) in test_cases
            option = NamedOption(names...)
            result = CliOptions.ParsedArguments()
            if xret isa Type && xret <: Exception
                @test_throws xret CliOptions.consume!(result, option, arg, index)
            else
                @test CliOptions.consume!(result, option, arg, index) == xret
                if xresult !== nothing
                    @test sorted_keys(xresult) == sorted_keys(result._dict)
                    for pair ∈ xresult
                        @test pair ∈ result._dict
                    end
                end
            end
        end
    end
end
