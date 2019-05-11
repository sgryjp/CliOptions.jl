using Test
using CliOptions

@testset "parse_args()" begin
    @testset "type of args; $(typeof(v))" for v in [
        ["-abc", "foo", "bar"],
        ("-abc", "foo", "bar"),
        split("-abc foo bar"),
    ]
        args = v
        spec = CliOptionSpec(FlagOption("-a"),
                             CounterOption("-b"),
                             Option("-c"),
                             Positional("d"))
        result = parse_args(spec, args)
        @test result.a == true
        @test result.b == 1
        @test result.c == "foo"
        @test result.d == "bar"
    end

    let spec = CliOptionSpec(Option("-n", "--num-workers"), FlagOption("-i"))
        @testset "`-ab` to `-a -b`" begin
            args = parse_args(spec, ["-i", "-n", "3"])
            @test args.i == true
            @test args.n == "3"

            args = parse_args(spec, ["-in", "3"])
            @test args.i == true
            @test args.n == "3"

            @test_throws CliOptionError parse_args(spec, ["-ni", "3"])
        end
        @testset "`--foo=bar` to `--foo bar`" begin
            args = parse_args(spec, ["--num-workers", "3"])
            @test args.i == false
            @test args.n == "3"

            args = parse_args(spec, ["--num-workers=3"])
            @test args.i == false
            @test args.n == "3"
        end
    end

    @testset "Option" begin
        @testset "required" begin
            spec = CliOptionSpec(
                Option("-a"),
            )
            @test_throws CliOptionError parse_args(spec, String[])
            @test_throws CliOptionError parse_args(spec, ["-a"])
            args = parse_args(spec, ["-a", "bar"])
            @test args.a == "bar"
            @test_throws CliOptionError parse_args(spec, ["-a", "bar", "-a"])
        end

        @testset "omittable" begin
            spec = CliOptionSpec(
                Option("-a"; default = missing),
            )
            args = parse_args(spec, String[])
            @test ismissing(args.a)
        end
    end

    @testset "FlagOption; $(v[1])" for v in [
        (["-a"], true),
        (["-b"], false),
        ([], false),
    ]
        args, expected = v
        spec = CliOptionSpec(
            FlagOption("-a"; negators = "-b")
        )
        result = parse_args(spec, args)
        @test result.a == expected
        @test result.b == !expected
    end

    @testset "CounterOption; $(v[1:3])" for v in [
        (Int8, 127, "--add", InexactError),
        (Int8, 126, "--add", Int8(127)),
        (Int8, -127, "--sub", Int8(-128)),
        (Int8, -128, "--sub", InexactError),
        (Int128, 0, "--add --sub", Int128(0)),
    ]
        T, default, args, expected = v
        spec = CliOptionSpec(CounterOption(T, "--add";
                                           decrementers = ["--sub"],
                                           default = default))
        if expected isa Type
            @test_throws expected parse_args(spec, split(args))
        else
            args = parse_args(spec, split(args))
            @test sorted_keys(args._dict) == ["add"]
            @test args.add == expected
            @test typeof(args.add) == typeof(expected)
        end
    end

    @testset "Positional; $(v[1]), $(v[4])" for v in [
        # single, required
        ("single, required", false, nothing, String[], CliOptionError),
        ("single, required", false, nothing, ["a"], "a"),
        ("single, required", false, nothing, ["a", "b"], CliOptionError),
        ("single, required", false, nothing, ["-1"], "-1"),
        ("single, required", false, nothing, ["-7"], CliOptionError),
        ("single, required", false, nothing, ["-a"], CliOptionError),

        # single, omittable
        ("single, omittable", false, "foo.txt", String[], "foo.txt"),
        ("single, omittable", false, "foo.txt", ["a"], "a"),
        ("single, omittable", false, "foo.txt", ["a", "b"], CliOptionError),

        # multiple, required
        ("multiple, required", true, nothing, String[], CliOptionError),
        ("multiple, required", true, nothing, ["a"], ["a"]),
        ("multiple, required", true, nothing, ["a", "b"], ["a", "b"]),
        ("multiple, required", true, nothing, ["a", "-1"], ["a", "-1"]),
        ("multiple, required", true, nothing, ["a", "-7"], ["a"]),
        ("multiple, required", true, nothing, ["a", "-a"], CliOptionError),
        ("multiple, required", true, nothing, ["-1", "a"], ["-1", "a"]),
        ("multiple, required", true, nothing, ["-7", "a"], ["a"]),
        ("multiple, required", true, nothing, ["-a", "a"], CliOptionError),

        # multiple, omittable
        ("multiple, omittable", true, "foo.txt", String[], "foo.txt"),
        ("multiple, omittable", true, "foo.txt", ["a"], ["a"]),
        ("multiple, omittable", true, "foo.txt", ["a", "b"], ["a", "b"]),
    ]
        title, multiple, default, args, expected = v
        spec = CliOptionSpec(
            FlagOption("-7"),
            Positional("file", "files"; multiple = multiple, default = default),
        )
        if expected == CliOptionError
            @test_throws expected parse_args(spec, args)
        else
            result = parse_args(spec, args)
            @test result.file == expected
            @test result.files == expected
        end
    end

    @testset "RemainderOption; $(v[1]), $(v[2])" for v in [
        (["--"], String[], AbstractString[]),
        (["--"], ["a", "-7", "--c"], CliOptionError),
        (["--"], ["--", "a", "-7", "--c"], ["a", "-7", "--c"]),
    ]
        names, args, expected = v
        spec = CliOptionSpec(
            FlagOption("-7"),
            RemainderOption(names...),
        )
        if expected isa Type
            try
                parse_args(spec, args)
                @assert false "Must throw an exception"
            catch ex
                @test ex isa CliOptionError
                @test occursin(repr(args[1]), ex.msg)
            end
        else
            args = parse_args(spec, args)
            @test args._remainders == expected
        end
    end

    @testset "OptionGroup" begin
        spec = CliOptionSpec(
            OptionGroup(
                Option("-a"),
                Option("-b"),
            ),
        )
        @test_throws CliOptionError parse_args(spec, String[])
        @test_throws CliOptionError parse_args(spec, split("-a foo"))
        @test_throws CliOptionError parse_args(spec, split("-b bar"))
        args = parse_args(spec, split("-a foo -b bar"))
        @test args.a == "foo"
        @test args.b == "bar"
        @test_throws CliOptionError parse_args(spec, split("-a foo -b bar baz"))
    end

    @testset "MutexGroup" begin
        spec = CliOptionSpec(
            MutexGroup(
                Option("-a"),
                Option("-b"),
                Option("-c"),
            ),
        )
        @test_throws CliOptionError parse_args(spec, String[])
        args = parse_args(spec, split("-a foo"))
        @test args._dict == Dict("a" => "foo")
        args = parse_args(spec, split("-b bar"))
        @test args._dict == Dict("b" => "bar")
        @test_throws CliOptionError parse_args(spec, split("-a foo -b bar"))
        @test_throws CliOptionError parse_args(spec, split("-a foo -c baz"))
        @test_throws CliOptionError parse_args(spec, split("-a foo -b bar -c baz"))
        @test_throws CliOptionError parse_args(spec, split("-a foo quux"))
    end
end
