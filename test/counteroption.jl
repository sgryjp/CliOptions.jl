using Test
using CliOptions

@testset "CounterOption()" begin
    @testset "ctor" begin
        @test_throws ArgumentError CounterOption()
        @test_throws ArgumentError CounterOption("")
        @test_throws ArgumentError CounterOption("a")
        @test_throws ArgumentError CounterOption("-")
        @test_throws ArgumentError CounterOption("--")
        @test_throws ArgumentError CounterOption("-a"; decrementers = [""])
        @test_throws ArgumentError CounterOption("-a"; decrementers = ["a"])
        @test_throws ArgumentError CounterOption("-a"; decrementers = ["-"])
        @test_throws ArgumentError CounterOption("-a"; decrementers = ["--"])
        #@test_throws ArgumentError CounterOption("-a"; decrementers = ["-a"])  #TODO
        option = CounterOption("-a")
        @test option.super.names == ["-a"]
        @test option.super.negators == String[]
        option = CounterOption("-a", "-b", decrementers = ["-c", "-d"])
        @test option.super.names == ["-a", "-b"]
        @test option.super.negators == ["-c", "-d"]
    end

    @testset "consume(::CounterOption)" begin
        option = CounterOption("-v", "--verbose")

        let ctx = Dict{AbstractOption,Int}()
            @test_throws AssertionError CliOptions.consume!(ctx, option, String[], 1)
        end
        let ctx = Dict{AbstractOption,Int}()
            # Splitting optchars are done by parse_args()
            @test_throws AssertionError CliOptions.consume!(ctx, option, ["-wv"], 1)
        end
        let ctx = Dict{AbstractOption,Int}()
            next_index, pairs = CliOptions.consume!(ctx, option, ["v"], 1)
            @test next_index == -1
            @test pairs === nothing
        end
        let ctx = Dict{AbstractOption,Int}()
            next_index, pairs = CliOptions.consume!(ctx, option, ["-v"], 1)
            @test next_index == 2
            @test pairs == ("v" => :incr__, "verbose" => :incr__)
        end
        let ctx = Dict{AbstractOption,Int}()
            next_index, pairs = CliOptions.consume!(ctx, option, ["--verbose"], 1)
            @test next_index == 2
            @test pairs == ("v" => :incr__, "verbose" => :incr__)
        end
    end

    @testset "consume(::CounterOption); decrementers" begin
        option = CounterOption("-v", decrementers = ["-q", "--quiet"])

        let ctx = Dict{AbstractOption,Int}()
            @test_throws AssertionError CliOptions.consume!(ctx, option, String[], 1)
        end
        let ctx = Dict{AbstractOption,Int}()
            # Splitting optchars are done by parse_args()
            @test_throws AssertionError CliOptions.consume!(ctx, option, ["-wv"], 1)
        end
        let ctx = Dict{AbstractOption,Int}()
            next_index, pairs = CliOptions.consume!(ctx, option, ["v"], 1)
            @test next_index == -1
            @test pairs === nothing
        end
        let ctx = Dict{AbstractOption,Int}()
            next_index, pairs = CliOptions.consume!(ctx, option, ["-v"], 1)
            @test next_index == 2
            @test pairs == ("v" => :incr__, "q" => :decr__, "quiet" => :decr__)
        end
        let ctx = Dict{AbstractOption,Int}()
            next_index, pairs = CliOptions.consume!(ctx, option, ["-q"], 1)
            @test next_index == 2
            @test pairs == ("v" => :decr__, "q" => :incr__, "quiet" => :incr__)
        end
        let ctx = Dict{AbstractOption,Int}()
            next_index, pairs = CliOptions.consume!(ctx, option, ["--quiet"], 1)
            @test next_index == 2
            @test pairs == ("v" => :decr__, "q" => :incr__, "quiet" => :incr__)
        end
    end
end
