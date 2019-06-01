using Test
using CliOptions

include("testutils.jl")


@testset "CounterOption()" begin
    @testset "ctor" begin
        @testset "names" begin
            @test_throws MethodError CounterOption()
            @test_throws MethodError CounterOption("-a", "--foo", "--bar")
            @test_throws ArgumentError CounterOption("")
            @test_throws ArgumentError CounterOption("a")
            @test_throws ArgumentError CounterOption("-")
            @test_throws ArgumentError CounterOption("--")
            @test_throws ArgumentError CounterOption(""; decrementers = "-a")
            @test_throws ArgumentError CounterOption("-a"; decrementers = "")
            @test_throws ArgumentError CounterOption("-a"; decrementers = [""])
            @test_throws ArgumentError CounterOption("-a"; decrementers = ["a"])
            @test_throws ArgumentError CounterOption("-a"; decrementers = ["-"])
            @test_throws ArgumentError CounterOption("-a"; decrementers = ["--"])
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

    @testset "ctor; duplicates, $(v[1]) and $(v[2])" for v in [
        (["-f", "--foo"], ["-b", "--bar"], (nothing, nothing)),
        (["-f", "-f"], ["-b", "--bar"], (ArgumentError, "-f")),
        (["-f", "--foo"], ["-f", "--bar"], (ArgumentError, "-f")),
        (["-f", "--foo"], ["-b", "--foo"], (ArgumentError, "--foo")),
        (["-f", "--foo"], ["-b", "-b"], (ArgumentError, "-b")),
    ]
        names, decrementers, expected = v
        if expected[1] isa Type
            tr = @test_throws expected[1] CounterOption(names...;
                                                        decrementers = decrementers)
            if tr isa Test.Pass
                buf = IOBuffer()
                showerror(buf, tr.value)
                msg = String(take!(buf))
                @test msg == ("ArgumentError: Duplicate names for a CounterOption found: " *
                              expected[2])
            end
        else
            @test CounterOption(names...; decrementers = decrementers) !== nothing
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
        (["-v"], (1, 1)),
        (["--verbose"], (1, 1)),
        (["-q"], (1, -1)),
        (["--quiet"], (1, -1)),
    ]
        args, expected = v
        d = Dict{String,Any}()
        ctx = CliOptions.ParseContext()
        option = CounterOption("-v", "--verbose"; decrementers = ["-q", "--quiet"])
        num_consumed = CliOptions.consume!(d, option, args, ctx)
        @test num_consumed == expected[1]
        @test d["verbose"] == expected[2]
    end

    @testset "consume!(); type, $v" for v in [
        Int, Int8, Int128,
    ]
        T = v
        d = Dict{String,Any}()
        ctx = CliOptions.ParseContext()
        option = CounterOption(T, "-v")
        CliOptions.consume!(d, option, ["-v"], ctx)
        @test typeof(d["v"]) == T
    end

    @testset "consume!(); overflow, $(v[1][1]) × $(v[2])" for v in [
        (["-v"], 127, 127),
        (["-v"], 128, CliOptionError),
        (["-q"], 128, -128),
        (["-q"], 129, CliOptionError),
    ]
        args, count, expected = v
        d = Dict{String,Any}()
        ctx = CliOptions.ParseContext()
        option = CounterOption(Int8, "-v"; decrementers = "-q")
        for _ in 1:count-1
            CliOptions.consume!(d, option, args, ctx)
        end
        if expected isa Type
            @test_throws expected CliOptions.consume!(d, option, args, ctx)
        else
            CliOptions.consume!(d, option, args, ctx)
            @test d["v"] == expected
        end
    end
end
