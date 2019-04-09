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

Abstract supertype representing a command line option. Concrete subtypes of this are:

- [`NamedOption`](@ref) ... a command line option
- [`Positional`](@ref) ... a command line argument which isn't a `NamedOption`
- [`OptionGroup`](@ref)
"""
abstract type AbstractOption end


"""
    AbstractOptionGroup

Abstract type representing a group of command line options. Each command line option belongs
to a group is `AbstractOption`, and `AbstractOptionGroup` itself is also an
`AbstractOption`.

There are 1 defined subtype:

- OptionGroup
"""
abstract type AbstractOptionGroup <: AbstractOption end


"""
    ParsedArguments

Dict-like object holding parsing result of command line options.
"""
struct ParsedArguments
    _dict
    _counter

    ParsedArguments() = new(Dict{String,Any}(),Dict{AbstractOption,Int}())
end

function Base.getindex(args::ParsedArguments, key)
    k = key isa Symbol ? String(key) : key
    getindex(args._dict, k)
end

function Base.propertynames(args::ParsedArguments, private = false)
    vcat([:_dict], [Symbol(k) for (k, v) ∈ getfield(args, :_dict)])
end

function Base.getproperty(args::ParsedArguments, name::String)
    Base.getproperty(args::ParsedArguments, Symbol(name))
end

function Base.getproperty(args::ParsedArguments, name::Symbol)
    if name == :_dict
        return getfield(args, :_dict)
    elseif name == :_counter
        return getfield(args, :_counter)
    else
        return getfield(args, :_dict)[String(name)]
    end
end


"""
    NamedOption(names::String...)

`NamedOption` represents the most basic command option type. Typycally, a named option
appears in a format like  `-a b`, `--option-name value` or `--option-name=value`.
"""
struct NamedOption <: AbstractOption
    names::Vector{String}
    help::String

    function NamedOption(names::String...; help="")
        if length(names) == 0
            throw(ArgumentError("At least one name for a NamedOption must be specified"))
        end
        for name ∈ names
            if "" == name
                throw(ArgumentError("Name of a NamedOption must not be empty"))
            elseif name[1] != '-'
                throw(ArgumentError("Name of a NamedOption must start with a hyphen: " *
                                    name))
            end
        end
        new([n for n ∈ names], help)
    end
end

function set_default!(result::ParsedArguments, o::NamedOption)
    result._counter[o] = 0
end

function consume!(result::ParsedArguments, o::NamedOption, args, i)
    @assert 1 ≤ i ≤ length(args)
    if args[i] ∉ o.names
        return -1
    end
    if length(args) < i + 1
        throw(CliOptionError("A value is needed for option `" * args[i] * "`"))
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

    foreach(k -> result._dict[encode(k)] = args[i + 1], o.names)
    i + 2
end

friendly_name(o::NamedOption) = "option"
primary_name(o::NamedOption) = o.names[1]
function to_usage_tokens(o::NamedOption)
    [o.names[1] * " " * uppercase(encode(2 ≤ length(o.names) ? o.names[2] : o.names[1]))]
end
function print_description(io::IO, o::NamedOption)
    heading = join(o.names, ", ")
    print(io, repeat(" ", 4) * heading)
    if 16 ≤ length(heading) + 4
        println(io)
        print(io, repeat(" ", 16) * o.help)
    else
        print(io, repeat(" ", 16 - 4 - length(heading)) * o.help)
    end
    println(io)
end


"""
    FlagOption

`FlagOption` represents a so-called "flag" command line option. An option of this type takes
no value and whether it was specified becomes a boolean value.
"""
struct FlagOption <: AbstractOption
    names::Vector{String}
    negators::Vector{String}

    function FlagOption(names::String...; negators::Vector{String} = String[])
        if length(names) == 0
            throw(ArgumentError("At least one name for a FlagOption must be specified"))
        end
        for name in unique(vcat(collect(names), negators))
            if match(r"^-[^-]", name) === nothing && match(r"^--[^-]", name) === nothing
                if name == ""
                    throw(ArgumentError("Name of a FlagOption must not be empty"))
                elseif match(r"^[^-]", name) !== nothing
                    throw(ArgumentError("Name of a FlagOption must start with a hyphen: " *
                                        name))
                else
                    throw(ArgumentError("Invalid name for FlagOption: " * name))
                end
            end
        end
        new([n for n ∈ names], [n for n ∈ negators])
    end
end

function set_default!(result::ParsedArguments, o::FlagOption)
    result._counter[o] = 0
    foreach(k -> result._dict[encode(k)] = false, o.names)
    foreach(k -> result._dict[encode(k)] = true, o.negators)
end

function consume!(result::ParsedArguments, o::FlagOption, args, i)
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

friendly_name(o::FlagOption) = "flag option"
primary_name(o::FlagOption) = o.names[1]
function to_usage_tokens(o::FlagOption)
    latter_part = 1 ≤ length(o.negators) ? " | " * o.negators[1] : ""
    ["[" * o.names[1] * latter_part * "]"]
end
function print_description(io::IO, o::FlagOption)
    @assert false  #TODO
end


"""
    Positional

`Positional` represents a command line argument which are not an option name nor an option
value.
"""
struct Positional <: AbstractOption
    names::Vector{String}
    multiple::Bool
    default::Any

    function Positional(singular_name, plural_name = "";
                        multiple = false,
                        default::Any = nothing)
        if singular_name == ""
            throw(ArgumentError("Name of a Positional must not be empty"))
        end
        if startswith(singular_name, '-')
            throw(ArgumentError("Name of a Positional must not start with a hyphen: " *
                                singular_name))
        end
        if startswith(plural_name, '-')
            throw(ArgumentError("Name of a Positional must not start with a hyphen: " *
                                plural_name))
        end

        if plural_name == ""
            return new([singular_name], multiple, default)
        else
            return new([singular_name, plural_name], multiple, default)
        end
    end
end

function set_default!(result::ParsedArguments, o::Positional)
    result._counter[o] = 0
    foreach(k -> result._dict[encode(k)] = o.default, o.names)
end

function consume!(result::ParsedArguments, o::Positional, args, i)
    @assert 1 ≤ i ≤ length(args)
    @assert "" ∉ o.names

    # Skip if this node is already processed
    count::Int = get(result._counter, o, -1)
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

friendly_name(o::Positional) = "positional argument"
primary_name(o::Positional) = o.names[1]
function to_usage_tokens(o::Positional)
    name = uppercase(o.names[1])
    if o.multiple
        [name * " [" * name * "...]"]
    else
        [name]
    end
end
function print_description(io::IO, o::Positional)
    @assert false  #TODO
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

function set_default!(result::ParsedArguments, o::OptionGroup)
    foreach(o -> set_default!(result._dict, o), o.options)
end

function consume!(result::ParsedArguments, o::OptionGroup, args, i)
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
        println(io)
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
    program::String

    function CliOptionSpec(options::AbstractOption...; program = PROGRAM_FILE)
        if program == ""
            program = "PROGRAM"
        end
        new(OptionGroup("", options...), program)
    end
end


"""
    print_usage([io::IO], spec::CliOptionSpec; verbose = false)

Write to `io` a usage (help) message for the command line specification.
If `verbose` is true, not only the usage message but also long description will be written.
"""
function print_usage(io::IO, spec::CliOptionSpec; verbose = false)
    tokens = []
    for option in spec.root
        push!(tokens, to_usage_tokens(option)...)
    end

    println(io, "Usage: " * spec.program * " " * join(tokens, " "))
    if verbose
        println(io)
        println(io, "Options:")
        print_description(io, spec.root)
    end
end

function print_usage(spec::CliOptionSpec)
    print_usage(stdout, spec)
end


"""
    parse_args(spec::CliOptionSpec, args=ARGS)

Parse command line options according to `spec`.

`args` is the command line arguments to be parsed. If omitted, this function parses
`Base.ARGS` which is an array of command line arguments passed to the Julia script.
"""
function parse_args(spec::CliOptionSpec, args = ARGS)
    result = ParsedArguments()

    # Setup default values
    foreach(o -> set_default!(result, o), spec.root)

    # Parse arguments
    i = 1
    while i ≤ length(args)
        next_index = consume!(result, spec.root, args, i)
        if next_index < 0
            throw(CliOptionError("Unrecognized argument: " * args[i]))
        end

        i = next_index
    end

    # Take care of omitted options  #TODO: Improve contron flow
    for option ∈ spec.root.options
        if option isa Positional
            if get(result._counter, option, 0) ≤ 0 && option.default === nothing
                msg = "A " * friendly_name(option) *
                        " \"" * primary_name(option) * "\" was not specified"
                throw(CliOptionError(msg))
            end
        end
    end

    result
end

# Internals
encode(s) = replace(replace(s, r"^(--|-|/)" => ""), r"[^0-9a-zA-Z]" => "_")
is_option(names) = any([startswith(name, '-') && 2 ≤ length(name) for name ∈ names])


export AbstractOption,
       CliOptionError,
       CliOptionSpec,
       FlagOption,
       NamedOption,
       OptionGroup,
       Positional,
       parse_args,
       print_usage

end # module
