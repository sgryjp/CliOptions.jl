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
            let ctx = Dict{AbstractOption,Int}()
                option = Positional("file")
                next_index, pairs = consume!(ctx, option, [""], 1)
                @test next_index == 2
                @test pairs == ("file" => "",)
            end
            let ctx = Dict{AbstractOption,Int}()
                option = Positional("file")
                next_index, pairs = consume!(ctx, option, ["-d"], 1)
                @test next_index == 2
                @test pairs == ("file" => "-d",)
            end
            let ctx = Dict{AbstractOption,Int}()
                option = Positional("file", "files")
                next_index, pairs = consume!(ctx, option, ["-d"], 1)
                @test next_index == 2
                @test pairs == ("file" => "-d", "files" => "-d")
            end
        end

        @testset "quantity:+" begin
            let ctx = Dict{AbstractOption,Int}()
                option = Positional("file", quantity='+')
                next_index, pairs = consume!(ctx, option, [""], 1)
                @test next_index == 2
                @test pairs == ("file" => [""],)
            end
            let ctx = Dict{AbstractOption,Int}()
                option = Positional("file", "files", quantity='+')
                next_index, pairs = consume!(ctx, option, ["a"], 1)
                @test next_index == 2
                @test pairs == ("file" => ["a"], "files" => ["a"])
            end
            let ctx = Dict{AbstractOption,Int}()
                option = Positional("file", quantity='+')
                next_index, pairs = consume!(ctx, option, ["a", "b"], 1)
                @test next_index == 3
                @test pairs == ("file" => ["a", "b"],)
            end
        end
    end
end
