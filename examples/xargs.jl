using CliOptions


spec = CliOptionSpec(
    HelpOption(),
    # FlagOption("-0", "--null";
    #            help = "Use NUL character as delimiter."),
    Positional("command"; default = "echo",
               help = "The command to execute for each items."),
    Positional("arguments"; default = String[], multiple = true,
               help = "The arguments to be passed to the commands."),
    use_double_dash = true,
)
options = parse_args(spec)

for line in eachline(stdin)
    cmd = Cmd([options.command, options.arguments..., line])
    run(cmd)
end
