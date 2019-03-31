using Test
using CliOptions
using CliOptions: consume!

@testset "Positional()" begin
    @testset "ctor" begin
        @test_throws ArgumentError Positional("")
        @test_throws ArgumentError Positional("-a")
        @test_throws ArgumentError Positional("a", "-b")
        @test_throws ArgumentError Positional("-a", "-b"; quantity='_')

        option = Positional("a")
        @test option.names == ["a"]
        @test option.quantity == '1'

        option = Positional("a", "b")
        @test option.names == ["a", "b"]
        @test option.quantity == '1'

        option = Positional("a", quantity='+')
        @test option.names == ["a"]
        @test option.quantity == '+'
    end

    @testset "consume(::Positional)" begin
        @testset "empty args" begin
            option = Positional("file")
            ctx = Dict{AbstractOption,Int}()
            @test_throws AssertionError consume!(ctx, option, Vector{String}(), 1)
        end

        @testset "quantity:1" begin
            test_cases = [
                ("file", "",      [""],   1, (2, ("file" => "",))),
                ("file", "",      ["-d"], 1, (2, ("file" => "-d",))),
                ("file", "files", ["-d"], 1, (2, ("file" => "-d", "files" => "-d"))),
            ]
            for (singular, plural, args, index, expected) in test_cases
                option = Positional(singular, plural)
                ctx = Dict{AbstractOption,Int}()
                if expected isa Type && expected <: Exception
                    @test_throws expected consume!(ctx, option, args, index)
                else
                    @test consume!(ctx, option, args, index) == expected
                end
            end
        end

        @testset "quantity:+" begin
            test_cases = [
                ("file", "",      [""],       1, (2, ("file" => [""],))),
                ("file", "",      ["a"],      1, (2, ("file" => ["a"],))),
                ("file", "files", ["a", "b"], 1, (3, ("file" => ["a", "b"],
                                                      "files" => ["a", "b"]))),
            ]
            for (singular, plural, args, index, expected) in test_cases
                option = Positional(singular, plural; quantity='+')
                ctx = Dict{AbstractOption,Int}()
                if expected isa Type && expected <: Exception
                    @test_throws expected consume!(ctx, option, args, index)
                else
                    @test consume!(ctx, option, args, index) == expected
                end
            end
        end
    end
end
