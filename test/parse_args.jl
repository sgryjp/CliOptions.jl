using Test
using CliOptions

@testset "parse_args()" begin
    @testset "Mixed options" begin
        spec = CliOptionSpec(
            NamedOption("-n", "--num-workers"),
            FlagOption("-i", "--ignore-case", negators = ["--case-sensitive"]),
            Positional("filename"),
        )
        args = parse_args(spec, ["-n", "3", "test.db"])
        @test args isa CliOptions.ParsedArguments
        @test args._dict["n"] == "3"
        @test args._dict["num_workers"] == "3"
        @test args._dict["ignore_case"] == false
        @test args._dict["case_sensitive"] == true
        @test args._dict["filename"] == "test.db"
        @test args["n"] == "3"
        @test args["num_workers"] == "3"
        @test args["ignore_case"] == false
        @test args["case_sensitive"] == true
        @test args["filename"] == "test.db"
        @test args.n == "3"
        @test args.num_workers == "3"
        @test args.ignore_case == false
        @test args.case_sensitive == true
        @test args.filename == "test.db"

        @test_throws CliOptionError parse_args(spec, ["test.db", "test.txt"])
    end

    @testset "FlagOption" begin  #TODO: 背反
        spec = CliOptionSpec(FlagOption("-a"; negators = ["-b"]), )
        args = parse_args(spec, split("-a", " "))
        @test args.a == true
        @test args.b == false

        args = parse_args(spec, split("-b", ' '))
        @test args.a == false
        @test args.b == true

        spec = CliOptionSpec(FlagOption("-a"; negators = ["-b"]), FlagOption("-c"))
        args = parse_args(spec, ["-c"])
        @test args.c == true
        @test args.a == false
        @test args.b == true
    end

    @testset "CounterOption" begin  #TODO: 背反
        spec = CliOptionSpec(CounterOption("-a"; decrementers = ["-b"]), )
        args = parse_args(spec, ["-a"])
        @test sorted_keys(args._dict) == ["a"]
        @test args.a == 1

        args = parse_args(spec, ["-b"])
        @test sorted_keys(args._dict) == ["a"]
        @test args.a == -1

        spec = CliOptionSpec(CounterOption(Int8, "-a"; decrementers = ["-b"]),
                             CounterOption(Int32, "-c"))
        args = parse_args(spec, ["-c"])
        @test sorted_keys(args._dict) == ["a", "c"]
        @test args.a == 0
        @test typeof(args.a) == Int8
        @test args.c == 1
        @test typeof(args.c) == Int32
    end

    @testset "Positional" begin
        @testset "single, required" begin
            spec = CliOptionSpec(
                Positional("file", "files"),
            )
            @test_throws CliOptionError parse_args(spec, String[])
            args = parse_args(spec, ["a"])
            @test args.file == "a"
            @test args.files == "a"
            @test_throws CliOptionError parse_args(spec, ["a", "b"])
        end

        @testset "single, omittable" begin
            spec = CliOptionSpec(
                Positional("file", "files"; default = "foo.txt"),
            )
            args = parse_args(spec, String[])
            @test args.file == "foo.txt"
            @test args.files == "foo.txt"
            @test_throws CliOptionError parse_args(spec, ["a", "b"])
            args = parse_args(spec, ["a"])
            @test args.file == "a"
            @test args.files == "a"
            @test_throws CliOptionError parse_args(spec, ["a", "b"])
        end

        @testset "multiple, required" begin
            spec = CliOptionSpec(
                Positional("file", "files"; multiple = true),
            )
            @test_throws CliOptionError parse_args(spec, String[])
            args = parse_args(spec, ["a"])
            @test args.file == ["a"]
            @test args.files == ["a"]
            args = parse_args(spec, ["a", "-b"])
            @test args.file == ["a", "-b"]
            @test args.files == ["a", "-b"]
        end

        @testset "multiple, omittable" begin
            spec = CliOptionSpec(
                Positional("file", "files"; multiple = true, default = ["foo.txt"]),
            )
            args = parse_args(spec, String[])
            @test args.file == ["foo.txt"]
            @test args.files == ["foo.txt"]
            args = parse_args(spec, ["a"])
            @test args.file == ["a"]
            @test args.files == ["a"]
            args = parse_args(spec, ["a", "-b"])
            @test args.file == ["a", "-b"]
            @test args.files == ["a", "-b"]
        end
    end
end
