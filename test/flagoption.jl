using Test
using CliOptions

include("testutils.jl")


@testset "FlagOption()" begin
    @testset "ctor" begin
        @test_throws MethodError FlagOption()
        @test_throws MethodError FlagOption("-f", "--foo", "--bar")
        @test_throws ArgumentError FlagOption("")
        @test_throws ArgumentError FlagOption("a")
        @test_throws ArgumentError FlagOption("-")
        @test_throws ArgumentError FlagOption("--")
        @test_throws ArgumentError FlagOption(""; negators = "-a")
        @test_throws ArgumentError FlagOption("-a"; negators = "")
        @test_throws ArgumentError FlagOption("-a"; negators = [""])
        @test_throws ArgumentError FlagOption("-a"; negators = ["a"])
        @test_throws ArgumentError FlagOption("-a"; negators = ["-"])
        @test_throws ArgumentError FlagOption("-a"; negators = ["--"])

        option = FlagOption("-a")
        @test option.names == ("-a",)
        @test option.negators == String[]

        option = FlagOption("-a", "-b", negators = "-c")
        @test option.names == ("-a", "-b")
        @test option.negators == ["-c"]

        option = FlagOption("-a", "-b", negators = ["-c", "-d"])
        @test option.names == ("-a", "-b")
        @test option.negators == ["-c", "-d"]
    end

    @testset "ctor; duplicates, $(v[1]) and $(v[2])" for v in [
        (["-f", "--foo"], ["-b", "--bar"], (nothing, nothing)),
        (["-f", "-f"], ["-b", "--bar"], (ArgumentError, "-f")),
        (["-f", "--foo"], ["-f", "--bar"], (ArgumentError, "-f")),
        (["-f", "--foo"], ["-b", "--foo"], (ArgumentError, "--foo")),
        (["-f", "--foo"], ["-b", "-b"], (ArgumentError, "-b")),
    ]
        names, negators, expected = v
        if expected[1] isa Type
            tr = @test_throws expected[1] FlagOption(names...; negators = negators)
            if tr isa Test.Pass
                buf = IOBuffer()
                showerror(buf, tr.value)
                msg = String(take!(buf))
                @test msg == ("ArgumentError: Duplicate names for a FlagOption found: " *
                              expected[2])
            end
        else
            @test FlagOption(names...; negators = negators) !== nothing
        end
    end

    @testset "show(x); $(join(v[1],','))" for v in [
        (["-a"], "FlagOption(:a)"),
        (["-a", "--foo-bar"], "FlagOption(:a,:foo_bar)"),
    ]
        names, expected_repr = v
        option = FlagOption(names...)
        @test repr(option) == expected_repr
    end

    @testset "show(io, x)" begin
        let option = FlagOption("-a")
            buf = IOBuffer()
            redirect_stdout(buf) do
                show(option)
            end
            @test String(take!(buf)) == "FlagOption(:a)"
        end
    end

    @testset "consume!(); $(v[1])" for v in [
        (["-i"], (1, true)),
        (["--ignore-case"], (1, true)),
        (["-I"], (1, false)),
        (["--case-sensitive"], (1, false)),
    ]
        args, expected = v
        d = Dict{String,Any}()
        ctx = CliOptions.ParseContext()
        option = FlagOption("-i", "--ignore-case"; negators = ["-I", "--case-sensitive"])
        num_consumed = CliOptions.consume!(d, option, args, ctx)
        @test num_consumed == expected[1]
        @test d["ignore_case"] == expected[2]
        @test d["case_sensitive"] == !expected[2]
    end
end
