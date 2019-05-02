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

    @testset "show(::Option); $(join(v[1],','))" for v in [
        (["-a"], "Option(:a)"),
        (["-a", "--foo-bar"], "Option(:a,:foo_bar)"),
    ]
        names, expected_repr = v
        result = CliOptions.ParseResult()
        option = Option(names...)
        @test repr(option) == expected_repr
    end

    @testset "consume!(::Option)" begin
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
        let option = Option(CliOptions.AbstractOption, "-a")
            result = CliOptions.ParseResult()
            @test_throws CliOptionError CliOptions.consume!(result, option, ["-a", "b"], 1)
        end
    end

    @testset "consume!(::Option); validator, Vector{String}" begin
        option = Option("-a", validator = ["foo", "bar"])
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["-a", "foo"], 1)
            @test next_index == 3
            @test result.a == "foo"
        end
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["-a", "bar"], 1)
            @test next_index == 3
            @test result.a == "bar"
        end
        let result = CliOptions.ParseResult()
            try
                CliOptions.consume!(result, option, ["-a", "baz"], 1)
            catch ex
                @test ex isa CliOptionError
                @test occursin("baz", ex.msg)
                @test occursin("must be one of", ex.msg)
                @test occursin("foo", ex.msg)
                @test occursin("bar", ex.msg)
            end
        end
    end

    @testset "consume!(::Option); validator, Tuple{Vararg{Int}}" begin
        option = Option(Int, "-a", validator = (7, 13))
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["-a", "7"], 1)
            @test next_index == 3
            @test result.a isa Int
            @test result.a == 7
        end
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["-a", "13"], 1)
            @test next_index == 3
            @test result.a isa Int
            @test result.a == 13
        end
        let result = CliOptions.ParseResult()
            try
                CliOptions.consume!(result, option, ["-a", "9"], 1)
            catch ex
                @test ex isa CliOptionError
                @test occursin("9", ex.msg)
                @test occursin("must be one of", ex.msg)
                @test occursin("7", ex.msg)
                @test occursin("13", ex.msg)
            end
        end
    end

    @testset "consume!(::Option); validator, Regex" begin
        option = Option("-a", validator = Regex("qu+x"))
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["-a", "qux"], 1)
            @test next_index == 3
            @test result.a == "qux"
        end
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["-a", "quux"], 1)
            @test next_index == 3
            @test result.a == "quux"
        end
        let result = CliOptions.ParseResult()
            try
                CliOptions.consume!(result, option, ["-a", "foo"], 1)
            catch ex
                @test ex isa CliOptionError
                @test occursin("foo", ex.msg)
                @test occursin("must match for", ex.msg)
                @test occursin("qu+x", ex.msg)
            end
        end
    end

    @testset "consume!(::Option); validator, String -> Bool" begin
        option = Option("-a", validator = s -> s == "foo")
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["-a", "foo"], 1)
            @test next_index == 3
            @test result.a == "foo"
        end

        # String
        let result = CliOptions.ParseResult()
            try
                CliOptions.consume!(result, option, ["-a", "bar"], 1)
            catch ex
                @test ex isa CliOptionError
                @test occursin("bar", ex.msg)
                @test occursin("validation failed", ex.msg)
            end
        end

        # non-String
        option = Option(Int8, "-a", validator = n -> iseven(n))
        let result = CliOptions.ParseResult()
            try
                CliOptions.consume!(result, option, ["-a", "7"], 1)
            catch ex
                @test ex isa CliOptionError
                @test occursin("Int8", ex.msg)
                @test occursin("7", ex.msg)
                @test occursin("validation failed", ex.msg)
            end
        end
    end

    @testset "consume!(::Option); validator, String -> String" begin
        option = Option("-a", validator = s -> s == "foo" ? "" : "It's not foo")
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["-a", "foo"], 1)
            @test next_index == 3
            @test result.a == "foo"
        end

        # String
        let result = CliOptions.ParseResult()
            try
                CliOptions.consume!(result, option, ["-a", "bar"], 1)
            catch ex
                @test ex isa CliOptionError
                @test occursin("bar", ex.msg)
                @test occursin("It's not foo", ex.msg)
            end
        end

        # non-String
        option = Option(Int8, "-a", validator = n -> iseven(n) ? "" : "must be even")
        let result = CliOptions.ParseResult()
            try
                CliOptions.consume!(result, option, ["-a", "7"], 1)
            catch ex
                @test ex isa CliOptionError
                @test occursin("Int8", ex.msg)
                @test occursin("7", ex.msg)
                @test occursin("must be even", ex.msg)
            end
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
