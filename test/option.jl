using Dates
using Test
using CliOptions

@testset "Option()" begin
    @testset "ctor" begin
        @test_throws MethodError Option()
        @test_throws MethodError Option("-f", "--foo", "--bar")
        @test_throws ArgumentError Option("")
        @test_throws ArgumentError Option("a")
        @test_throws ArgumentError Option("-")
        @test_throws ArgumentError Option("--")
        @test Option("-a").names == ["-a"]
        @test Option("-a", "-b").names == ["-a", "-b"]

        @test Option(String, "-a").T == String
        @test Option(DateTime, "-a").T == DateTime
        @test Option(UInt32, "-a").T == UInt32
    end

    @testset "consume(::Option)" begin
        option = Option("-d", "--depth")
        let result = CliOptions.ParseResult()
            @test_throws AssertionError CliOptions.consume!(result, option, String[], 1)
        end
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, [""], 1)
            @test next_index == -1
            @test sorted_keys(result._dict) == String[]
        end
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["-a"], 1)
            @test next_index == -1
            @test sorted_keys(result._dict) == String[]
        end
        let result = CliOptions.ParseResult()
            @test_throws CliOptionError CliOptions.consume!(result, option, ["-d"], 1)
        end
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["-d", "3"], 1)
            @test next_index == 3
            @test sorted_keys(result._dict) == ["d", "depth"]
            @test result.d == "3"
            @test result.depth == "3"
        end
        let result = CliOptions.ParseResult()
            @test_throws CliOptionError CliOptions.consume!(result, option, ["a", "-d"], 2)
        end
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["a", "-d", "3"], 2)
            @test next_index == 4
            @test sorted_keys(result._dict) == ["d", "depth"]
            @test result.d == "3"
            @test result.depth == "3"
        end
    end

    @testset "consume!(::Option); type, constructible" begin
        let option = Option(Date, "-d", "--date")
            result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["-d", "2006-01-02"], 1)
            @test next_index == 3
            @test result.date == Date(2006, 1, 2)
        end
    end

    @testset "consume!(::Option); type, parsable" begin
        let option = Option(UInt8, "-n", "--number")
            result = CliOptions.ParseResult()
            @test_throws CliOptionError CliOptions.consume!(result, option, ["-n", "-1"], 1)

            result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["-n", "0"], 1)
            @test next_index == 3
            @test result.number == 0

            result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["-n", "255"], 1)
            @test next_index == 3
            @test result.number == 255

            result = CliOptions.ParseResult()
            @test_throws CliOptionError CliOptions.consume!(result, option, ["-n", "256"], 1)
        end
    end

    @testset "consume!(::Option); type, inconvertible" begin
        let option = Option(AbstractOption, "-a")
            result = CliOptions.ParseResult()
            @test_throws CliOptionError CliOptions.consume!(result, option, ["-a", "b"], 1)
        end
    end

    @testset "post_parse_action!(::Option)" begin
        # Once evaluated
        let result = CliOptions.ParseResult()
            option = Option("-n", default = nothing)
            result._counter[option] = 1
            rv = CliOptions.post_parse_action!(result, option)
            @test rv === nothing
            @test sorted_keys(result._dict) == String[]
        end

        # Not evaluated, no default value
        let result = CliOptions.ParseResult()
            option = Option("-n", default = nothing)
            @test_throws CliOptionError CliOptions.post_parse_action!(result, option)
        end

        # Not evaluated, default value was set
        let result = CliOptions.ParseResult()
            option = Option("-n"; default = "foo")
            rv = CliOptions.post_parse_action!(result, option)
            @test rv === nothing
            @test sorted_keys(result._dict) == ["n"]
            @test result.n == "foo"
        end
    end
end
