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

    @testset "show(); $(v[1])" for v in [
        ([], "HelpOption(:h,:help)"),
        (["-a"], "HelpOption(:a)"),
        (["-a", "--foo-bar"], "HelpOption(:a,:foo_bar)"),
    ]
        names, expected_repr = v
        if length(names) == 0
            option = HelpOption()
        else
            option = HelpOption(names...)
        end
        @test repr(option) == expected_repr
    end

    @testset "consume(); $(v[1])" for v in [
        ([], AssertionError),
        (["-ab"], AssertionError),
        (["-h"], true),
        (["--help"], true),
    ]
        args, expected = v
        option = HelpOption()
        result = CliOptions.ParseResult()
        if expected isa Type
            @test_throws expected CliOptions.consume!(result, [option], option, args, 1)
        else
            next_index = CliOptions.consume!(result, [option], option, args, 1)
            @test next_index == 1 + length(args)
            @test result.help == expected
        end
    end
end
