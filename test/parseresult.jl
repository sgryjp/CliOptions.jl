using Test
using CliOptions

include("testutils.jl")


@testset "ParseResult" begin
    let result = CliOptions.ParseResult(Dict("foo" => "FOO", "bar" => "BAR"))

        @testset "show(::ParseResult)" begin
            @test repr(result) == "CliOptions.ParseResult(:bar,:foo)"
        end

        @testset "getindex; Symbol" begin
            @test result[:foo] == "FOO"
            @test result[:bar] == "BAR"
        end

        @testset "getindex; String" begin
            @test result["foo"] == "FOO"
            @test result["bar"] == "BAR"
        end

        @testset "propertynames" begin
            props = propertynames(result)
            @test sort(props) == [:bar, :foo]
            props = propertynames(result; private = true)
            @test sort(props) == [:_argvals, :_defaults, :_errors, :_resolved, :bar, :foo]
        end

        @testset "getproperty" begin
            @test getproperty(result, :_defaults) isa Dict
            @test getproperty(result, :_argvals) isa Dict
            @test getproperty(result, :_resolved) isa Dict
            @test getproperty(result, :_errors) isa Vector
            @test getproperty(result, :foo) == "FOO"
            @test getproperty(result, :bar) == "BAR"
        end
    end

    @testset "update_defaults(); \"$(v[1])\", $(v[2])" for v in [
        (Dict{String,Any}("n" => 9, "c" => 7, "f" => true, "p" => "bar"),
            "",
            (9, 7, true, "bar")),
        (Dict{String,Any}("n" => 9, "c" => 7, "f" => false, "p" => "bar"),
            "-n 4 -c -f foo",
            (4, 8, true, "foo")),
        (Dict{String,Any}(),
            "-n 4 -c -f foo",
            (4, 1, true, "foo")),
        (Dict{String,Any}(),
            "",
            (0, 0, false, "qux")),
    ]
        defaults, args, expected = v
        spec = CliOptionSpec(
            Option(Int8, "-n"; default = 0),
            CounterOption("-c"),
            FlagOption("-f"),
            Positional("p", default = "qux"),
            onerror = error,
        )
        options = parse_args(spec, split(args))
        options = update_defaults(options, defaults)
        @test options.n == expected[1]
        @test options.c == expected[2]
        @test options.f == expected[3]
        @test options.p == expected[4]
    end
end
