using Test
using CliOptions

@testset "ParseResult" begin
    let result = CliOptions.ParseResult()
        result._dict["foo"] = "FOO"
        result._dict["bar"] = "BAR"

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
            @test sort(props) == [:_defaults, :_dict, :bar, :foo]
        end

        @testset "getproperty" begin
            @test getproperty(result, :_dict) !== nothing
            @test getproperty(result, :foo) == "FOO"
            @test getproperty(result, :bar) == "BAR"
        end
    end
end
