using Dates
using Test
using CliOptions


@testset "RemainderOption()" begin
    @testset "ctor; $(repr(v[1]))" for v in [
        ("", "must not be empty"),
        ("a", "must start with a hyphen"),
        ("-", "Invalid name"),
    ]
        names, msg = v
        try
            RemainderOption(names)
        catch ex
            @test ex isa ArgumentError
            @test occursin(msg, ex.msg)
        end
    end

    @testset "ctor; $(v[1])" for v in [
        (String[], ("--",)),
        (["-x", "--exec"], ("-x", "--exec")),
    ]
        names, expected_names = v
        option = RemainderOption(names...)
        @test option.names == expected_names
    end

    @testset "show(x); $(join(v[1],','))" for v in [
        ([], "RemainderOption(:_remainders)"),
        (["-x"], "RemainderOption(:x)"),
        (["-x", "--exec"], "RemainderOption(:x,:exec)"),
    ]
        names, expected_repr = v
        option = RemainderOption(names...)
        @test repr(option) == expected_repr
    end

    @testset "show(io, x)" begin
        let option = RemainderOption()
            buf = IOBuffer()
            redirect_stdout(buf) do
                show(option)
            end
            @test String(take!(buf)) == "RemainderOption(:_remainders)"
        end
    end

    @testset "consume(); args = Any[]" begin
        let result = CliOptions.ParseResult()
            option = RemainderOption()
            @test_throws AssertionError CliOptions.consume!(result, [option],
                                                            option, String[], 1)
        end
    end

    @testset "consume(); names = $(v[1])" for v in [
        ([], ["--", "a", "b"], 4, :_remainders, ["a", "b"])
        (["-x"], ["-x", "a", "b"], 4, :x, ["a", "b"])
        (["--exec"], ["--exec", "a", "b"], 4, :exec, ["a", "b"])
    ]
        names, args, expected_next_index, property, expected_values = v
        result = CliOptions.ParseResult()
        option = RemainderOption(names...)
        next_index = CliOptions.consume!(result, [option], option, args, 1)
        @test next_index == expected_next_index
        @test getproperty(result, property) == expected_values
    end

    @testset "post_parse_action!(); consumed nothing; $(v[1])" for v in [
        ([], [:_remainders], AbstractString[]),
        (["-x", "--exec"], [:x, :exec], AbstractString[]),
    ]
        names, keys, values = v
        result = CliOptions.ParseResult()
        option = RemainderOption(names...)
        CliOptions.post_parse_action!(result, option)
        for k in keys
            @test k in propertynames(result)
            @test getproperty(result, k) == values
        end
    end
end
