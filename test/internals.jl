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
        test_cases = [
            (["-d", "--depth"], Vector{String}(), 1, AssertionError),
            (["-d", "--depth"], [""],             1, (-1, nothing)),
            (["-d", "--depth"], ["-a"],           1, (-1, nothing)),
            (["-d", "--depth"], ["-d"],           1, CliOptionError),
            (["-d", "--depth"], ["-d", "3"],      1, (3, ("d" => "3", "depth" => "3"))),
            (["-d", "--depth"], ["a", "-d"],      2, CliOptionError),
            (["-d", "--depth"], ["a", "-d", "3"], 2, (4, ("d" => "3", "depth" => "3"))),
        ]
        for (names, arg, index, expected) in test_cases
            option = NamedOption(names)
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
            ("",     "",      Vector{String}(), 1, AssertionError),
            ("file", "",      Vector{String}(), 1, AssertionError),
            ("file", "",      [""],             1, (2, ("file" => "",))),
            ("file", "",      ["-d"],           1, (2, ("file" => "-d",))),
            ("",     "files", ["-d"],           1, AssertionError),
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
