using Test
using CliOptions

include("testutils.jl")


@testset "HelpOption()" begin
    @testset "ctor; $(v[1])" for v in [
        ([""], ArgumentError),
        ([""], ArgumentError),
        (["a"], ArgumentError),
        (["-"], ArgumentError),
        (["-a"], ("-a",)),
        (["--"], ArgumentError),
        (["--foo"], ("--foo",)),
    ]
        names, expected = v
        if expected isa Type
            @test_throws expected HelpOption(names...)
        else
            option = HelpOption(names...)
            @test option.names == expected
        end
    end

    @testset "ctor; duplicates, $(v[1])" for v in [
        (["-f", "--foo"], (nothing, nothing)),
        (["-f", "-f"], (ArgumentError, "-f")),
    ]
        names, expected = v
        if expected[1] isa Type
            tr = @test_throws expected[1] HelpOption(names...)
            if tr isa Test.Pass
                msg = stringify(tr.value)
                @test msg == ("ArgumentError: Duplicate names for a HelpOption found: " *
                              expected[2])
            end
        else
            @test HelpOption(names...) !== nothing
        end
    end

    @testset "show(x); $(v[1])" for v in [
        ([], "HelpOption(:h,:help)"),
        (["-a"], "HelpOption(:a)"),
        (["-a", "--foo-bar"], "HelpOption(:a,:foo_bar)"),
    ]
        names, expected_repr = v
        option = HelpOption(names...)
        @test repr(option) == expected_repr
    end

    @testset "show(io, x)" begin
        let option = HelpOption()
            buf = IOBuffer()
            redirect_stdout(buf) do
                show(option)
            end
            @test String(take!(buf)) == "HelpOption(:h,:help)"
        end
    end

    @testset "consume!(); $(v[1])" for v in [
        ([], AssertionError),
        (["-ab"], AssertionError),
        (["-h"], true),
        (["--help"], true),
    ]
        args, expected = v
        option = HelpOption()
        d = Dict{String,Any}()
        ctx = CliOptions.ParseContext()
        if expected isa Type
            @test_throws expected CliOptions.consume!(d, option, args, ctx)
        else
            num_consumed = CliOptions.consume!(d, option, args, ctx)
            @test num_consumed == 1
            @test d["help"] == expected
        end
    end
end
