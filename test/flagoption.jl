using Test
using CliOptions

@testset "FlagOption()" begin
    @testset "ctor" begin
        @test_throws MethodError FlagOption()
        @test_throws MethodError FlagOption("-f", "--foo", "--bar")
        @test_throws ArgumentError FlagOption("")
        @test_throws ArgumentError FlagOption("a")
        @test_throws ArgumentError FlagOption("-")
        @test_throws ArgumentError FlagOption("--")
        @test_throws ArgumentError FlagOption("-a"; negators = "")
        @test_throws ArgumentError FlagOption("-a"; negators = [""])
        @test_throws ArgumentError FlagOption("-a"; negators = ["a"])
        @test_throws ArgumentError FlagOption("-a"; negators = ["-"])
        @test_throws ArgumentError FlagOption("-a"; negators = ["--"])
        #@test_throws ArgumentError FlagOption("-a"; negators = ["-a"])  #TODO

        option = FlagOption("-a")
        @test option.names == ["-a"]
        @test option.negators == String[]

        option = FlagOption("-a", "-b", negators = "-c")
        @test option.names == ["-a", "-b"]
        @test option.negators == ["-c"]

        option = FlagOption("-a", "-b", negators = ["-c", "-d"])
        @test option.names == ["-a", "-b"]
        @test option.negators == ["-c", "-d"]
    end

    @testset "show(::FlagOption); $(join(v[1],','))" for v in [
        (["-a"], "FlagOption(:a)"),
        (["-a", "--foo-bar"], "FlagOption(:a,:foo_bar)"),
    ]
        names, expected_repr = v
        result = CliOptions.ParseResult()
        option = FlagOption(names...)
        @test repr(option) == expected_repr
    end

    @testset "consume(::FlagOption)" begin
        option = FlagOption("-i", "--ignore-case")

        let result = CliOptions.ParseResult()
            @test_throws AssertionError CliOptions.consume!(result, option, String[], 1)
        end
        let result = CliOptions.ParseResult()
            # Splitting optchars are done by parse_args()
            @test_throws AssertionError CliOptions.consume!(result, option, ["-ab"], 1)
        end
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["foo"], 1)
            @test next_index == -1
            @test isempty(result._dict)
        end
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["-i"], 1)
            @test next_index == 2
            @test sorted_keys(result._dict) == ["i", "ignore_case"]
            @test result.i == true
            @test result.ignore_case == true
        end
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["--ignore-case"], 1)
            @test next_index == 2
            @test sorted_keys(result._dict) == ["i", "ignore_case"]
            @test result.i == true
            @test result.ignore_case == true
        end
    end

    @testset "consume(::FlagOption); negators" begin
        option = FlagOption("-i", negators = ["-c", "--case-sensitive"])

        let result = CliOptions.ParseResult()
            @test_throws AssertionError CliOptions.consume!(result, option, String[], 1)
        end
        let result = CliOptions.ParseResult()
            # Splitting optchars are done by parse_args()
            @test_throws AssertionError CliOptions.consume!(result, option, ["-ab"], 1)
        end
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["foo"], 1)
            @test next_index == -1
            @test isempty(result._dict)
        end
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["-i"], 1)
            @test next_index == 2
            @test sorted_keys(result._dict) == ["c", "case_sensitive", "i"]
            @test result.i == true
            @test result.c == false
            @test result.case_sensitive == false
        end
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["-c"], 1)
            @test next_index == 2
            @test sorted_keys(result._dict) == ["c", "case_sensitive", "i"]
            @test result.i == false
            @test result.c == true
            @test result.case_sensitive == true
        end
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["--case-sensitive"], 1)
            @test next_index == 2
            @test sorted_keys(result._dict) == ["c", "case_sensitive", "i"]
            @test result.i == false
            @test result.c == true
            @test result.case_sensitive == true
        end
    end
end
