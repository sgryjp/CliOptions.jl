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
        @test option.names == ("-a",)
        @test option.negators == String[]

        option = FlagOption("-a", "-b", negators = "-c")
        @test option.names == ("-a", "-b")
        @test option.negators == ["-c"]

        option = FlagOption("-a", "-b", negators = ["-c", "-d"])
        @test option.names == ("-a", "-b")
        @test option.negators == ["-c", "-d"]
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
        (["-i"], (2, true)),
        (["--ignore-case"], (2, true)),
        (["-I"], (2, false)),
        (["--case-sensitive"], (2, false)),
    ]
        args, expected = v
        result = CliOptions.ParseResult()
        ctx = CliOptions.ParseContext()
        option = FlagOption("-i", "--ignore-case"; negators = ["-I", "--case-sensitive"])
        next_index = CliOptions.consume!(result, option, args, 1, ctx)
        @test next_index == expected[1]
        @test result.ignore_case == expected[2]
        @test result.case_sensitive == !expected[2]
    end
end
