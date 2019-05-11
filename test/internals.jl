using Test
using CliOptions: encode

@testset "Internal utilities" begin

    @testset "_validate_option_names(); $(v[1])" for v in [
        # valid form
        ("short form", Option, ["-a"], false, ""),
        ("long form", Option, ["--foo-bar"], false, ""),

        # article in an error message
        ("article for Option", Option, ["a"], true, "an Option"),
        ("article for FlagOption", FlagOption, ["a"], true, "a FlagOption"),
        ("article for CounterOption", CounterOption,[ "a"], true, "a CounterOption"),

        # reason
        ("nameless", Option, String[], true, "At least one name"),
        ("empty", Option, [""], true, "must not be empty"),
        ("starting with non-hyphen", Option, ["a"], true, "must start with a hyphen"),
        ("double hyphen only", Option, ["--"], true, "Invalid name"),
    ]
        _, T, names, should_fail, substr = v
        ok = false
        try
            CliOptions._validate_option_names(T, names)
            ok = true
        catch ex
            @test ex isa ArgumentError
            if 1 ≤ length(names)
                @test occursin(names[1], ex.msg)
            end
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

    @testset "foreach_options; $(v[2])" for v in [
        (
            OptionGroup(
                FlagOption("-a"),
                MutexGroup(
                    CounterOption("-b"),
                    Option("-c")
                ),
                Positional("x"),
                OptionGroup(
                    Positional("y"),
                    Positional("z"),
                ),
            ),
            "-a;-b;-c;x;y;z;",
        ),
    ]
        root, trace = v
        buf = IOBuffer()
        CliOptions.foreach_options(root) do o
            if !isa(o, CliOptions.AbstractOptionGroup)
                print(buf, o.names[1])
                print(buf, ';')
            end
        end
        @test trace == String(take!(buf))
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
