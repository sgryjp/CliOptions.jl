module CliOptions


"""
    CliOptionError

An error occurred inside CliOptions module. Detailed error message can be retrieved by `msg`
field.
"""
struct CliOptionError <: Exception
    msg::String
end

Base.showerror(io::IO, e::CliOptionError) = print(io, "CliOptionError: " * e.msg)


"""
    AbstractOption

Abstract supertype representing a command line option. Concrete subtypes are:

- [`Option`](@ref) ... an option which takes a following argument as its value
- [`FlagOption`](@ref) ... an option of which existence becomes its boolean value
- [`CounterOption`](@ref) ... an option of which number of usage becomes its integer value
- [`Positional`](@ref) ... an argument which is not an option

Note that a group of options represented with `AbstractOptionGroup` is also considered as
an `AbstractOption` so it can be used to construct `CliOptionSpec`.
"""
abstract type AbstractOption end


"""
    AbstractOptionGroup

Abstract type representing a group of command line options. Concrete subtypes are:

- [`OptionGroup`](@ref)
"""
abstract type AbstractOptionGroup <: AbstractOption end


"""
    ParseResult

Dict-like object holding parsing result of command line options.
"""
struct ParseResult
    _dict
    _counter

    ParseResult() = new(Dict{String,Any}(),Dict{AbstractOption,Int}())
end

function Base.getindex(args::ParseResult, key)
    k = key isa Symbol ? String(key) : key
    getindex(args._dict, k)
end

function Base.propertynames(args::ParseResult, private = false)
    vcat([:_dict], [Symbol(k) for (k, v) ∈ getfield(args, :_dict)])
end

function Base.getproperty(args::ParseResult, name::String)
    Base.getproperty(args::ParseResult, Symbol(name))
end

function Base.getproperty(args::ParseResult, name::Symbol)
    if name == :_dict
        return getfield(args, :_dict)
    elseif name == :_counter
        return getfield(args, :_counter)
    else
        return getfield(args, :_dict)[String(name)]
    end
end


"""
    Option([type::Type], short_name::String, long_name::String = "";
           default = nothing, help = "")

Type representing a command line option whose value is a following argument. An option
appears in a format like `-a buzz`, `--foo-bar buzz` or `--foo-bar=buzz`.
"""
struct Option <: AbstractOption
    names::Vector{String}
    type::Type
    default::Any
    help::String

    function Option(type::Type, short_name::String, long_name::String = "";
                    default = nothing, help = "")
        if !applicable(type, "") && !applicable(parse, type, "")
            throw(ArgumentError("Type of an Option must be constructible or" *
                                " `parse`able from a String: $(type)"))
        end
        names = long_name == "" ? [short_name] : [short_name, long_name]
        for name ∈ names
            if "" == name
                throw(ArgumentError("Name of an Option must not be empty"))
            elseif name[1] != '-'
                throw(ArgumentError("Name of an Option must start with a hyphen: " *
                                    name))
            elseif match(r"^-[^-]", name) === nothing && match(r"^--[^-]", name) === nothing
                throw(ArgumentError("Invalid name for Option: \"$name\""))
            end
        end
        new([n for n ∈ names], type, default, help)
    end
end

function Option(short_name::String, long_name::String = ""; default = nothing, help = "")
    Option(String, short_name, long_name; default = default, help = help)
end

function set_default!(result::ParseResult, o::Option)
    result._counter[o] = 0
end

function consume!(result::ParseResult, o::Option, args, i)
    @assert 1 ≤ i ≤ length(args)
    if args[i] ∉ o.names
        return -1
    end
    if length(args) < i + 1
        throw(CliOptionError("A value is needed for option \"$(args[i])\""))
    end

    # Get how many times this option was evaluated
    count::Int = get(result._counter, o, -1)
    if count == -1
        result._counter[o] = 0
    end

    # Skip if this node is already processed
    if 1 ≤ count
        return -1
    end
    result._counter[o] += 1

    function cvt(x)
        try
            if applicable(o.type, "")
                return o.type(x)
            elseif applicable(parse, o.type, "")
                return parse(o.type, x)
            else
                throw(AssertionError("THIS LINE MUST NOT BE EXECUTED"))
            end
        catch exc
            throw(CliOptionError(exc.msg))
        end
    end
    foreach(k -> result._dict[encode(k)] = cvt(args[i + 1]), o.names)
    i + 2
end

function post_parse_action!(result, o::Option)
    # Do nothing if once parsed
    if 1 ≤ get(result._counter, o, 0)
        return
    end

    # Apply deafult value or throw error if no default is set
    if o.default !== nothing
        foreach(k -> result._dict[encode(k)] = o.default, o.names)
    else
        msg = "Option \"$(o.names[1])\" must be specified"
        throw(CliOptionError(msg))
    end
end

_optval(o::Option) = uppercase(encode(2 ≤ length(o.names) ? o.names[2] : o.names[1]))
function to_usage_tokens(o::Option)
    tokens = [o.names[1] * " " * _optval(o)]
    if o.default !== nothing
        tokens[1] = "[" * tokens[1]
        tokens[end] = tokens[end] * "]"
    end
    tokens
end
function print_description(io::IO, o::Option)
    print_description(io, o.names, _optval(o), o.help)
end


"""
    FlagOption(short_name::String, long_name::String = "";
               negators::Union{String,Vector{String}} = "",
               help = "",
               negator_help = "")

`FlagOption` represents a so-called "flag" command line option. An option of this type takes
no value and whether it was specified becomes a boolean value.
"""
struct FlagOption <: AbstractOption
    names::Vector{String}
    negators::Vector{String}
    help::String
    negator_help::String

    function FlagOption(short_name::String, long_name::String = "";
                        negators::Union{String,Vector{String}} = String[],
                        help = "", negator_help = "")
        names = long_name == "" ? [short_name] : [short_name, long_name]
        if negators isa String
            negators = [negators]
        end
        for name in unique(vcat(collect(names), negators))
            if name == ""
                throw(ArgumentError("Name of a FlagOption must not be empty"))
            elseif name[1] != '-'
                throw(ArgumentError("Name of a FlagOption must start with a hyphen:" *
                                    " \"$name\""))
            elseif match(r"^-[^-]", name) === nothing && match(r"^--[^-]", name) === nothing
                throw(ArgumentError("Invalid name for FlagOption: \"$name\""))
            end
        end
        if negator_help == ""
            negator_help = "Negate usage of " * names[1] * " option"
        end
        new([n for n ∈ names], [n for n ∈ negators], help, negator_help)
    end
end

function set_default!(result::ParseResult, o::FlagOption)
    result._counter[o] = 0
    foreach(k -> result._dict[encode(k)] = false, o.names)
    foreach(k -> result._dict[encode(k)] = true, o.negators)
end

function consume!(result::ParseResult, o::FlagOption, args, i)
    @assert 1 ≤ i ≤ length(args)

    if startswith(args[i], "--")
        if args[i] ∈ o.names
            value = true
        elseif args[i] ∈ o.negators
            value = false
        else
            return -1
        end
    elseif startswith(args[i], "-")
        @assert length(args[i]) == 2  # Splitting -abc to -a, -b, -c is done by parse_args()
        if args[i] ∈ o.names
            value = true
        elseif args[i] ∈ o.negators
            value = false
        else
            return -1
        end
    else
        return -1
    end

    # Update counter
    count::Int = get(result._counter, o, -1)
    result._counter[o] = count + 1

    # Construct parsed values
    foreach(k -> result._dict[encode(k)] = value, o.names)
    foreach(k -> result._dict[encode(k)] = !value, o.negators)
    i + 1
end

function to_usage_tokens(o::FlagOption)
    latter_part = 1 ≤ length(o.negators) ? " | " * o.negators[1] : ""
    ["[" * o.names[1] * latter_part * "]"]
end
function print_description(io::IO, o::FlagOption)
    print_description(io, o.names, "", o.help)
    print_description(io, o.negators, "", o.negator_help)
end


"""
    CounterOption([type::Type], short_name::String, long_name::String = "";
                  decrementers::Union{String,Vector{String}} = String[],
                  default::Signed = 0,
                  help::String = "",
                  decrementer_help = "")

A type represents a flag-like command line option. Total number of times a `CounterOption`
was specified becomes the option's value.
"""
struct CounterOption <: AbstractOption
    names::Vector{String}
    decrementers::Vector{String}
    default::Signed
    type::Type
    help::String
    decrementer_help::String

    function CounterOption(type::Type, short_name::String, long_name::String = "";
                           decrementers::Union{String,Vector{String}} = String[],
                           default::Signed = 0,
                           help::String = "",
                           decrementer_help::String = "")
        names = long_name == "" ? [short_name] : [short_name, long_name]
        if decrementers isa String
            decrementers = [decrementers]
        end
        for name in unique(vcat(collect(names), decrementers))
            if name == ""
                throw(ArgumentError("Name of a CounterOption must not be empty"))
            elseif name[1] != '-'
                throw(ArgumentError("Name of a CounterOption must start with a hyphen:" *
                                    " \"$name\""))
            elseif match(r"^-[^-]", name) === nothing && match(r"^--[^-]", name) === nothing
                throw(ArgumentError("Invalid name for CounterOption: \"$name\""))
            end
        end
        if !(type <: Signed)
            throw(ArgumentError("Type of a CounterOption must be a subtype of Signed:" *
                                " \"$type\""))
        end
        if decrementer_help == ""
            decrementer_help = "Opposite of " * names[1] * " option"
        end
        new([n for n ∈ names], [n for n ∈ decrementers], type(default), type, help,
            decrementer_help)
    end
end
function CounterOption(short_name::String, long_name::String = "";
                       decrementers::Union{String,Vector{String}} = String[],
                       default::Signed = 0,
                       help::String = "",
                       decrementer_help::String = "")
    CounterOption(Int, short_name, long_name;
                  decrementers = decrementers, default = default, help = help,
                  decrementer_help = decrementer_help)
end

function set_default!(result::ParseResult, o::CounterOption)
    result._counter[o] = 0
    foreach(k -> result._dict[encode(k)] = o.type(o.default), o.names)
end

function consume!(result::ParseResult, o::CounterOption, args, i)
    @assert 1 ≤ i ≤ length(args)

    diff = 0
    if startswith(args[i], "--")
        if args[i] ∈ o.names
            diff = +1
        elseif args[i] ∈ o.decrementers
            diff = -1
        end
    elseif startswith(args[i], "-")
        @assert length(args[i]) == 2  # Splitting -abc to -a, -b, -c is done by parse_args()
        if args[i] ∈ o.names
            diff = +1
        elseif args[i] ∈ o.decrementers
            diff = -1
        end
    end
    if diff == 0
        return -1
    end
    value = o.type(get(result._dict, encode(o.names[1]), 0) + diff)

    # Update counter
    count::Int = get(result._counter, o, -1)
    result._counter[o] = count + 1

    # Construct parsed values
    foreach(k -> result._dict[encode(k)] = value, o.names)
    i + 1
end

function to_usage_tokens(o::CounterOption)
    latter_part = 1 ≤ length(o.decrementers) ? " | " * o.decrementers[1] : ""
    ["[" * o.names[1] * latter_part * "]"]
end
function print_description(io::IO, o::CounterOption)
    print_description(io, o.names, "", o.help)
    print_description(io, o.decrementers, "", o.decrementer_help)
end


"""
    Positional(singular_name, plural_name = "";
               multiple = false,
               default = nothing)

`Positional` represents a command line argument which are not an option name nor an option
value.
"""
struct Positional <: AbstractOption
    names::Vector{String}
    multiple::Bool
    default::Any
    help::String

    function Positional(singular_name, plural_name = "";
                        multiple = false,
                        default::Any = nothing,
                        help::String = "")
        if singular_name == ""
            throw(ArgumentError("Name of a Positional must not be empty"))
        elseif startswith(singular_name, '-')
            throw(ArgumentError("Name of a Positional must not start with a hyphen: " *
                                singular_name))
        elseif startswith(plural_name, '-')
            throw(ArgumentError("Name of a Positional must not start with a hyphen: " *
                                plural_name))
        end

        if plural_name == ""
            return new([singular_name], multiple, default, help)
        else
            return new([singular_name, plural_name], multiple, default, help)
        end
    end
end

function set_default!(result::ParseResult, o::Positional)
    # Do nothing
end

function consume!(result::ParseResult, o::Positional, args, i)
    @assert 1 ≤ i ≤ length(args)
    @assert "" ∉ o.names

    # Skip if this node is already processed
    count::Int = get(result._counter, o, 0)
    max_nvalues = o.multiple ? Inf : 1
    if max_nvalues ≤ count
        return -1
    end
    result._counter[o] = count + 1

    # Determine value and update result
    if o.multiple
        values = args[i:end]
        foreach(k -> result._dict[encode(k)] = values, o.names)
        return i + length(values)
    else
        value = args[i]
        foreach(k -> result._dict[encode(k)] = value, o.names)
        return i + 1
    end
end

function post_parse_action!(result, o::Positional)
    # Do nothing if once parsed
    if 1 ≤ get(result._counter, o, 0)
        return
    end

    # Apply deafult value or throw error if no default is set
    if o.default === nothing
        msg = "\"$(o.names[1])\" must be specified"
        throw(CliOptionError(msg))
    else
        foreach(k -> result._dict[encode(k)] = o.default, o.names)
    end
end

function to_usage_tokens(o::Positional)
    name = uppercase(o.names[1])
    if o.multiple
        [name * " [" * name * "...]"]
    else
        [name]
    end
end
function print_description(io::IO, o::Positional)
    print_description(io, [uppercase(n) for n in o.names[1:1]], "", o.help)
end


"""
    OptionGroup(name::String, options::AbstractOption...)

`OptionGroup` contains one or more `AbstractOption`s and accepts command line arguments if
it sees one of the options. In other word, this is an OR operator for `AbstractOption`s.
"""
struct OptionGroup <: AbstractOptionGroup
    name::String
    options

    OptionGroup(name::String, options::AbstractOption...) = new(name, options)
end

function set_default!(result::ParseResult, o::OptionGroup)
    foreach(o -> set_default!(result._dict, o), o.options)
end

function consume!(result::ParseResult, o::OptionGroup, args, i)
    for option in o.options
        next_index = consume!(result, option, args, i)
        if 0 < next_index
            return next_index
        end
    end
    return -1
end

function to_usage_tokens(o::OptionGroup)
    tokens = Vector{String}()
    for option in o.options
        append!(tokens, to_usage_tokens(option))
    end
    tokens
end

function print_description(io::IO, o::OptionGroup)
    if o.name != ""
        println(io, "  " * o.name * ":")
    end
    for option in o.options
        print_description(io, option)
    end
end

function Base.iterate(o::OptionGroup)
    1 ≤ length(o.options) ? (o.options[1], 2) : nothing
end

function Base.iterate(o::OptionGroup, state)
    state ≤ length(o.options) ? (o.options[state], state+1) : nothing
end


"""
    CliOptionSpec(options::AbstractOption...; program = PROGRAM_FILE)

A type representing a command line option specification.
"""
struct CliOptionSpec
    root::OptionGroup
    usage::String

    function CliOptionSpec(options::AbstractOption...; program = PROGRAM_FILE)
        if program == ""
            program = "PROGRAM"
        end
        usage = "Usage: " * program * " " * join(Iterators.flatten(to_usage_tokens(o)
                                                                   for o in options),
                                                 " ")
        new(OptionGroup("", options...), usage)
    end
end


"""
    show([io::IO], spec::CliOptionSpec)

Write fully descriptive usage (help) message to `io`. If you want to print only the first
line of the usage message, print `CliOptionSpec.usage` instead.
"""
function Base.show(io::IO, spec::CliOptionSpec)
    println(io, spec.usage)
    println(io)
    println(io, "Options:")
    print_description(io, spec.root)
end
Base.show(spec::CliOptionSpec) = show(stdout, spec)


"""
    parse_args(spec::CliOptionSpec, args = ARGS)

Parse `args` according to the `spec`.

`spec` is an instance of [`CliOptionSpec`](@ref) which defines how to parse command line
arguments. It is constructed with one or more concrete subtypes of
[`AbstractOption`](@ref)s. See document of `AbstractOption` for full list of its subtypes.

`args` is the command line arguments to be parsed. If omitted, `Base.ARGS` – the command
line arguments passed to the Julia script – will be parsed.

This function returns a [`ParseResult`](@ref) after parsing. It is basically a Dict-like
object holding the values of options.

```jldoctest
using CliOptions

spec = CliOptionSpec(
    Option(Int, "-n", "--num-workers"),
    FlagOption("-i", "--ignore-case"; negators = "--case-sensitive"),
    Positional("root"),
    Positional("pattern", "patterns"; multiple = true);
    program = "myfind"
)

args = parse_args(spec, split("-n 3 -i /var/log *.log", " "))
println("num_workers: ", args.num_workers)
println("ignore_case: ", args.ignore_case)
println("root: ", args.root)
println("patterns: ", args.patterns)

# output

num_workers: 3
ignore_case: true
root: /var/log
patterns: ["*.log"]
```
"""
function parse_args(spec::CliOptionSpec, args = ARGS)
    result = ParseResult()

    # Reparsing argument list
    arguments = String[]
    for i = 1:length(args)
        if !startswith(args[i], '-')
            push!(arguments, args[i])  # -a
        elseif startswith(args[i], "--")
            kv = split(args[i], '=')
            if length(kv) == 1
                push!(arguments, args[i])  # --foo-bar
            elseif length(kv) == 2
                push!(arguments, kv[1], kv[2])  # --foo-bar=buzz
            else
                throw(CliOptionError("Unrecognizable option string: \"$(args[i])\""))
            end
        elseif startswith(args[i], '-')
            append!(arguments, ["-$c" for c ∈ args[i][2:end]])  # -abc ==> -a -b -c
        end
    end

    # Setup default values
    foreach(o -> set_default!(result, o), spec.root)

    # Parse arguments
    i = 1
    while i ≤ length(arguments)
        next_index = consume!(result, spec.root, arguments, i)
        if next_index < 0
            throw(CliOptionError("Unrecognized argument: \"$(arguments[i])\""))
        end

        i = next_index
    end

    # Take care of omitted options
    for option ∈ (o for o in spec.root.options if get(result._counter, o, 0) ≤ 0)
        if applicable(post_parse_action!, result, option)
            post_parse_action!(result, option)
        end
    end

    result
end

# Internals
encode(s) = replace(replace(s, r"^(--|-|/)" => ""), r"[^0-9a-zA-Z]" => "_")
is_option(names) = any([startswith(name, '-') && 2 ≤ length(name) for name ∈ names])
function print_description(io, names, val, help)
    heading = join(names, ", ") * (val != "" ? " $val" : "")
    print(io, repeat(" ", 4) * heading)
    if 16 ≤ length(heading) + 4
        println(io)
        println(io, repeat(" ", 16) * help)
    else
        println(io, repeat(" ", 16 - 4 - length(heading)) * help)
    end
    println(io)
end


export AbstractOption,
       CliOptionError,
       CliOptionSpec,
       CounterOption,
       FlagOption,
       Option,
       OptionGroup,
       Positional,
       parse_args

end # module
