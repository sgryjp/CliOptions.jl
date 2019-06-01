using CliOptions


# An utility which executes a command line for many times
spec = CliOptionSpec(
    Option(Int, "-n", "--times"; default = 1,
           help = "Number of times to execute the command"),
    Positional("arguments"; multiple = true,
               help = "Command line arguments to execute"),
    HelpOption(),
    use_double_dash = true,
)
options = parse_args(spec)
for _ in 1:options.times
    cmd = Cmd(String[a for a in options.arguments])
    run(cmd)
end
