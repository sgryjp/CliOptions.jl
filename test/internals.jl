using Test
using CliOptions: encode, is_option, match, NamedOption, Positional

@testset "Internal utilities" begin

    @testset "is_option()" begin
        @test CliOptions.is_option(["a"]) == false
        @test CliOptions.is_option(["-a"]) == true
        @test CliOptions.is_option(["-"]) == false
        @test CliOptions.is_option([""]) == false
    end

    @testset "encoding()" begin
        @test CliOptions.encode("f") == "f"
        @test CliOptions.encode("-f") == "f"
        @test CliOptions.encode("/f") == "f"
        @test CliOptions.encode("--f") == "f"
        @test CliOptions.encode("--foo-bar") == "foo_bar"
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

    @testset "consume(::Positional)" begin
        test_cases = [
            ("file", "",      Vector{String}(), 1, AssertionError),
            ("file", "",      [""],             1, (2, ("file" => "",))),
            ("file", "",      ["-d"],           1, (2, ("file" => "-d",))),
            ("file", "files", ["-d"],           1, (2, ("file" => "-d", "files" => "-d"))),
        ]
        for (singular, plural, arg, index, expected) in test_cases
            option = CliOptions.Positional(singular, plural)
            ctx = Dict{Any,Int}(option => 0)
            if expected isa Type && expected <: Exception
                @test_throws expected CliOptions.consume!(ctx, option, arg, index)
            else
                @test CliOptions.consume!(ctx, option, arg, index) == expected
            end
        end
    end

end