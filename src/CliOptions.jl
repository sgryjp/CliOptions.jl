module CliOptions


"""
    CliOptionError(msg::String)

An error occurred inside `CliOptions` module. Message describing the error is available in
the `msg` field.
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

Note that a group of options represented with `AbstractOptionGroup` is also an
`AbstractOption` so it can be used to construct `CliOptionSpec`.
"""
abstract type AbstractOption end


"""
    AbstractOptionGroup

Abstract type representing a group of command line options. Concrete subtypes are:

- [`OptionGroup`](@ref)
- [`MutexGroup`](@ref)
"""
abstract type AbstractOptionGroup <: AbstractOption end

Base.length(o::AbstractOptionGroup) = length(o.options)

function Base.iterate(o::AbstractOptionGroup)
    1 ≤ length(o.options) ? (o.options[1], 2) : nothing
end

function Base.iterate(o::AbstractOptionGroup, state)
    state ≤ length(o.options) ? (o.options[state], state+1) : nothing
end


"""
    ParseResult()

Dictionary like object holding parsing result of command line options. [`parse_args`](@ref)
function always returns a value of this type. See example of the function.

This type is not exported.
"""
struct ParseResult
    _dict
    _counter

    ParseResult() = new(Dict{String,Any}(),Dict{AbstractOption,Int}())
end

function Base.getindex(result::ParseResult, key)
    k = key isa Symbol ? String(key) : key
    getindex(result._dict, k)
end

function Base.propertynames(result::ParseResult, private = false)
    vcat([:_dict, :_counter], [Symbol(k) for (k, v) ∈ getfield(result, :_dict)])
end

function Base.getproperty(result::ParseResult, name::Symbol)
    if name == :_dict
        return getfield(result, :_dict)
    elseif name == :_counter
        return getfield(result, :_counter)
    else
        return getfield(result, :_dict)[String(name)]
    end
end


"""
    Option([type=String,] primary_name::String, secondary_name::String = "";
           default = nothing, validator = nothing, help = "")

Type representing a command line option whose value is a following argument. Two forms of
option notations are supported:

1. Short form (e.g.: `-n 42`)
   - Starting with a hyphen, one character follows it
   - A following command line argument will be the option's value
2. Long form (e.g.: `--foo-bar`)
   - Starting with two hyphens, hyphen-separated words follow them
   - Value can be specified as one of the two forms below:
     1. `--foo-bar value`; a following command line argument becomes the option's value
     2. `--foo-bar=value`; characters after an equal sign following the option name becomes
        the option's value

An Option can have two names. `primary_name` is typically a short form notation and is also
used to express the option in a usage message or error messages. `secondary_name` is
typically a long form notation and is also used to generate a value name in a usage message.
For example, if names of an option are `-n` and `--foo-bar`, it will appear in a usage
message as `-n FOO_BAR`. If you want to define an option which have only a long form
notation, specify it as `primary_name` and omit `secondary_name`.

If `type` parameter is set, option values will be converted to the type inside `parse_args`
and will be stored in returned `ParseResult`.

`default` parameter controls behavior of `parse_args` when the option is not found in
command line arguments. If `default` is `nothing`, `parse_args` will throw a
`CliOptionError`. If `default` is NOT `nothing`, it will be used as the option's value.
Note that if you want to allow omitting the option but there is no good default value,
consider using `missing` as default value *(NOTE: this `missing` is not "statistically
missing"... isn't there better way?)*.

`validator` is used to check whether a command line argument is acceptable or not. If there
is an argument which is rejected by the given validator, [`parse_args`](@ref) function will
throw a `CliOptionError`. `validator` can be one of:

1. `nothing`
   - No validation will be done; any value will be accepted
2. A list of acceptable values
   - Arguments which matches one of the values will be accepted
   - Any iterable can be used to specify acceptable values
   - Arguments will be converted to the specified type and then compared to each element of
     the list using function `==`
3. A `Regex`
   - Arguments which matches the regular expression will be accepted
   - Pattern matching will be done for unprocessed input string, not type converted one
4. A custom validator function
   - It validates command line arguments one by one
   - It can return a `Bool` which indicates whether a given argument is acceptable or not
   - It also can return a `String` describing why a given command line argument is NOT
     acceptable, or an empty `String` if it is acceptable

If you want an option which does not take a command line argument as its value, see
[`FlagOption`](@ref) and [`CounterOption`](@ref)
"""
struct Option <: AbstractOption
    names::Vector{String}
    T::Type
    validator::Any
    default::Any
    help::String

    function Option(T::Type, primary_name::String, secondary_name::String = "";
                    default = nothing, validator = nothing, help = "")
        names = secondary_name == "" ? [primary_name] : [primary_name, secondary_name]
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
        new([n for n ∈ names], T, validator, default, help)
    end
end

function Option(primary_name::String, secondary_name::String = "";
                default = nothing, validator = nothing, help = "")
    Option(String, primary_name, secondary_name;
           default = default, validator = validator, help = help)
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

    value = _parse(o.T, args[i + 1], args[i])
    _validate(o.T, args[i + 1], value, o.validator, args[i])
    foreach(k -> result._dict[encode(k)] = value, o.names)
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
               negators::Union{String,Vector{String}} = String[],
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

post_parse_action!(result, o::FlagOption) = nothing

function to_usage_tokens(o::FlagOption)
    latter_part = 1 ≤ length(o.negators) ? " | " * o.negators[1] : ""
    ["[" * o.names[1] * latter_part * "]"]
end
function print_description(io::IO, o::FlagOption)
    print_description(io, o.names, "", o.help)
    print_description(io, o.negators, "", o.negator_help)
end


"""
    CounterOption([type=Int,] short_name::String, long_name::String = "";
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
    T::Type
    help::String
    decrementer_help::String

    function CounterOption(T::Type, short_name::String, long_name::String = "";
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
        if !(T <: Signed)
            throw(ArgumentError("Type of a CounterOption must be a subtype of Signed:" *
                                " \"$T\""))
        end
        if decrementer_help == ""
            decrementer_help = "Opposite of " * names[1] * " option"
        end
        new([n for n ∈ names], [n for n ∈ decrementers], T(default), T, help,
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
    foreach(k -> result._dict[encode(k)] = o.T(o.default), o.names)
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
    value = o.T(get(result._dict, encode(o.names[1]), 0) + diff)

    # Update counter
    count::Int = get(result._counter, o, -1)
    result._counter[o] = count + 1

    # Construct parsed values
    foreach(k -> result._dict[encode(k)] = value, o.names)
    i + 1
end

post_parse_action!(result, o::CounterOption) = nothing

function to_usage_tokens(o::CounterOption)
    latter_part = 1 ≤ length(o.decrementers) ? " | " * o.decrementers[1] : ""
    ["[" * o.names[1] * latter_part * "]"]
end
function print_description(io::IO, o::CounterOption)
    print_description(io, o.names, "", o.help)
    print_description(io, o.decrementers, "", o.decrementer_help)
end


"""
    Positional([type=String,] singular_name, plural_name = "";
               multiple = false, validator = nothing,
               default = nothing, help = "")

`Positional` represents a command line argument which are not an option name nor an option
value.

`validator` is used to check whether a command line argument is acceptable or not. See
[Option](@ref) for more detail.
"""
struct Positional <: AbstractOption
    names::Vector{String}
    T::Type
    multiple::Bool
    validator::Any
    default::Any
    help::String

    function Positional(T::Type, singular_name, plural_name = "";
                        multiple = false,
                        validator = nothing,
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
            return new([singular_name], T, multiple, validator, default, help)
        else
            return new([singular_name, plural_name], T, multiple, validator, default, help)
        end
    end
end

function Positional(singular_name, plural_name = "";
                    multiple = false,
                    validator = nothing,
                    default::Any = nothing,
                    help::String = "")
    Positional(String, singular_name, plural_name;
               multiple = multiple, validator = validator, default = default, help = help)
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
        values = [_parse(o.T, a) for a in args[i:end]]
        for (v, arg) in zip(values, args[i:end])
            _validate(o.T, arg, v, o.validator)
        end
        foreach(k -> result._dict[encode(k)] = values, o.names)
        return i + length(values)
    else
        value = _parse(o.T, args[i])
        _validate(o.T, args[i], value, o.validator)
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
one of the options is accepted. In other word, this is an OR operator for `AbstractOption`s.
"""
struct OptionGroup <: AbstractOptionGroup
    names::Tuple{String}
    options

    OptionGroup(name::String, options::AbstractOption...) = new((name,), options)
end

function set_default!(result::ParseResult, o::OptionGroup)
    foreach(o -> set_default!(result, o), o.options)
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

function post_parse_action!(result, o::OptionGroup)
    for option in o.options
        post_parse_action!(result, option)
    end
end

function to_usage_tokens(o::OptionGroup)
    tokens = Vector{String}()
    for option in o.options
        append!(tokens, to_usage_tokens(option))
    end
    tokens
end

function print_description(io::IO, o::OptionGroup)
    if o.names[1] != ""
        println(io, "  " * o.names[1] * ":")
    end
    for option in o.options
        print_description(io, option)
    end
end


"""
    MutexGroup(name::String, options::AbstractOption...)

`MutexGroup` contains one or more `AbstractOption`s and accepts command line arguments only
if exactly one of the options was accepted.
"""
struct MutexGroup <: AbstractOptionGroup
    name::String
    options

    MutexGroup(name::String, options::AbstractOption...) = new(name, options)
end

function set_default!(result::ParseResult, o::MutexGroup)  # Same as from OptionGroup
    foreach(o -> set_default!(result, o), o.options)
end

function consume!(result::ParseResult, o::MutexGroup, args, i)  # Same as from OptionGroup
    for option in o.options
        next_index = consume!(result, option, args, i)
        if 0 < next_index
            return next_index
        end
    end
    return -1
end

function post_parse_action!(result, o::MutexGroup)
    exceptions = Vector{Exception}()
    for option in o.options
        try
            post_parse_action!(result, option)
        catch ex
            push!(exceptions, ex)
        end
    end
    if length(o.options) - length(exceptions) != 1
        buf = IOBuffer()
        print(buf, "Exactly one of ")
        print(buf, join([x.names[1] for x in o.options], ", ", " or "))
        print(buf, " must be specified")
        msg = String(take!(buf))
        throw(CliOptionError(msg))
    end
end

function to_usage_tokens(o::MutexGroup)
    tokens = Vector{String}()
    append!(tokens, to_usage_tokens(o.options[1]))
    for option in o.options[2:end]
        push!(tokens, "|")
        append!(tokens, to_usage_tokens(option))
    end
    tokens[1] = "{" * tokens[1]
    tokens[end] = tokens[end] * "}"
    tokens
end

function print_description(io::IO, o::MutexGroup)  # Same as from OptionGroup
    if o.name != ""
        println(io, "  " * o.name * ":")
    end
    for option in o.options
        print_description(io, option)
    end
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
                push!(arguments, kv[1], kv[2])  # --foo-bar=baz
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
        post_parse_action!(result, option)
    end

    result
end

# Internals
encode(s) = replace(replace(s, r"^(--|-|/)" => ""), r"[^0-9a-zA-Z]" => "_")
is_option(names) = any([startswith(name, '-') && 2 ≤ length(name) for name ∈ names])

function _parse(T, optval::String, optname = "")
    try
        # Use `parse` if available, or use constructor of the type
        if applicable(parse, T, optval)
            return parse(T, optval)
        else
            return T(optval)
        end
    catch exc
        # Generate message expressing the error encountered
        if :msg in fieldnames(typeof(exc))
            reason = exc.msg
        else
            buf = IOBuffer()
            print(buf, exc)
            reason = String(take!(buf))
        end

        # Throw exception with formatted message
        buf = IOBuffer()
        print(buf, "Unparsable ")
        print(buf, optname == "" ? "positional argument" : "value for $optname")
        print(buf, " of type $T: ")
        print(buf, "\"$optval\" ($reason)")
        msg = String(take!(buf))
        throw(CliOptionError(msg))
    end
end

function _validate(T, optval::String, parsed_value::Any, validator, optname = "")
    # Validate the parsed result
    reason = ""
    if validator isa Function
        rv = validator(parsed_value)
        if rv == false || (rv isa String && rv != "")
            reason = rv isa Bool ? "validation failed" : rv
        end
    elseif validator isa Regex
        if match(validator, optval) === nothing
            reason = "must match for $(validator)"
        end
    elseif validator !== nothing
        if !any(x == parsed_value for x in validator)
            reason = "must be one of " * join([isa(s, Regex) ? "$s" : "\"$s\""
                                               for s in validator],
                                              ", ", " or ")
        end
    end

    # Throw if validation failed
    if reason != ""
        buf = IOBuffer()
        print(buf, "Invalid ")
        print(buf, "value for $optname")  #TODO: in case of positional argument
        print(buf, T == String ? ": " : " of type $T: ")
        print(buf, "\"$optval\" ($reason)")
        msg = String(take!(buf))
        throw(CliOptionError(msg))
    end
end
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


export CliOptionSpec,
       Option,
       FlagOption,
       CounterOption,
       Positional,
       OptionGroup,
       MutexGroup,
       parse_args,
       CliOptionError

end # module
