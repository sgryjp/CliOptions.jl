using Test
using CliOptions: encode

@testset "Internal utilities" begin

    @testset "_is_valid_option_or_throw(); $(v[1])" for v in [
        # valid form
        ("short form", Option, "-a", false, ""),
        ("long form", Option, "--foo-bar", false, ""),

        # article in an error message
        ("article for Option", Option, "a", true, "an Option"),
        ("article for FlagOption", FlagOption, "a", true, "a FlagOption"),
        ("article for CounterOption", CounterOption, "a", true, "a CounterOption"),

        # reason
        ("empty", Option, "", true, "must not be empty"),
        ("starting with non-hyphen", Option, "a", true, "must start with a hyphen"),
        ("double hyphen only", Option, "--", true, "Invalid name"),
    ]
        _, T, optval, should_fail, substr = v
        ok = false
        try
            CliOptions._is_valid_option_or_throw(T, optval)
            ok = true
        catch ex
            @test ex isa ArgumentError
            @test occursin("$T", ex.msg)
            @test occursin(optval, ex.msg)
            @test occursin(substr, ex.msg)
        end
        @test ok == !should_fail
    end

    @testset "encoding()" begin
        @test encode("f") == "f"
        @test encode("-f") == "f"
        @test encode("/f") == "f"
        @test encode("--f") == "f"
        @test encode("--foo-bar") == "foo_bar"
        @test encode("-foo bar") == "foo_bar"
    end

    @testset "CliOptionError; showerror" begin
        let ex = CliOptionError("foo bar")
            buf = IOBuffer()
            showerror(buf, ex)
            msg = String(take!(buf))
            @test occursin(repr(typeof(ex)), msg)
            @test occursin("foo bar", msg)
        end
    end

end
