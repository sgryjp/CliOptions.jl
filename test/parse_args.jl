using Test
using CliOptions

@testset "parse_args()" begin
    @testset "Mixed options" begin
        options = (
            NamedOption("-n", "--num-workers"),
            Positional("filename"),
        )
        args = parse_args(options, ["-n", "3", "test.db"])
        @test args isa CliOptions.ParsedArguments
        @test args._dict["n"] == "3"
        @test args._dict["num_workers"] == "3"
        @test args._dict["filename"] == "test.db"
        @test args["n"] == "3"
        @test args["num_workers"] == "3"
        @test args["filename"] == "test.db"
        @test args.n == "3"
        @test args.num_workers == "3"
        @test args.filename == "test.db"

        @test_throws CliOptionError parse_args(options, ["test.db", "test.txt"])
    end

    @testset "FlagOption" begin
        options = (FlagOption("-a"; negators=["-b"]),)
        args = parse_args(options, split("-a", " "))
        @test args.a == true
        @test args.b == false

        args = parse_args(options, split("-b", ' '))
        @test args.a == false
        @test args.b == true

        options = (FlagOption("-a"; negators=["-b"]), FlagOption("-c"))
        args = parse_args(options, ["-c"])
        @test args.c == true
        @test args.a == false
        @test args.b == true
    end

    @testset "Positional" begin
        @testset "quantity:1, required" begin
            options = (Positional("file", "files"; quantity='1'),)
            @test_throws CliOptionError parse_args(options, String[])
            args = parse_args(options, ["a"])
            @test args.file == "a"
            @test args.files == "a"
            @test_throws CliOptionError parse_args(options, ["a", "b"])
        end

        @testset "quantity:1, omittable" begin
            options = (Positional("file", "files"; quantity='1', default="foo.txt"),)
            args = parse_args(options, String[])
            @test args.file == "foo.txt"
            @test args.files == "foo.txt"
            @test_throws CliOptionError parse_args(options, ["a", "b"])
            args = parse_args(options, ["a"])
            @test args.file == "a"
            @test args.files == "a"
            @test_throws CliOptionError parse_args(options, ["a", "b"])
        end

        @testset "quantity:+, required" begin
            options = (Positional("file", "files"; quantity='+'),)
            @test_throws CliOptionError parse_args(options, String[])
            args = parse_args(options, ["a"])
            @test args.file == ["a"]
            @test args.files == ["a"]
            args = parse_args(options, ["a", "-b"])
            @test args.file == ["a", "-b"]
            @test args.files == ["a", "-b"]
        end

        @testset "quantity:+, omittable" begin
            options = (Positional("file", "files"; quantity='+', default=["foo.txt"]),)
            args = parse_args(options, String[])
            @test args.file == ["foo.txt"]
            @test args.files == ["foo.txt"]
            args = parse_args(options, ["a"])
            @test args.file == ["a"]
            @test args.files == ["a"]
            args = parse_args(options, ["a", "-b"])
            @test args.file == ["a", "-b"]
            @test args.files == ["a", "-b"]
        end
    end
end
