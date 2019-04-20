using Test
using CliOptions

@testset "println()" begin
    @testset "NamedOption" begin
        spec = CliOptionSpec(
            NamedOption("-f", "--foo-buzz", help = "an option here."),
            NamedOption("-p", help = "another option here."),
        )

        @test spec.usage == "Usage: PROGRAM -f FOO_BUZZ -p P"

        buf = IOBuffer()
        print(buf, spec)
        usage_message = String(take!(buf))
        @test usage_message == """
                               Usage: PROGRAM -f FOO_BUZZ -p P

                               Options:
                                   -f, --foo-buzz FOO_BUZZ
                                               an option here.

                                   -p P        another option here.

                               """
    end

    @testset "OptionGroup" begin
        spec = CliOptionSpec(
            NamedOption("-w", "--window-function", help = "window function to use"),
            OptionGroup(
                "Input data",
                NamedOption("-x", help = "explanatory variables"),
                NamedOption("-y", help = "objective variable"),
            ),
            NamedOption("-t", help = "dtype (float or int)"),
        )

        @test spec.usage == "Usage: PROGRAM -w WINDOW_FUNCTION -x X -y Y -t T"

        buf = IOBuffer()
        print(buf, spec)
        usage_message = String(take!(buf))
        @test usage_message == """
                               Usage: PROGRAM -w WINDOW_FUNCTION -x X -y Y -t T

                               Options:
                                   -w, --window-function WINDOW_FUNCTION
                                               window function to use

                                 Input data:
                                   -x X        explanatory variables

                                   -y Y        objective variable

                                   -t T        dtype (float or int)

                               """
    end
end
