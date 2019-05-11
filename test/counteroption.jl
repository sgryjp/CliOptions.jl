using Test
using CliOptions

@testset "CounterOption()" begin
    @testset "ctor" begin
        @testset "names" begin
            @test_throws MethodError CounterOption()
            @test_throws MethodError CounterOption("-a", "--foo", "--bar")
            @test_throws ArgumentError CounterOption("")
            @test_throws ArgumentError CounterOption("a")
            @test_throws ArgumentError CounterOption("-")
            @test_throws ArgumentError CounterOption("--")
            @test_throws ArgumentError CounterOption("-a"; decrementers = "")
            @test_throws ArgumentError CounterOption("-a"; decrementers = [""])
            @test_throws ArgumentError CounterOption("-a"; decrementers = ["a"])
            @test_throws ArgumentError CounterOption("-a"; decrementers = ["-"])
            @test_throws ArgumentError CounterOption("-a"; decrementers = ["--"])
            #@test_throws ArgumentError CounterOption("-a"; decrementers = ["-a"])  #TODO
            @test_throws ArgumentError CounterOption(UInt8, "-a")

            option = CounterOption("-a")
            @test option.names == ("-a",)
            @test option.decrementers == String[]
        end

        @testset "decrementers" begin
            option = CounterOption("-a", "-b", decrementers = "-c")
            @test option.names == ("-a", "-b")
            @test option.decrementers == ["-c"]

            option = CounterOption("-a", "-b", decrementers = ["-c", "-d"])
            @test option.names == ("-a", "-b")
            @test option.decrementers == ["-c", "-d"]
        end

        @testset "default" begin
            let result = CliOptions.ParseResult()
                @test_throws InexactError CounterOption(Int8, "-v", default = -129)
                CounterOption(Int8, "-v", default = -128)
                CounterOption(Int8, "-v", default = 127)
                @test_throws InexactError CounterOption(Int8, "-v", default = 128)
            end
        end
    end

    @testset "show(::CounterOption); $(join(v[1],','))" for v in [
        (["-a"], "CounterOption(:a)"),
        (["-a", "--foo-bar"], "CounterOption(:a,:foo_bar)"),
    ]
        names, expected_repr = v
        option = CounterOption(names...)
        @test repr(option) == expected_repr
    end

    @testset "consume(::CounterOption)" begin
        option = CounterOption("-v", "--verbose")

        let result = CliOptions.ParseResult()
            @test_throws AssertionError CliOptions.consume!(result, [option], option, String[], 1)
        end
        let result = CliOptions.ParseResult()
            # Splitting optchars are done by parse_args()
            @test_throws AssertionError CliOptions.consume!(result, [option], option, ["-wv"], 1)
        end
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, [option], option, ["v"], 1)
            @test next_index == 0
            @test sorted_keys(result._dict) == []
        end
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, [option], option, ["-v"], 1)
            @test next_index == 2
            @test sorted_keys(result._dict) == ["v", "verbose"]
            @test result.v == 1
            @test result.verbose == 1
        end
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, [option], option, ["--verbose"], 1)
            @test next_index == 2
            @test sorted_keys(result._dict) == ["v", "verbose"]
            @test result.v == 1
            @test result.verbose == 1
        end
    end

    @testset "consume(::CounterOption); decrementers" begin
        option = CounterOption("-v", decrementers = ["-q", "--quiet"])

        let result = CliOptions.ParseResult()
            @test_throws AssertionError CliOptions.consume!(result, [option], option, String[], 1)
        end
        let result = CliOptions.ParseResult()
            # Splitting optchars are done by parse_args()
            @test_throws AssertionError CliOptions.consume!(result, [option], option, ["-wv"], 1)
        end
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, [option], option, ["v"], 1)
            @test next_index == 0
            @test sorted_keys(result._dict) == []
        end
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, [option], option, ["-v"], 1)
            @test next_index == 2
            @test sorted_keys(result._dict) == ["v"]
            @test result.v == 1
        end
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, [option], option, ["-q"], 1)
            @test next_index == 2
            @test sorted_keys(result._dict) == ["v"]
            @test result.v == -1
        end
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, [option], option, ["--quiet"], 1)
            @test next_index == 2
            @test sorted_keys(result._dict) == ["v"]
            @test result.v == -1
        end
    end

    @testset "consume(::CounterOption); type" begin
        let result = CliOptions.ParseResult()
            option = CounterOption("-v")
            CliOptions.consume!(result, [option], option, ["-v"], 1)
            @test typeof(result.v) == Int
        end
        let result = CliOptions.ParseResult()
            option = CounterOption(Int8, "-v")
            CliOptions.consume!(result, [option], option, ["-v"], 1)
            @test typeof(result.v) == Int8
        end
        let result = CliOptions.ParseResult()
            option = CounterOption(Int128, "-v")
            CliOptions.consume!(result, [option], option, ["-v"], 1)
            @test typeof(result.v) == Int128
        end
        let result = CliOptions.ParseResult()
            option = CounterOption(Int8, "-v")
            for _ in 1:127
                CliOptions.consume!(result, [option], option, ["-v"], 1)
            end
            @test result.v == 127
            @test_throws InexactError CliOptions.consume!(result, [option], option, ["-v"], 1)
        end
        let result = CliOptions.ParseResult()
            option = CounterOption(Int8, "-v"; decrementers = ["-q"])
            for _ in 1:128
                CliOptions.consume!(result, [option], option, ["-q"], 1)
            end
            @test result.v == -128
            @test_throws InexactError CliOptions.consume!(result, [option], option, ["-q"], 1)
        end
    end
end
