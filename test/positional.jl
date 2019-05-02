using Dates
using Test
using CliOptions
using CliOptions: consume!

@testset "Positional()" begin
    @testset "ctor" begin
        @test_throws ArgumentError Positional("")
        @test_throws ArgumentError Positional("-a")
        @test_throws ArgumentError Positional("a", "-b")

        option = Positional("a")
        @test option.names == ["a"]
        @test option.multiple == false
        @test option.default === nothing

        option = Positional("a", "b")
        @test option.names == ["a", "b"]
        @test option.multiple == false
        @test option.default === nothing

        option = Positional("a", multiple = true)
        @test option.names == ["a"]
        @test option.multiple == true
        @test option.default === nothing

        option = Positional("a", default = 42)
        @test option.names == ["a"]
        @test option.multiple == false
        @test option.default == 42
    end

    @testset "show(::Positional); $(join(v[1],','))" for v in [
        (["file"], "Positional(:file)"),
        (["file", "files"], "Positional(:file,:files)"),
    ]
        names, expected_repr = v
        result = CliOptions.ParseResult()
        option = Positional(names...)
        @test repr(option) == expected_repr
    end

    @testset "consume(::Positional); empty args" begin
        let result = CliOptions.ParseResult()
            option = Positional("file")
            @test_throws AssertionError consume!(result, option, Vector{String}(), 1)
        end
    end

    @testset "consume(::Positional); single" begin
        let result = CliOptions.ParseResult()
            option = Positional("file")
            next_index = consume!(result, option, [""], 1)
            @test next_index == 2
            @test sorted_keys(result._dict) == ["file"]
            @test result.file == ""
        end
        let result = CliOptions.ParseResult()
            option = Positional("file")
            next_index = consume!(result, option, ["-d"], 1)
            @test next_index == 2
            @test sorted_keys(result._dict) == ["file"]
            @test result.file == "-d"
        end
        let result = CliOptions.ParseResult()
            option = Positional("file", "files")
            next_index = consume!(result, option, ["-d"], 1)
            @test next_index == 2
            @test sorted_keys(result._dict) == ["file", "files"]
            @test result.file == "-d"
            @test result.files == "-d"
        end
    end

    @testset "consume(::Positional); multiple; $(join(v[1],','))" for v in [
        ([""], 2, [""]),
        (["a"], 2, ["a"]),
        (["a", "b"], 3, ["a", "b"])
    ]
        args, expected_next_index, expected_values = v
        result = CliOptions.ParseResult()
        option = Positional("file", "files", multiple = true)
        next_index = consume!(result, option, args, 1)
        @test sorted_keys(result._dict) == ["file", "files"]
        @test next_index == expected_next_index
        @test result.file == expected_values
        @test result.files == expected_values
    end

    @testset "consume(::Positional); type" begin
        let result = CliOptions.ParseResult()
            option = Positional(Int32, "number", "numbers", multiple = true)
            next_index = consume!(result, option, ["2", "-3"], 1)
            @test next_index == 3
            @test sorted_keys(result._dict) == ["number", "numbers"]
            @test result.numbers == [2, -3]
        end
        let result = CliOptions.ParseResult()
            option = Positional(Date, "date", "dates", multiple = false)
            next_index = consume!(result, option, ["2006-01-02"], 1)
            @test next_index == 2
            @test sorted_keys(result._dict) == ["date", "dates"]
            @test result.date == Date(2006, 1, 2)
        end
        let result = CliOptions.ParseResult()
            option = Positional(Date, "date", multiple = false)
            @test_throws CliOptionError consume!(result, option, ["not_a_date"], 1)
        end
    end

    @testset "consume(::Positional); validator, Vector{String}" begin
        option = Positional("name", "names", validator = ["foo", "bar"], multiple = true)
        let result = CliOptions.ParseResult()
            next_index = consume!(result, option, ["foo", "bar"], 1)
            @test next_index == 3
            @test result.names == ["foo", "bar"]
        end

        option = Positional("name", validator = ["foo", "bar"])
        let result = CliOptions.ParseResult()
            next_index = consume!(result, option, ["foo"], 1)
            @test next_index == 2
            @test result.name == "foo"
        end
        let result = CliOptions.ParseResult()
            next_index = consume!(result, option, ["bar"], 1)
            @test next_index == 2
            @test result.name == "bar"
        end
        let result = CliOptions.ParseResult()
            try
                CliOptions.consume!(result, option, ["baz"], 1)
            catch ex
                @test ex isa CliOptionError
                @test occursin("baz", ex.msg)
                @test occursin("must be one of", ex.msg)
                @test occursin("foo", ex.msg)
                @test occursin("bar", ex.msg)
            end
        end
    end

    @testset "consume(::Positional); validator, Tuple{Vararg{Int}}" begin
        option = Positional(Int, "number", "numbers", validator = (7, 13), multiple = true)
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["7", "13"], 1)
            @test next_index == 3
            @test result.numbers isa Vector{Int}
            @test result.numbers == [7, 13]
        end
        option = Positional(Int, "number", validator = (7, 13))
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["7"], 1)
            @test next_index == 2
            @test result.number isa Int
            @test result.number == 7
        end
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["13"], 1)
            @test next_index == 2
            @test result.number isa Int
            @test result.number == 13
        end
        let result = CliOptions.ParseResult()
            try
                CliOptions.consume!(result, option, ["9"], 1)
            catch ex
                @test ex isa CliOptionError
                @test occursin("9", ex.msg)
                @test occursin("must be one of", ex.msg)
                @test occursin("7", ex.msg)
                @test occursin("13", ex.msg)
            end
        end
    end

    @testset "consume(::Positional); validator, Regex" begin
        option = Positional("name", "names", validator = Regex("qu+x"), multiple = true)
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["qux", "quux"], 1)
            @test next_index == 3
            @test result.names == ["qux", "quux"]
        end
        option = Positional("name", validator = Regex("qu+x"))
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["qux"], 1)
            @test next_index == 2
            @test result.name == "qux"
        end
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["quux"], 1)
            @test next_index == 2
            @test result.name == "quux"
        end
        let result = CliOptions.ParseResult()
            try
                CliOptions.consume!(result, option, ["foo"], 1)
            catch ex
                @test ex isa CliOptionError
                @test occursin("foo", ex.msg)
                @test occursin("must match for", ex.msg)
                @test occursin("qu+x", ex.msg)
            end
        end
    end

    @testset "consume(::Positional); validator, String -> Bool" begin
        f = s -> startswith(s, "foo")
        g = n -> iseven(n)

        option = Positional("name", "names", validator = f, multiple = true)
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["foo", "foobar"], 1)
            @test next_index == 3
            @test result.names == ["foo", "foobar"]
        end
        option = Positional("name", validator = f)
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["foo"], 1)
            @test next_index == 2
            @test result.name == "foo"
        end

        # String
        let result = CliOptions.ParseResult()
            try
                CliOptions.consume!(result, option, ["bar"], 1)
            catch ex
                @test ex isa CliOptionError
                @test occursin("bar", ex.msg)
                @test occursin("validation failed", ex.msg)
            end
        end

        # non-String
        option = Positional(Int8, "name", validator = g)
        let result = CliOptions.ParseResult()
            try
                CliOptions.consume!(result, option, ["7"], 1)
            catch ex
                @test ex isa CliOptionError
                @test occursin("Int8", ex.msg)
                @test occursin("7", ex.msg)
                @test occursin("validation failed", ex.msg)
            end
        end
    end

    @testset "consume(::Positional); validator, String -> String" begin
        f = s -> startswith(s, "foo") ? "" : "It's not foo"
        g = n -> iseven(n) ? "" : "must be even"

        option = Positional("name", "names", validator = f, multiple = true)
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["foo", "foobar"], 1)
            @test next_index == 3
            @test result.names == ["foo", "foobar"]
        end
        option = Positional("name", validator = f)
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, option, ["foo"], 1)
            @test next_index == 2
            @test result.name == "foo"
        end

        # String
        let result = CliOptions.ParseResult()
            try
                CliOptions.consume!(result, option, ["bar"], 1)
            catch ex
                @test ex isa CliOptionError
                @test occursin("bar", ex.msg)
                @test occursin("It's not foo", ex.msg)
            end
        end

        # non-String
        option = Positional(Int8, "name", validator = g)
        let result = CliOptions.ParseResult()
            try
                CliOptions.consume!(result, option, ["7"], 1)
            catch ex
                @test ex isa CliOptionError
                @test occursin("Int8", ex.msg)
                @test occursin("7", ex.msg)
                @test occursin("must be even", ex.msg)
            end
        end
    end

    @testset "post_parse_action!(::Positional)" begin
        # Once evaluated
        let result = CliOptions.ParseResult()
            option = Positional("file", default = nothing)
            result._counter[option] = 1
            rv = CliOptions.post_parse_action!(result, option)
            @test rv === nothing
            @test sorted_keys(result._dict) == String[]
        end

        # Not evaluated, no default value
        let result = CliOptions.ParseResult()
            option = Positional("file", default = nothing)
            @test_throws CliOptionError CliOptions.post_parse_action!(result, option)
        end

        # Not evaluated, default value was set
        let result = CliOptions.ParseResult()
            option = Positional("file"; default = "foo")
            rv = CliOptions.post_parse_action!(result, option)
            @test rv === nothing
            @test sorted_keys(result._dict) == ["file"]
            @test result.file == "foo"
        end
    end
end
