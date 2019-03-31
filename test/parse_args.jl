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
end
