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
        ("single", false, [""], 1, ""),
        ("single", false, ["a"], 1, "a"),
        ("multiple", true, String[], 0, AssertionError),
        ("multiple", true, [""], 1, [""]),
        ("multiple", true, ["a"], 1, ["a"]),
        ("multiple", true, ["a", "b"], 2, ["a", "b"]),
    ]
        _, multiple, args, expected_rv, expected = v
        d = Dict{String,Any}()
        ctx = CliOptions.ParseContext()
        option = Positional("file", "files"; multiple = multiple)
        if expected isa Type
            @test_throws expected consume!(d, option, args, ctx)
        else
            next_index = consume!(d, option, args, ctx)
            @test next_index == expected_rv
            @test sorted_keys(d) == ["file", "files"]
            @test d["file"] == expected
        end
    end

    @testset "consume!(); type, $(v[1]), $(v[2])" for v in [
        (Int32, ["2"], Int32(2)),
        (Int32, ["-3"], Int32(-3)),
        (Date, ["2006-01-02"], Date(2006, 1, 2)),
        (Date, ["__not_a_date__"], CliOptionError),
    ]
        T, args, expected = v
        d = Dict{String,Any}()
        ctx = CliOptions.ParseContext()
        option = Positional(T, "value")
        if expected isa Type
            @test_throws expected consume!(d, option, args, ctx)
        else
            consume!(d, option, args, ctx)
            @test d["value"] == expected
        end
    end

    @testset "consume!(); requirement, $(v[1])" for v in [
        ("[7, 13], 13", ["13"],
            Int, [7, 13], (1, 13)),
        ("[7, 13], 7", ["7"],
            Int, [7, 13], (1, 7)),
        ("[7, 13], 0", ["0"],
            Int, [7, 13], (CliOptionError, "must be one of")),
        ("(7, 13), 13", ["13"],
            Int, (7, 13), (1, 13)),
        ("(7, 13), 7", ["7"],
            Int, (7, 13), (1, 7)),
        ("(7, 13), 0", ["0"],
            Int, (7, 13), (CliOptionError, "must be one of")),
        ("/qu+x/, quux", ["quux"],
            String, Regex("qu+x"), (1, "quux")),
        ("/qu+x/, qux", ["qux"],
            String, Regex("qu+x"), (1, "qux")),
        ("/qu+x/, qx", ["qx"],
            String, Regex("qu+x"), (CliOptionError, "must match for")),
        ("String -> Bool, foo", ["foo"],
            String, s -> startswith(s, "foo"), (1, "foo")),
        ("String -> Bool, 6", ["6"],
            Int, n -> iseven(n), (1, 6)),
        ("String -> Bool, 7", ["7"],
            Int, n -> iseven(n), (CliOptionError, "validation failed")),
        ("String -> String, foo", ["foo"],
            String, s -> startswith(s, "foo") ? "" : "It's not foo", (1, "foo")),
        ("String -> String, 6", ["6"],
            Int, n -> iseven(n) ? "" : "must be even", (1, 6)),
        ("String -> String, 7", ["7"],
            Int, n -> iseven(n) ? "" : "must be even", (CliOptionError, "must be even")),
    ]
        _, args, T, requirement, expected = v
        option = Positional(T, "name"; requirement = requirement)
        let d = Dict{String,Any}()
            ctx = CliOptions.ParseContext()
            if expected[1] isa Type
                try
                    CliOptions.consume!(d, option, args, ctx)
                    @test false  # Exception must be thrown
                catch ex
                    @test ex isa expected[1]
                    @test occursin(args[1], ex.msg)
                    @test occursin(expected[2], ex.msg)
                end
            else
                num_consumed = CliOptions.consume!(d, option, args, ctx)
                @test num_consumed == expected[1]
                @test d["name"] == expected[2]
            end
        end
    end

    @testset "check_usage_count(); $(v[1])" for v in [
        ("required, 0", missing, 0, CliOptionError),
        ("required, 1", missing, 1, nothing),
        ("omittable, 0", "foo", 0, nothing),
    ]
        _, default, count, expected = v
        option = Positional("file", default = default)
        ctx = CliOptions.ParseContext()
        ctx.usage_count[option] = count
        if expected isa Type
            @test_throws expected CliOptions.check_usage_count(option, ctx)
        else
            @test true  # No exception was thrown
        end
    end
end
