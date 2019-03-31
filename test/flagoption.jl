using Test
using CliOptions
using CliOptions: consume!

@testset "FlagOption()" begin
    @testset "ctor" begin
        @test_throws ArgumentError FlagOption()
        @test_throws ArgumentError FlagOption("")
        @test_throws ArgumentError FlagOption("a")
        @test_throws ArgumentError FlagOption("-")
        @test_throws ArgumentError FlagOption("--")
        @test_throws ArgumentError FlagOption("-a"; negators=[""])
        @test_throws ArgumentError FlagOption("-a"; negators=["a"])
        @test_throws ArgumentError FlagOption("-a"; negators=["-"])
        @test_throws ArgumentError FlagOption("-a"; negators=["--"])
        option = FlagOption("-a")
        @test option.names == ["-a"]
        @test option.negators == String[]
        option = FlagOption("-a", "-b", negators=["-c", "-d"])
        @test option.names == ["-a", "-b"]
        @test option.negators == ["-c", "-d"]
    end

    @testset "consume(::FlagOption)" begin
        option = FlagOption("-i", "--ignore-case")

        let ctx = Dict{AbstractOption,Int}()
            @test_throws AssertionError consume!(ctx, option, String[], 1)
        end
        let ctx = Dict{AbstractOption,Int}()
            # Splitting optchars are done by parse_args()
            @test_throws AssertionError consume!(ctx, option, ["-ab"], 1)
        end
        let ctx = Dict{AbstractOption,Int}()
            next_index, pairs = consume!(ctx, option, ["foo"], 1)
            @test next_index == -1
            @test pairs == nothing
        end
        let ctx = Dict{AbstractOption,Int}()
            next_index, pairs = consume!(ctx, option, ["-i"], 1)
            @test next_index == 2
            @test pairs == ("i" => true, "ignore_case" => true)
        end
        let ctx = Dict{AbstractOption,Int}()
            next_index, pairs = consume!(ctx, option, ["--ignore-case"], 1)
            @test next_index == 2
            @test pairs == ("i" => true, "ignore_case" => true)
        end
    end

    @testset "consume(::FlagOption); negators" begin
        option = FlagOption("-i", negators=["-c", "--case-sensitive"])

        let ctx = Dict{AbstractOption,Int}()
            @test_throws AssertionError consume!(ctx, option, String[], 1)
        end
        let ctx = Dict{AbstractOption,Int}()
            # Splitting optchars are done by parse_args()
            @test_throws AssertionError consume!(ctx, option, ["-ab"], 1)
        end
        let ctx = Dict{AbstractOption,Int}()
            next_index, pairs = consume!(ctx, option, ["foo"], 1)
            @test next_index == -1
            @test pairs == nothing
        end
        let ctx = Dict{AbstractOption,Int}()
            next_index, pairs = consume!(ctx, option, ["-i"], 1)
            @test next_index == 2
            @test pairs == ("i" => true, "c" => false, "case_sensitive" => false)
        end
        let ctx = Dict{AbstractOption,Int}()
            next_index, pairs = consume!(ctx, option, ["-c"], 1)
            @test next_index == 2
            @test pairs == ("i" => false, "c" => true, "case_sensitive" => true)
        end
        let ctx = Dict{AbstractOption,Int}()
            next_index, pairs = consume!(ctx, option, ["--case-sensitive"], 1)
            @test next_index == 2
            @test pairs == ("i" => false, "c" => true, "case_sensitive" => true)
        end
    end
end
