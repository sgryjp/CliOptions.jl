using Test
using CliOptions

@testset "parse_args()" begin
    options = (
        make_option("-n", "--num-workers"),
        make_option("filename"),
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
