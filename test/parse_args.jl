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

    @testset "normalization; $(v[1])" for v in [
        (["-fa", "foo"], [FlagOption("-f"), Option("-a")], [:f => true, :a => "foo"]),
        (["-af", "foo"], [FlagOption("-f"), Option("-a")], ErrorException),
        (["--foo-bar=baz"], [Option("--foo-bar")], [:foo_bar => "baz"]),
    ]
        args, options, expected = v
        spec = CliOptionSpec(options...; onerror = error)
        if expected isa Type
            @test_throws expected parse_args(spec, args)
        else
            args = parse_args(spec, args)
            for (k, v) in expected
                @test getproperty(args, k) == v
            end
        end
    end

    @testset "Option" begin
        @testset "required" begin
            spec = CliOptionSpec(
                Option("-a"),
                onerror = error,
            )
            @test_throws ErrorException parse_args(spec, String[])
            @test_throws ErrorException parse_args(spec, ["-a"])
            args = parse_args(spec, ["-a", "bar"])
            @test args.a == "bar"
            @test_throws ErrorException parse_args(spec, ["-a", "bar", "-a"])
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
        (Int8, 127, "--add", ErrorException),
        (Int8, 126, "--add", Int8(127)),
        (Int8, -127, "--sub", Int8(-128)),
        (Int8, -128, "--sub", ErrorException),
        (Int128, 0, "--add --sub", Int128(0)),
    ]
        T, default, args, expected = v
        spec = CliOptionSpec(CounterOption(T, "--add";
                                           decrementers = ["--sub"],
                                           default = default),
                             onerror = error)
        if expected isa Type
            @test_throws expected parse_args(spec, split(args))
        else
            args = parse_args(spec, split(args))
            @test sorted_keys(args._dict) == ["add"]
            @test args.add == expected
            @test typeof(args.add) == typeof(expected)
        end
    end

    @testset "HelpOption; onhelp = $(v[1])" for v in [
        ("Integer", 42, (c) -> error("foobar$c"), (ErrorException, "foobar42")),
        ("Nothing", nothing, Base.exit, (true, nothing)),
        ("Function", () -> error("foo"), (c) -> error("$c"), (ErrorException, "foo")),
    ]
        _, onhelp, exitfunc, expected = v
        spec = CliOptionSpec(
            HelpOption(),
            onhelp = onhelp
        )
        CliOptions._mock_exit_function(exitfunc) do
            buf = IOBuffer()
            redirect_stdout(buf) do
                if expected[1] isa Type
                    @test_throws expected[1] parse_args(spec, ["-h"])
                    output = String(take!(buf))
                    @test occursin(output, expected[2])
                else
                    result = parse_args(spec, ["-h"])
                    @test result.help == expected[1]
                end
            end
        end
    end

    @testset "Positional; $(v[1]), $(v[4])" for v in [
        # single, required
        ("single, required", false, nothing, String[], ErrorException),
        ("single, required", false, nothing, ["a"], "a"),
        ("single, required", false, nothing, ["a", "b"], ErrorException),
        ("single, required", false, nothing, ["-1"], "-1"),
        ("single, required", false, nothing, ["-7"], ErrorException),
        ("single, required", false, nothing, ["-a"], ErrorException),

        # single, omittable
        ("single, omittable", false, "foo.txt", String[], "foo.txt"),
        ("single, omittable", false, "foo.txt", ["a"], "a"),
        ("single, omittable", false, "foo.txt", ["a", "b"], ErrorException),

        # multiple, required
        ("multiple, required", true, nothing, String[], ErrorException),
        ("multiple, required", true, nothing, ["a"], ["a"]),
        ("multiple, required", true, nothing, ["a", "b"], ["a", "b"]),
        ("multiple, required", true, nothing, ["a", "-1"], ["a", "-1"]),
        ("multiple, required", true, nothing, ["a", "-7"], ["a"]),
        ("multiple, required", true, nothing, ["a", "-a"], ErrorException),
        ("multiple, required", true, nothing, ["-1", "a"], ["-1", "a"]),
        ("multiple, required", true, nothing, ["-7", "a"], ["a"]),
        ("multiple, required", true, nothing, ["-a", "a"], ErrorException),

        # multiple, omittable
        ("multiple, omittable", true, "foo.txt", String[], "foo.txt"),
        ("multiple, omittable", true, "foo.txt", ["a"], ["a"]),
        ("multiple, omittable", true, "foo.txt", ["a", "b"], ["a", "b"]),
    ]
        title, multiple, default, args, expected = v
        spec = CliOptionSpec(
            FlagOption("-7"),
            Positional("file", "files"; multiple = multiple, default = default),
            onerror = error,
        )
        if expected == ErrorException
            @test_throws expected parse_args(spec, args)
        else
            result = parse_args(spec, args)
            @test result.file == expected
            @test result.files == expected
        end
    end

    @testset "RemainderOption; $(v[1]), $(v[2])" for v in [
        (["--"], String[], AbstractString[]),
        (["--"], ["a", "-7", "--c"], ErrorException),
        (["--"], ["--", "a", "-7", "--c"], ["a", "-7", "--c"]),
    ]
        names, args, expected = v
        spec = CliOptionSpec(
            FlagOption("-7"),
            RemainderOption(names...),
            onerror = error,
        )
        if expected isa Type
            try
                parse_args(spec, args)
                @assert false "Must throw an exception"
            catch ex
                @test ex isa ErrorException
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
            onerror = error,
        )
        @test_throws ErrorException parse_args(spec, String[])
        @test_throws ErrorException parse_args(spec, split("-a foo"))
        @test_throws ErrorException parse_args(spec, split("-b bar"))
        args = parse_args(spec, split("-a foo -b bar"))
        @test args.a == "foo"
        @test args.b == "bar"
        @test_throws ErrorException parse_args(spec, split("-a foo -b bar baz"))
    end

    @testset "MutexGroup" begin
        spec = CliOptionSpec(
            MutexGroup(
                Option("-a"),
                Option("-b"),
                Option("-c"),
            ),
            onerror = error,
        )
        @test_throws ErrorException parse_args(spec, String[])
        args = parse_args(spec, split("-a foo"))
        @test args.a == "foo"
        @test args.b === nothing
        @test args.c === nothing
        args = parse_args(spec, split("-b bar"))
        @test args.a === nothing
        @test args.b == "bar"
        @test args.c === nothing
        @test_throws ErrorException parse_args(spec, split("-a foo -b bar"))
        @test_throws ErrorException parse_args(spec, split("-a foo -c baz"))
        @test_throws ErrorException parse_args(spec, split("-a foo -b bar -c baz"))
        @test_throws ErrorException parse_args(spec, split("-a foo quux"))
    end

    @testset "onerror = $(v[1])" for v in [
        ("Integer", 42, (c) -> error("foobar$c"), (ErrorException, "foobar42")),
        ("Nothing", nothing, () -> error("foo bar"), ("\"-a\"", nothing)),
        ("Function", (msg) -> error("foo"), (c) -> error("$c"), (ErrorException, "foo")),
    ]
        t, onerror, exitfunc, expected = v
        spec = CliOptionSpec(
            FlagOption("-f"),
            Option("-a"),
            CounterOption("-v"),
            onerror = onerror
        )
        CliOptions._mock_exit_function(exitfunc) do
            buf = IOBuffer()
            redirect_stderr(buf) do
                if expected[1] isa Type
                    tr = @test_throws expected[1] parse_args(spec, ["-fva"])
                    if tr isa Test.Pass
                        @test occursin(expected[2], tr.value.msg)
                    end
                else
                    result = parse_args(spec, ["-fva"])
                    @test occursin(expected[1], result._errors[1])
                end
            end
        end
    end
end
