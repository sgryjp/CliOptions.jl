using Test
using CliOptions


@testset "CliOptionSpec" begin
    @testset "ctor(); program = $(repr(v[1]))" for v in [
        ("", "PROGRAM"),
        ("a", "a"),
    ]
        program, expected = v
        spec = CliOptionSpec(
            FlagOption("-a"),
            program = program,
            onerror = error,
        )
        @test spec.program == expected
    end

    @testset "show(io, x)" begin
        let spec = CliOptionSpec(
            FlagOption("-a"),
            CounterOption("-b"),
            Option("-c"),
            Positional("d"),
            onerror = error,
        )
            buf = IOBuffer()
            show(buf, spec)
            @test String(take!(buf)) == "CliOptionSpec(" * join([
                "FlagOption(:a)",
                "CounterOption(:b)",
                "Option(:c)",
                "Positional(:d)",
            ], ',') * ")"
        end
    end

    @testset "show(io, x)" begin
        let spec = CliOptionSpec(
            FlagOption("-a"),
            CounterOption("-b"),
            Option("-c"),
            Positional("d"),
            onerror = error,
        )
            buf = IOBuffer()
            redirect_stdout(buf) do
                show(spec)
            end
            @test String(take!(buf)) == "CliOptionSpec(" * join([
                "FlagOption(:a)",
                "CounterOption(:b)",
                "Option(:c)",
                "Positional(:d)",
            ], ',') * ")"
        end
    end
end
