using Dates
using Test
using CliOptions

@testset "Option()" begin
    @testset "ctor" begin
        @test_throws MethodError Option()
        @test_throws MethodError Option("-f", "--foo", "--bar")
        @test_throws ArgumentError Option("")
        @test_throws ArgumentError Option("a")
        @test Option("-a").names == ["-a"]
        @test Option("-a", "-b").names == ["-a", "-b"]

        @test_throws ArgumentError Option(Exception, "-a")
        @test Option(String, "-a").type == String
        @test Option(DateTime, "-a").type == DateTime  # constructible
        @test Option(UInt32, "-a").type == UInt32      # `parse`able
    end

    @testset "consume(::Option)" begin
        names = ["-d", "--depth"]
        test_cases = [
            (names, Vector{String}(), 1, AssertionError, nothing),
            (names, [""],             1,             -1, nothing),
            (names, ["-a"],           1,             -1, nothing),
            (names, ["-d"],           1, CliOptionError, nothing),
            (names, ["-d", "3"],      1,              3, Dict("d" => "3", "depth" => "3")),
            (names, ["a", "-d"],      2, CliOptionError, nothing),
            (names, ["a", "-d", "3"], 2,              4, Dict("d" => "3", "depth" => "3")),
        ]
        for (names, arg, index, xret, xresult) in test_cases
            option = Option(names...)
            result = CliOptions.ParseResult()
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
end
