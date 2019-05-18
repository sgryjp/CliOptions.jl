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

    @testset "consume!(); args = Any[]" begin
        let d = Dict{String,Any}()
            ctx = CliOptions.ParseContext()
            option = RemainderOption()
            @test_throws AssertionError CliOptions.consume!(d, option, [], 1, ctx)
        end
    end

    @testset "consume!(); names = $(v[1])" for v in [
        ([], ["--", "a", "b"], 4, "_remainders", ["a", "b"])
        (["-x"], ["-x", "a", "b"], 4, "x", ["a", "b"])
        (["--exec"], ["--exec", "a", "b"], 4, "exec", ["a", "b"])
    ]
        names, args, expected_next_index, key, expected_values = v
        dict = Dict{String,Any}()
        ctx = CliOptions.ParseContext()
        option = RemainderOption(names...)
        next_index = CliOptions.consume!(dict, option, args, 1, ctx)
        @test next_index == expected_next_index
        @test dict[key] == expected_values
    end
end
