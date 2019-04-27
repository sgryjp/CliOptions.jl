using Test
using CliOptions

@testset "ParseResult" begin
    let result = CliOptions.ParseResult()
        result._dict["foo"] = "FOO"
        result._dict["bar"] = "BAR"
        @testset "getindex; Symbol" begin
            @test result[:foo] == "FOO"
            @test result[:bar] == "BAR"
        end
        @testset "getindex; String" begin
            @test result["foo"] == "FOO"
            @test result["bar"] == "BAR"
        end
        @testset "propertynames" begin
            @test sort(propertynames(result)) == [:_counter, :_dict, :bar, :foo]
        end
        @testset "getproperty" begin
            @test getproperty(result, :_dict) !== nothing
            @test getproperty(result, :_counter) !== nothing
            @test getproperty(result, :foo) == "FOO"
            @test getproperty(result, :bar) == "BAR"
        end
    end
end
