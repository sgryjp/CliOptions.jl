using CliOptions


# An utility which executes a command line for many times
spec = CliOptionSpec(
    Option(Int, "-n", "--times"; default = 1,
           help = "Number of times to execute the command"),
    RemainderOption(help = "Command line arguments to execute"),
    HelpOption(),
)
args = parse_args(spec)
for _ in 1:args.times
    cmd = Cmd(String[a for a in args._remainders])
    run(cmd)
end
