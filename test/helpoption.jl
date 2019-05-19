using Test
using CliOptions

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
            @test option.flag.names == expected
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
            @test_throws expected CliOptions.consume!(d, option, args, 1, ctx)
        else
            next_index = CliOptions.consume!(d, option, args, 1, ctx)
            @test next_index == 1 + length(args)
            @test d["help"] == expected
        end
    end
end
