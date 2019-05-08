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

    @testset "FlagOption" begin  #TODO: 背反
        spec = CliOptionSpec(FlagOption("-a"; negators = ["-b"]))
        args = parse_args(spec, ["-a"])
        @test args.a == true
        @test args.b == false

        args = parse_args(spec, ["-b"])
        @test args.a == false
        @test args.b == true

        spec = CliOptionSpec(FlagOption("-a"; negators = ["-b"]), FlagOption("-c"))
        args = parse_args(spec, ["-c"])
        @test args.c == true
        @test args.a == false
        @test args.b == true
    end

    @testset "CounterOption" begin  #TODO: 背反
        spec = CliOptionSpec(CounterOption("-a"; decrementers = ["-b"]))
        args = parse_args(spec, ["-a"])
        @test sorted_keys(args._dict) == ["a"]
        @test args.a == 1

        args = parse_args(spec, ["-b"])
        @test sorted_keys(args._dict) == ["a"]
        @test args.a == -1

        @testset "implicit default" begin
            spec = CliOptionSpec(CounterOption(Int8, "-a"; decrementers = ["-b"]),
                                 CounterOption(Int32, "-c"))
            args = parse_args(spec, ["-c"])
            @test sorted_keys(args._dict) == ["a", "c"]
            @test args.a == 0
            @test typeof(args.a) == Int8
            @test args.c == 1
            @test typeof(args.c) == Int32
        end

        @testset "explicit default" begin
            spec = CliOptionSpec(CounterOption(Int8, "-a";
                                               decrementers = ["-b"],
                                               default = -1),
                                 CounterOption(Int32, "-c"))
            args = parse_args(spec, ["-a"])
            @test args.a == 0
            args = parse_args(spec, ["-c"])
            @test args.a == -1
            args = parse_args(spec, ["-b"])
            @test args.a == -2

            spec = CliOptionSpec(CounterOption(Int8, "-a";
                                               decrementers = ["-b"], default = 127))
            @test_throws InexactError parse_args(spec, ["-a"])
            spec = CliOptionSpec(CounterOption(Int8, "-a";
                                               decrementers = ["-b"], default = -128))
            @test_throws InexactError parse_args(spec, ["-b"])
        end
    end

    @testset "Positional" begin
        @testset "$(v[1]), $(v[4])" for v in [
            # single, required
            ("single, required", false, nothing, String[], CliOptionError),
            ("single, required", false, nothing, ["a"], "a"),
            ("single, required", false, nothing, ["a", "b"], CliOptionError),
            #("single, required", false, nothing, ["-1"], "-1"),
            #("single, required", false, nothing, ["-a"], CliOptionError),

            # single, omittable
            ("single, omittable", false, "foo.txt", String[], "foo.txt"),
            ("single, omittable", false, "foo.txt", ["a"], "a"),
            ("single, omittable", false, "foo.txt", ["a", "b"], CliOptionError),

            # multiple, required
            ("multiple, required", true, nothing, String[], CliOptionError),
            ("multiple, required", true, nothing, ["a"], ["a"]),
            ("multiple, required", true, nothing, ["a", "b"], ["a", "b"]),
            #("multiple, required", true, nothing, ["a", "-1"], "-1"),
            #("multiple, required", true, nothing, ["a", "-a"], CliOptionError),

            # multiple, omittable
            ("multiple, omittable", true, "foo.txt", String[], "foo.txt"),
            ("multiple, omittable", true, "foo.txt", ["a"], ["a"]),
            ("multiple, omittable", true, "foo.txt", ["a", "b"], ["a", "b"]),
        ]
            title, multiple, default, args, expected = v
            spec = CliOptionSpec(
                Positional("file", "files"; multiple = multiple, default = default),
            )
            if expected == CliOptionError
                @test_throws expected parse_args(spec, args)
            else
                args = parse_args(spec, args)
                @test args.file == expected
                @test args.files == expected
            end
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
