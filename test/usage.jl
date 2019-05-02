using Test
using CliOptions

@testset "println()" begin
    @testset "Option" begin
        spec = CliOptionSpec(
            Option("-f", "--foo-bar", help = "an option here."),
            Option("-p", help = "another option here."),
            program = ""
        )

        @test spec.usage == "Usage: PROGRAM -f FOO_BAR -p P"

        buf = IOBuffer()
        print(buf, spec)
        usage_message = String(take!(buf))
        @test usage_message == """
                               Usage: PROGRAM -f FOO_BAR -p P

                               Options:
                                   -f, --foo-bar FOO_BAR
                                               an option here.

                                   -p P        another option here.

                               """
    end

    @testset "OptionGroup" begin
        spec = CliOptionSpec(
            Option("-w", "--window-function", help = "window function to use"),
            OptionGroup(
                Option("-x", help = "explanatory variables"),
                Option("-y", help = "objective variable"),
                name = "Input data",
            ),
            Option("-t", help = "dtype (float or int)"),
            program = ""
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
