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
        @test Option("-a").names == ("-a",)
        @test Option("-a", "-b").names == ("-a", "-b")

        @test Option(String, "-a").T == String
        @test Option(DateTime, "-a").T == DateTime
        @test Option(UInt32, "-a").T == UInt32
    end

    @testset "show(x); $(join(v[1],','))" for v in [
        (["-a"], "Option(:a)"),
        (["-a", "--foo-bar"], "Option(:a,:foo_bar)"),
    ]
        names, expected_repr = v
        option = Option(names...)
        @test repr(option) == expected_repr
    end

    @testset "show(io, x)" begin
        let option = Option("-a")
            buf = IOBuffer()
            redirect_stdout(buf) do
                show(option)
            end
            @test String(take!(buf)) == "Option(:a)"
        end
    end

    @testset "consume!(); $(v[1])" for v in [
        ([""], (0, nothing)),
        (["-a"], (0, nothing)),
        (["-d"], CliOptionError),
        (["-d", "3"], (3, "3")),
    ]
        args, expected = v
        option = Option("-d", "--depth")
        d = Dict{String,Any}()
        ctx = CliOptions.ParseContext()
        if expected isa Type
            @test_throws expected CliOptions.consume!(d, option, args, 1, ctx)
        else
            next_index = CliOptions.consume!(d, option, args, 1, ctx)
            @test next_index == expected[1]
            if expected[2] !== nothing
                @test d["d"] == expected[2]
                @test d["depth"] == expected[2]
            end
        end
    end

    @testset "consume!(); type, $(v[1])" for v in [
        # ctor
        ("constructible", Date, ["-a", "2006-01-02"], (3, Date(2006, 1, 2))),

        # Base.parse
        ("parsable, -1", UInt8, ["-a", "-1"], CliOptionError),
        ("parsable, 0", UInt8, ["-a", "0"], (3, UInt8(0))),
        ("parsable, 255", UInt8, ["-a", "255"], (3, UInt8(255))),
        ("parsable, 256", UInt8, ["-a", "256"], CliOptionError),

        # N/A
        ("unacceptable", AbstractFloat, ["-a", "42"], CliOptionError),
    ]
        _, T, args, expected = v
        option = Option(T, "-a")
        d = Dict{String,Any}()
        ctx = CliOptions.ParseContext()
        if expected isa Type
            @test_throws expected CliOptions.consume!(d, option, args, 1, ctx)
        else
            next_index = CliOptions.consume!(d, option, args, 1, ctx)
            @test next_index == expected[1]
            @test d["a"] == expected[2]
        end
    end

    @testset "consume!(); validator, $(v[1])" for v in [
        ("[foo, bar], foo", ["-a", "foo"],
            String, ["foo", "bar"], (3, "foo")),
        ("[foo, bar], bar", ["-a", "bar"],
            String, ["foo", "bar"], (3, "bar")),
        ("[foo, bar], qux", ["-a", "qux"],
            String, ["foo", "bar"], (CliOptionError, "must be one of")),
        ("(foo, bar), foo", ["-a", "foo"],
            String, ("foo", "bar"), (3, "foo")),
        ("(foo, bar), bar", ["-a", "bar"],
            String, ("foo", "bar"), (3, "bar")),
        ("(foo, bar), qux", ["-a", "qux"],
            String, ("foo", "bar"), (CliOptionError, "must be one of")),
        ("/qu+x/, quux/", ["-a", "quux"],
            String, Regex("qu+x"), (3, "quux")),
        ("/qu+x/, qux", ["-a", "qux"],
            String, Regex("qu+x"), (3, "qux")),
        ("/qu+x/, qx", ["-a", "qx"],
            String, Regex("qu+x"), (CliOptionError, "must match for")),
        ("String -> Bool, foo", ["-a", "foo"],
            String, s -> startswith(s, "foo"), (3, "foo")),
        ("String -> Bool, 6", ["-a", "6"],
            Int, n -> iseven(n), (3, 6)),
        ("String -> Bool, 7", ["-a", "7"],
            Int, n -> iseven(n), (CliOptionError, "validation failed")),
        ("String -> String, foo", ["-a", "foo"],
            String, s -> startswith(s, "foo") ? "" : "It's not foo", (3, "foo")),
        ("String -> String, 6", ["-a", "6"],
            Int, n -> iseven(n) ? "" : "must be even", (3, 6)),
        ("String -> String, 7", ["-a", "7"],
            Int, n -> iseven(n) ? "" : "must be even", (CliOptionError, "must be even")),
    ]
        _, args, T, validator, expected = v
        option = Option(T, "-a"; validator = validator)
        d = Dict{String,Any}()
        ctx = CliOptions.ParseContext()
        if expected[1] isa Type
            try
                CliOptions.consume!(d, option, args, 1, ctx)
                @test false  # Exception must be thrown
            catch ex
                @test ex isa expected[1]
                @test occursin(args[1], ex.msg)
                @test occursin(expected[2], ex.msg)
            end
        else
            next_index = CliOptions.consume!(d, option, args, 1, ctx)
            @test next_index == expected[1]
            @test d["a"] == expected[2]
        end
    end

    @testset "consume!(); until, $(v[1])" for v in [
        ("nothing, String", String, nothing, (3, "1"))
        ("nothing, Int", Int, nothing, (3, 1))
        ("4, String", String, "4", (6, ["1", "2", "3"]))
        ("4, Int", Int, "4", (6, [1, 2, 3]))
        ("[4, 3], String", String, ["4", "3"], (5, ["1", "2"]))
        ("[4, 3], Int", Int, ["4", "3"], (5, [1, 2]))
        ("(4, 3), String", String, ("4", "3"), (5, ["1", "2"]))
        ("(4, 3), Int", Int, ("4", "3"), (5, [1, 2]))
    ]
        _, T, until, expected = v
        args = split("-a 1 2 3 4")
        option = Option(T, "-a"; until = until)
        d = Dict{String,Any}()
        ctx = CliOptions.ParseContext()
        if expected[1] isa Type
            try
                CliOptions.consume!(d, option, args, 1, ctx)
                @test false  # Exception must be thrown
            catch ex
                @test ex isa expected[1]
                @test occursin(args[1], ex.msg)
                @test occursin(expected[2], ex.msg)
            end
        else
            next_index = CliOptions.consume!(d, option, args, 1, ctx)
            @test next_index == expected[1]
            @test d["a"] == expected[2]
        end
    end

    @testset "check_usage_count(); $(v[1])" for v in [
        ("required, 0", missing, 0, CliOptionError),
        ("required, 1", missing, 1, nothing),
        ("omittable, 0", "foo", 0, nothing),
    ]
        _, default, count, expected = v
        option = Option("-n", default = default)
        ctx = CliOptions.ParseContext()
        ctx.usage_count[option] = count
        if expected isa Type
            @test_throws expected CliOptions.check_usage_count(option, ctx)
        else
            @test true  # No exception was thrown
        end
    end
end
