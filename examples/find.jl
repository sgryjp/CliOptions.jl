using CliOptions


# A utility which searches for files of which name matches a given pattern and optionally
# invoke a command line for each of them

spec = CliOptionSpec(
    HelpOption(),
    Option("-x", "--exec"; default = nothing, until = ";",
           help = "Execute command for each found file."),
    Positional("starting-point"; default = ".",
               help = "Root of directory tree to execute recursive file search."),
)
options = parse_args(spec)

# Recursively search for matching files
for (rootpath, dirs, files) in walkdir(options.starting_point)
    for fn in files
        path = joinpath(rootpath, fn)
        if options.exec === nothing
            println(path)
        else
            commandline = copy(options.exec)
            push!(commandline, path)
            run(Cmd(commandline))
        end
    end
end
