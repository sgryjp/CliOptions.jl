using Dates
using Test
using CliOptions
using CliOptions: consume!

@testset "Positional()" begin
    @testset "ctor; $(v[1]); $(v[4])" for v in [
        ("single, required", false, nothing, [""], ArgumentError),
        ("single, required", false, nothing, ["-a"], ArgumentError),
        ("single, required", false, nothing, ["a", "-b"], ArgumentError),
        ("single, required", false, nothing, ["a"], ("a",)),
        ("single, required", false, nothing, ["a", "b"], ("a", "b")),
        ("multiple, required", true, nothing, ["a"], ("a",)),
        ("multiple, required", true, nothing, ["a", "b"], ("a", "b")),
        ("single, omittable", false, 42, ["a"], ("a",)),
        ("single, omittable", false, 42, ["a", "b"], ("a", "b")),
    ]
        _, multiple, default, names, expected = v
        if expected isa Type
            @test_throws expected Positional(names...;
                                             multiple = multiple,
                                             default = default)
        else
            option = Positional(names...; multiple = multiple, default = default)
            @test option.names == expected
            @test option.multiple == multiple
            @test option.default === default
        end
    end

    @testset "show(x); $(v[1])" for v in [
        (["file"], "Positional(:file)"),
        (["file", "files"], "Positional(:file,:files)"),
    ]
        names, expected_repr = v
        option = Positional(names...)
        @test repr(option) == expected_repr
    end

    @testset "show(io, x)" begin
        let option = Positional("file")
            buf = IOBuffer()
            redirect_stdout(buf) do
                show(option)
            end
            @test String(take!(buf)) == "Positional(:file)"
        end
    end

    @testset "consume!(); $(v[1]), $(v[3])" for v in [
        ("single", false, String[], 0, AssertionError),
        ("single", false, [""], 2, ""),
        ("single", false, ["a"], 2, "a"),
        ("multiple", true, String[], 0, AssertionError),
        ("multiple", true, [""], 2, [""]),
        ("multiple", true, ["a"], 2, ["a"]),
        ("multiple", true, ["a", "b"], 3, ["a", "b"]),
    ]
        _, multiple, args, expected_rv, expected = v
        result = CliOptions.ParseResult()
        option = Positional("file", "files"; multiple = multiple)
        if expected isa Type
            @test_throws expected consume!(result, [option], option, args, 1)
        else
            next_index = consume!(result, [option], option, args, 1)
            @test next_index == expected_rv
            @test sorted_keys(result._dict) == ["file", "files"]
            @test result.file == expected
        end
    end

    @testset "consume!(); type, $(v[1]), $(v[2])" for v in [
        (Int32, ["2"], Int32(2)),
        (Int32, ["-3"], Int32(-3)),
        (Date, ["2006-01-02"], Date(2006, 1, 2)),
        (Date, ["__not_a_date__"], CliOptionError),
    ]
        T, args, expected = v
        result = CliOptions.ParseResult()
        option = Positional(T, "value")
        if expected isa Type
            @test_throws expected consume!(result, [option], option, args, 1)
        else
            consume!(result, [option], option, args, 1)
            @test result.value == expected
        end
    end

    @testset "consume(::Positional); validator, Vector{String}" begin
        option = Positional("name", "names", validator = ["foo", "bar"], multiple = true)
        let result = CliOptions.ParseResult()
            next_index = consume!(result, [option], option, ["foo", "bar"], 1)
            @test next_index == 3
            @test result.names == ["foo", "bar"]
        end

        option = Positional("name", validator = ["foo", "bar"])
        let result = CliOptions.ParseResult()
            next_index = consume!(result, [option], option, ["foo"], 1)
            @test next_index == 2
            @test result.name == "foo"
        end
        let result = CliOptions.ParseResult()
            next_index = consume!(result, [option], option, ["bar"], 1)
            @test next_index == 2
            @test result.name == "bar"
        end
        let result = CliOptions.ParseResult()
            try
                CliOptions.consume!(result, [option], option, ["baz"], 1)
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
            next_index = CliOptions.consume!(result, [option], option, ["7", "13"], 1)
            @test next_index == 3
            @test result.numbers isa Vector{Int}
            @test result.numbers == [7, 13]
        end
        option = Positional(Int, "number", validator = (7, 13))
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, [option], option, ["7"], 1)
            @test next_index == 2
            @test result.number isa Int
            @test result.number == 7
        end
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, [option], option, ["13"], 1)
            @test next_index == 2
            @test result.number isa Int
            @test result.number == 13
        end
        let result = CliOptions.ParseResult()
            try
                CliOptions.consume!(result, [option], option, ["9"], 1)
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
            next_index = CliOptions.consume!(result, [option], option, ["qux", "quux"], 1)
            @test next_index == 3
            @test result.names == ["qux", "quux"]
        end
        option = Positional("name", validator = Regex("qu+x"))
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, [option], option, ["qux"], 1)
            @test next_index == 2
            @test result.name == "qux"
        end
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, [option], option, ["quux"], 1)
            @test next_index == 2
            @test result.name == "quux"
        end
        let result = CliOptions.ParseResult()
            try
                CliOptions.consume!(result, [option], option, ["foo"], 1)
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
            next_index = CliOptions.consume!(result, [option], option, ["foo", "foobar"], 1)
            @test next_index == 3
            @test result.names == ["foo", "foobar"]
        end
        option = Positional("name", validator = f)
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, [option], option, ["foo"], 1)
            @test next_index == 2
            @test result.name == "foo"
        end

        # String
        let result = CliOptions.ParseResult()
            try
                CliOptions.consume!(result, [option], option, ["bar"], 1)
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
                CliOptions.consume!(result, [option], option, ["7"], 1)
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
            next_index = CliOptions.consume!(result, [option], option, ["foo", "foobar"], 1)
            @test next_index == 3
            @test result.names == ["foo", "foobar"]
        end
        option = Positional("name", validator = f)
        let result = CliOptions.ParseResult()
            next_index = CliOptions.consume!(result, [option], option, ["foo"], 1)
            @test next_index == 2
            @test result.name == "foo"
        end

        # String
        let result = CliOptions.ParseResult()
            try
                CliOptions.consume!(result, [option], option, ["bar"], 1)
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
                CliOptions.consume!(result, [option], option, ["7"], 1)
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
