using Test
using CliOptions

@testset "CounterOption()" begin
    @testset "ctor" begin
        @test_throws ArgumentError CounterOption()
        @test_throws ArgumentError CounterOption("")
        @test_throws ArgumentError CounterOption("a")
        @test_throws ArgumentError CounterOption("-")
        @test_throws ArgumentError CounterOption("--")
        @test_throws ArgumentError CounterOption("-a"; decrementers = [""])
        @test_throws ArgumentError CounterOption("-a"; decrementers = ["a"])
        @test_throws ArgumentError CounterOption("-a"; decrementers = ["-"])
        @test_throws ArgumentError CounterOption("-a"; decrementers = ["--"])
        #@test_throws ArgumentError CounterOption("-a"; decrementers = ["-a"])  #TODO
        option = CounterOption("-a")
        @test option.names == ["-a"]
        @test option.decrementers == String[]
        option = CounterOption("-a", "-b", decrementers = ["-c", "-d"])
        @test option.names == ["-a", "-b"]
        @test option.decrementers == ["-c", "-d"]
    end

    @testset "consume(::CounterOption)" begin
        option = CounterOption("-v", "--verbose")

        let result = CliOptions.ParsedArguments()
            @test_throws AssertionError CliOptions.consume!(result, option, String[], 1)
        end
        let result = CliOptions.ParsedArguments()
            # Splitting optchars are done by parse_args()
            @test_throws AssertionError CliOptions.consume!(result, option, ["-wv"], 1)
        end
        let result = CliOptions.ParsedArguments()
            next_index = CliOptions.consume!(result, option, ["v"], 1)
            @test next_index == -1
            @test sorted_keys(result._dict) == []
        end
        let result = CliOptions.ParsedArguments()
            next_index = CliOptions.consume!(result, option, ["-v"], 1)
            @test next_index == 2
            @test sorted_keys(result._dict) == ["v", "verbose"]
            @test result.v == 1
            @test result.verbose == 1
        end
        let result = CliOptions.ParsedArguments()
            next_index = CliOptions.consume!(result, option, ["--verbose"], 1)
            @test next_index == 2
            @test sorted_keys(result._dict) == ["v", "verbose"]
            @test result.v == 1
            @test result.verbose == 1
        end
    end

    @testset "consume(::CounterOption); decrementers" begin
        option = CounterOption("-v", decrementers = ["-q", "--quiet"])

        let result = CliOptions.ParsedArguments()
            @test_throws AssertionError CliOptions.consume!(result, option, String[], 1)
        end
        let result = CliOptions.ParsedArguments()
            # Splitting optchars are done by parse_args()
            @test_throws AssertionError CliOptions.consume!(result, option, ["-wv"], 1)
        end
        let result = CliOptions.ParsedArguments()
            next_index = CliOptions.consume!(result, option, ["v"], 1)
            @test next_index == -1
            @test sorted_keys(result._dict) == []
        end
        let result = CliOptions.ParsedArguments()
            next_index = CliOptions.consume!(result, option, ["-v"], 1)
            @test next_index == 2
            @test sorted_keys(result._dict) == ["v"]
            @test result.v == 1
        end
        let result = CliOptions.ParsedArguments()
            next_index = CliOptions.consume!(result, option, ["-q"], 1)
            @test next_index == 2
            @test sorted_keys(result._dict) == ["v"]
            @test result.v == -1
        end
        let result = CliOptions.ParsedArguments()
            next_index = CliOptions.consume!(result, option, ["--quiet"], 1)
            @test next_index == 2
            @test sorted_keys(result._dict) == ["v"]
            @test result.v == -1
        end
    end
end
