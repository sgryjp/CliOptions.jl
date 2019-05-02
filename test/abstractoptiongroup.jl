using Test
using CliOptions

@testset "AbstractOptionGroup()" begin
    option0 = OptionGroup()
    option1 = OptionGroup(Option("-a"))
    option2 = OptionGroup(Option("-a"), Option("-b"))
    @testset "length(::OptionGroup)" begin
        @test length(option0) == 0
        @test length(option1) == 1
        @test length(option2) == 2
    end
    @testset "iterate(::OptionGroup)" begin
        @test [o.names[1] for o in option0] == String[]
        @test [o.names[1] for o in option1] == String["-a"]
        @test [o.names[1] for o in option2] == String["-a", "-b"]
    end

    option0 = MutexGroup()
    option1 = MutexGroup(Option("-a"))
    option2 = MutexGroup(Option("-a"), Option("-b"))
    @testset "length(::MutexGroup)" begin
        @test length(option0) == 0
        @test length(option1) == 1
        @test length(option2) == 2
    end
    @testset "iterate(::MutexGroup)" begin
        @test [o.names[1] for o in option0] == String[]
        @test [o.names[1] for o in option1] == String["-a"]
        @test [o.names[1] for o in option2] == String["-a", "-b"]
    end
end
