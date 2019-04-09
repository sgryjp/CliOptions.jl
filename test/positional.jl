using Test
using CliOptions
using CliOptions: consume!

@testset "Positional()" begin
    @testset "ctor" begin
        @test_throws ArgumentError Positional("")
        @test_throws ArgumentError Positional("-a")
        @test_throws ArgumentError Positional("a", "-b")

        option = Positional("a")
        @test option.names == ["a"]
        @test option.multiple == false
        @test option.default === nothing

        option = Positional("a", "b")
        @test option.names == ["a", "b"]
        @test option.multiple == false
        @test option.default === nothing

        option = Positional("a", multiple = true)
        @test option.names == ["a"]
        @test option.multiple == true
        @test option.default === nothing

        option = Positional("a", default = 42)
        @test option.names == ["a"]
        @test option.multiple == false
        @test option.default == 42
    end

    @testset "consume(::Positional)" begin
        @testset "empty args" begin
            let result = CliOptions.ParsedArguments()
                option = Positional("file")
                @test_throws AssertionError consume!(result, option, Vector{String}(), 1)
            end
        end

        @testset "single" begin
            let result = CliOptions.ParsedArguments()
                option = Positional("file")
                next_index, pairs = consume!(result, option, [""], 1)
                @test next_index == 2
                @test pairs == ("file" => "",)
            end
            let result = CliOptions.ParsedArguments()
                option = Positional("file")
                next_index, pairs = consume!(result, option, ["-d"], 1)
                @test next_index == 2
                @test pairs == ("file" => "-d",)
            end
            let result = CliOptions.ParsedArguments()
                option = Positional("file", "files")
                next_index, pairs = consume!(result, option, ["-d"], 1)
                @test next_index == 2
                @test pairs == ("file" => "-d", "files" => "-d")
            end
        end

        @testset "multiple" begin
            let result = CliOptions.ParsedArguments()
                option = Positional("file", multiple = true)
                next_index, pairs = consume!(result, option, [""], 1)
                @test next_index == 2
                @test pairs == ("file" => [""],)
            end
            let result = CliOptions.ParsedArguments()
                option = Positional("file", "files", multiple = true)
                next_index, pairs = consume!(result, option, ["a"], 1)
                @test next_index == 2
                @test pairs == ("file" => ["a"], "files" => ["a"])
            end
            let result = CliOptions.ParsedArguments()
                option = Positional("file", multiple = true)
                next_index, pairs = consume!(result, option, ["a", "b"], 1)
                @test next_index == 3
                @test pairs == ("file" => ["a", "b"],)
            end
        end
    end
end
