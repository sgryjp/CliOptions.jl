using Test
using CliOptions: encode, is_option

@testset "Internal utilities" begin

    @testset "is_option()" begin
        @test is_option(["a"]) == false
        @test is_option(["-a"]) == true
        @test is_option(["-"]) == false
        @test is_option([""]) == false
    end

    @testset "encoding()" begin
        @test encode("f") == "f"
        @test encode("-f") == "f"
        @test encode("/f") == "f"
        @test encode("--f") == "f"
        @test encode("--foo-bar") == "foo_bar"
        @test encode("-foo bar") == "foo_bar"
    end

end
