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

    @testset "consume(::Positional)" begin
        @testset "empty args" begin
            let result = CliOptions.ParseResult()
                option = Positional("file")
                @test_throws AssertionError consume!(result, option, Vector{String}(), 1)
            end
        end

        @testset "single" begin
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

        @testset "multiple" begin
            let result = CliOptions.ParseResult()
                option = Positional("file", multiple = true)
                next_index = consume!(result, option, [""], 1)
                @test next_index == 2
                @test sorted_keys(result._dict) == ["file"]
                @test result.file == [""]
            end
            let result = CliOptions.ParseResult()
                option = Positional("file", "files", multiple = true)
                next_index = consume!(result, option, ["a"], 1)
                @test next_index == 2
                @test sorted_keys(result._dict) == ["file", "files"]
                @test result.file == ["a"]
                @test result.files == ["a"]
            end
            let result = CliOptions.ParseResult()
                option = Positional("file", multiple = true)
                next_index = consume!(result, option, ["a", "b"], 1)
                @test next_index == 3
                @test sorted_keys(result._dict) == ["file"]
                @test result.file == ["a", "b"]
            end
        end

        @testset "type" begin
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
