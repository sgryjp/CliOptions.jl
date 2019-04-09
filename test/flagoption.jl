using Test
using CliOptions

@testset "FlagOption()" begin
    @testset "ctor" begin
        @test_throws ArgumentError FlagOption()
        @test_throws ArgumentError FlagOption("")
        @test_throws ArgumentError FlagOption("a")
        @test_throws ArgumentError FlagOption("-")
        @test_throws ArgumentError FlagOption("--")
        @test_throws ArgumentError FlagOption("-a"; negators = [""])
        @test_throws ArgumentError FlagOption("-a"; negators = ["a"])
        @test_throws ArgumentError FlagOption("-a"; negators = ["-"])
        @test_throws ArgumentError FlagOption("-a"; negators = ["--"])
        #@test_throws ArgumentError FlagOption("-a"; negators = ["-a"])  #TODO
        option = FlagOption("-a")
        @test option.names == ["-a"]
        @test option.negators == String[]
        option = FlagOption("-a", "-b", negators = ["-c", "-d"])
        @test option.names == ["-a", "-b"]
        @test option.negators == ["-c", "-d"]
    end

    @testset "consume(::FlagOption)" begin
        option = FlagOption("-i", "--ignore-case")

        let result = CliOptions.ParsedArguments()
            @test_throws AssertionError CliOptions.consume!(result, option, String[], 1)
        end
        let result = CliOptions.ParsedArguments()
            # Splitting optchars are done by parse_args()
            @test_throws AssertionError CliOptions.consume!(result, option, ["-ab"], 1)
        end
        let result = CliOptions.ParsedArguments()
            next_index = CliOptions.consume!(result, option, ["foo"], 1)
            @test next_index == -1
            @test isempty(result._dict)
        end
        let result = CliOptions.ParsedArguments()
            next_index = CliOptions.consume!(result, option, ["-i"], 1)
            @test next_index == 2
            @test result.i == true
            @test result.ignore_case == true
        end
        let result = CliOptions.ParsedArguments()
            next_index = CliOptions.consume!(result, option, ["--ignore-case"], 1)
            @test next_index == 2
            @test result.i == true
            @test result.ignore_case == true
        end
    end

    @testset "consume(::FlagOption); negators" begin
        option = FlagOption("-i", negators = ["-c", "--case-sensitive"])

        let result = CliOptions.ParsedArguments()
            @test_throws AssertionError CliOptions.consume!(result, option, String[], 1)
        end
        let result = CliOptions.ParsedArguments()
            # Splitting optchars are done by parse_args()
            @test_throws AssertionError CliOptions.consume!(result, option, ["-ab"], 1)
        end
        let result = CliOptions.ParsedArguments()
            next_index = CliOptions.consume!(result, option, ["foo"], 1)
            @test next_index == -1
            @test isempty(result._dict)
        end
        let result = CliOptions.ParsedArguments()
            next_index = CliOptions.consume!(result, option, ["-i"], 1)
            @test next_index == 2
            @test result.i == true
            @test result.c == false
            @test result.case_sensitive == false
        end
        let result = CliOptions.ParsedArguments()
            next_index = CliOptions.consume!(result, option, ["-c"], 1)
            @test next_index == 2
            @test result.i == false
            @test result.c == true
            @test result.case_sensitive == true
        end
        let result = CliOptions.ParsedArguments()
            next_index = CliOptions.consume!(result, option, ["--case-sensitive"], 1)
            @test next_index == 2
            @test result.i == false
            @test result.c == true
            @test result.case_sensitive == true
        end
    end
end
