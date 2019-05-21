using Test
using CliOptions

@testset "print_usage()" begin
    @testset "example 1" begin
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
        buf = IOBuffer()
        print_usage(buf, spec; verbose = false)
        usage = String(take!(buf))
        @test usage == """Usage: PROGRAM -w WINDOW_FUNCTION -x X -y Y -t T
                       """

        buf = IOBuffer()
        print_usage(buf, spec; verbose = true)
        usage = String(take!(buf))
        # print(usage)  # DEBUG
        @test usage == """
                       Usage: PROGRAM -w WINDOW_FUNCTION -x X -y Y -t T

                       Options:
                           -w, --window-function WINDOW_FUNCTION
                                                  window function to use

                         Input data:
                           -x X                   explanatory variables

                           -y Y                   objective variable

                           -t T                   dtype (float or int)

                       """
    end
end
