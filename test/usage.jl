using Test
using CliOptions

@testset "print_usage()" begin
    @testset "NamedOption" begin
        buf = IOBuffer()
        spec = CliOptionSpec(
            NamedOption("-f", "--foo-buzz", help = "an option here."),
            NamedOption("-p", help = "another option here."),
        )

        print_usage(buf, spec)
        usage_message = String(take!(buf))
        @test usage_message == """
                               Usage: PROGRAM -f FOO_BUZZ -p P
                               """

        print_usage(buf, spec; verbose = true)
        usage_message = String(take!(buf))
        @test usage_message == """
                               Usage: PROGRAM -f FOO_BUZZ -p P

                               Options:
                                   -f, --foo-buzz
                                               an option here.
                                   -p          another option here.
                               """
    end

    @testset "OptionGroup" begin
        buf = IOBuffer()
        spec = CliOptionSpec(
            NamedOption("-w", "--window-function", help = "window function to use"),
            OptionGroup(
                "Input data",
                NamedOption("-x", help = "explanatory variables"),
                NamedOption("-y", help = "objective variable"),
            ),
            NamedOption("-t", help = "dtype (float or int)"),
        )

        print_usage(buf, spec)
        usage_message = String(take!(buf))
        @test usage_message == """
                               Usage: PROGRAM -w WINDOW_FUNCTION -x X -y Y -t T
                               """

        print_usage(buf, spec; verbose = true)
        usage_message = String(take!(buf))
        @test usage_message == """
                               Usage: PROGRAM -w WINDOW_FUNCTION -x X -y Y -t T

                               Options:
                                   -w, --window-function
                                               window function to use

                                 Input data:
                                   -x          explanatory variables
                                   -y          objective variable
                                   -t          dtype (float or int)
                               """
    end
end
