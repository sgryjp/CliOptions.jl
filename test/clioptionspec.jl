using Test
using CliOptions


@testset "CliOptionSpec" begin
    @testset "show(::CliOptionSpec)" begin
        spec = CliOptionSpec(
            FlagOption("-a"),
            CounterOption("-b"),
            Option("-c"),
            Positional("d"),
        )
        @test repr(spec) == join(["CliOptionSpec(",
                                  "FlagOption(:a),",
                                  "CounterOption(:b),",
                                  "Option(:c),",
                                  "Positional(:d)",
                                  ")"])
    end
end
