using Test
using CliOptions

include("testutils.jl")


@testset "AbstractOptionGroup()" begin
    @testset "show(::OptionGroup); $(join(v[1],','))" for v in [
        (["-a"], "OptionGroup(Option(:a))"),
        (["-a", "-b"], "OptionGroup(Option(:a),Option(:b))"),
    ]
        names, expected_repr = v
        result = CliOptions.ParseResult()
        option = OptionGroup([Option(name) for name in names]...)
        @test repr(option) == expected_repr
    end

    @testset "show(::MutexGroup); $(join(v[1],','))" for v in [
        (["-a"], "MutexGroup(Option(:a))"),
        (["-a", "-b"], "MutexGroup(Option(:a),Option(:b))"),
    ]
        names, expected_repr = v
        result = CliOptions.ParseResult()
        option = MutexGroup([Option(name) for name in names]...)
        @test repr(option) == expected_repr
    end

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
