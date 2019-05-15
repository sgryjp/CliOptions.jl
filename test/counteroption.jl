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

    @testset "show(x); $(join(v[1],','))" for v in [
        (["-a"], "CounterOption(:a)"),
        (["-a", "--foo-bar"], "CounterOption(:a,:foo_bar)"),
    ]
        names, expected_repr = v
        option = CounterOption(names...)
        @test repr(option) == expected_repr
    end

    @testset "show(io, x)" begin
        let option = CounterOption("-a")
            buf = IOBuffer()
            redirect_stdout(buf) do
                show(option)
            end
            @test String(take!(buf)) == "CounterOption(:a)"
        end
    end

    @testset "consume!(); $(v[1])" for v in [
        (["-v"], (2, 1)),
        (["--verbose"], (2, 1)),
        (["-q"], (2, -1)),
        (["--quiet"], (2, -1)),
    ]
        args, expected = v
        result = CliOptions.ParseResult()
        ctx = CliOptions.ParseContext()
        option = CounterOption("-v", "--verbose"; decrementers = ["-q", "--quiet"])
        next_index = CliOptions.consume!(result, option, args, 1, ctx)
        @test next_index == expected[1]
        @test result.verbose == expected[2]
    end

    @testset "consume!(); type, $v" for v in [
        Int, Int8, Int128,
    ]
        T = v
        result = CliOptions.ParseResult()
        ctx = CliOptions.ParseContext()
        option = CounterOption(T, "-v")
        CliOptions.consume!(result, option, ["-v"], 1, ctx)
        @test typeof(result.v) == T
    end

    @testset "consume!(); upper limit" begin
        let result = CliOptions.ParseResult()
            ctx = CliOptions.ParseContext()
            option = CounterOption(Int8, "-v")
            for _ in 1:127
                CliOptions.consume!(result, option, ["-v"], 1, ctx)
            end
            @test result.v == typemax(Int8)
            @test_throws InexactError CliOptions.consume!(result, option, ["-v"], 1, ctx)
        end
    end

    @testset "consume!(); lower limit" begin
        let result = CliOptions.ParseResult()
            ctx = CliOptions.ParseContext()
            option = CounterOption(Int8, "-v", decrementers = "-q")
            for _ in 1:128
                CliOptions.consume!(result, option, ["-q"], 1, ctx)
            end
            @test result.v == typemin(Int8)
            @test_throws InexactError CliOptions.consume!(result, option, ["-q"], 1, ctx)
        end
    end
end
