module CliOptions


StringOrStrings = Union{String,Tuple{Vararg{String}},Vector{String}}

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
    CliOptions.AbstractOption

Abstract supertype representing a command line option. Concrete subtypes are:

- [`Option`](@ref) ... an option which takes a following argument as its value
- [`FlagOption`](@ref) ... an option of which existence becomes its boolean value
- [`CounterOption`](@ref) ... an option of which number of usage becomes its integer value
- [`Positional`](@ref) ... an argument which is not an option

Note that a group of options represented with `AbstractOptionGroup` is also an
`AbstractOption` so it can be used to construct `CliOptionSpec`.
"""
abstract type AbstractOption end

function Base.show(io::IO, x::AbstractOption)
    print(io, typeof(x), "(", join([":" * encode(name) for name in x.names], ','), ")")
end
Base.show(x::AbstractOption) = show(stdout, x)


"""
    CliOptions.AbstractOptionGroup

Abstract type representing a group of command line options. Concrete subtypes are:

- [`OptionGroup`](@ref)
- [`MutexGroup`](@ref)
"""
abstract type AbstractOptionGroup <: AbstractOption end

function Base.show(io::IO, x::AbstractOptionGroup)
    print(io, typeof(x), "(", join([repr(o) for o in x], ','), ")")
end
Base.show(x::AbstractOptionGroup) = show(stdout, x)

Base.length(o::AbstractOptionGroup) = length(o.options)

function Base.iterate(o::AbstractOptionGroup)
    1 ≤ length(o.options) ? (o.options[1], 2) : nothing
end

function Base.iterate(o::AbstractOptionGroup, state)
    state ≤ length(o.options) ? (o.options[state], state + 1) : nothing
end


"""
    CliOptions.ParseResult()

Dictionary like object holding parsing result of command line options. [`parse_args`](@ref)
function always returns a value of this type. See example of the function.

This type is not exported.
"""
struct ParseResult
    _dict

    ParseResult() = new(Dict{String,Any}())
end

function Base.show(io::IO, x::ParseResult)
    print(io, typeof(x), "(", join([":$k" for k in sort(collect(keys(x._dict)))], ','), ")")
end
Base.show(x::ParseResult) = show(stdout, x)

function Base.getindex(result::ParseResult, key)
    k = key isa Symbol ? String(key) : key
    getindex(result._dict, k)
end

function Base.propertynames(result::ParseResult; private = false)
    props = [Symbol(k) for (k, v) in getfield(result, :_dict)]
    if private
        push!(props, :_dict)
    end
    sort!(props)
end

function Base.getproperty(result::ParseResult, name::Symbol)
    if name == :_dict
        return getfield(result, :_dict)
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
    names::Union{Tuple{String},Tuple{String,String}}
    T::Type
    validator::Any
    default::Any
    help::String

    function Option(T::Type, primary_name::String, secondary_name::String = "";
                    default::Any = nothing, validator::Any = nothing, help::String = "")
        names = secondary_name == "" ? (primary_name,) : (primary_name, secondary_name)
        _validate_option_names(Option, names)
        new(names, T, validator, default, help)
    end
end

function Option(primary_name::String, secondary_name::String = "";
                default::Any = nothing, validator::Any = nothing, help::String = "")
    Option(String, primary_name, secondary_name;
           default = default, validator = validator, help = help)
end

function set_default!(d::Dict{String,Any}, o::Option)
    for name in o.names
        d[encode(name)] = o.default
    end
end

function consume!(d::Dict{String,Any}, o::Option, args, i, ctx)
    @assert 1 ≤ i ≤ length(args)
    @assert "" ∉ o.names
    @assert all(o isa AbstractOption for o in ctx.all_options)

    if args[i] ∉ o.names
        return 0
    end
    if length(args) < i + 1
        throw(CliOptionError("A value is needed for option \"$(args[i])\""))
    end

    # Update counter
    ctx.usage_count[o] = get(ctx.usage_count, o, 0) + 1

    value = _parse(o.T, args[i + 1], o.validator, args[i])
    for name in o.names
        d[encode(name)] = value
    end
    i + 2
end

function check_usage_count(o::Option, ctx)
    # Throw if it's required but was omitted
    if o.default === nothing && get(ctx.usage_count, o, 0) ≤ 0
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
    FlagOption(primary_name::String, secondary_name::String = "";
               negators::Union{String,Vector{String}} = String[],
               help = "",
               negator_help = "")

`FlagOption` represents a so-called "flag" command line option. An option of this type takes
no value and whether it was specified becomes a boolean value.
"""
struct FlagOption <: AbstractOption
    names::Union{Tuple{String},Tuple{String,String}}
    negators::Vector{String}
    help::String
    negator_help::String

    function FlagOption(primary_name::String, secondary_name::String = "";
                        negators::Union{String,Vector{String}} = String[],
                        help = "", negator_help = "")
        names = secondary_name == "" ? (primary_name,) : (primary_name, secondary_name)
        if negators isa String
            negators = [negators]
        end
        _validate_option_names(FlagOption, names)
        _validate_option_names(FlagOption, negators; allow_nameless = true)
        if negator_help == ""
            negator_help = "Negate usage of " * names[1] * " option"
        end
        new(names, [n for n ∈ negators], help, negator_help)
    end
end

function set_default!(d::Dict{String,Any}, o::FlagOption)
    for name in o.names
        d[encode(name)] = false
    end
    for name in o.negators
        d[encode(name)] = true
    end
end

function consume!(d::Dict{String,Any}, o::FlagOption, args, i, ctx)
    @assert 1 ≤ i ≤ length(args)
    @assert "" ∉ o.names
    @assert all(o isa AbstractOption for o in ctx.all_options)

    if startswith(args[i], "--")
        if args[i] ∈ o.names
            value = true
        elseif args[i] ∈ o.negators
            value = false
        else
            return 0
        end
    elseif startswith(args[i], "-")
        @assert length(args[i]) == 2  # Splitting -abc to -a, -b, -c is done by parse_args()
        if args[i] ∈ o.names
            value = true
        elseif args[i] ∈ o.negators
            value = false
        else
            return 0
        end
    else
        return 0
    end

    # Update counter
    count::Int = get!(ctx.usage_count, o, 0)
    ctx.usage_count[o] = count + 1

    # Construct parsed values
    for name in o.names
        d[encode(name)] = value
    end
    for name in o.negators
        d[encode(name)] = !value
    end
    i + 1
end

check_usage_count(o::FlagOption, ctx) = nothing

function to_usage_tokens(o::FlagOption)
    latter_part = 1 ≤ length(o.negators) ? " | " * o.negators[1] : ""
    ["[" * o.names[1] * latter_part * "]"]
end
function print_description(io::IO, o::FlagOption)
    print_description(io, o.names, "", o.help)
    if 1 ≤ length(o.negators)
        print_description(io, o.negators, "", o.negator_help)
    end
end


"""
    CounterOption([type=Int,] primary_name::String, secondary_name::String = "";
                  decrementers::Union{String,Vector{String}} = String[],
                  default::Signed = 0,
                  help::String = "",
                  decrementer_help = "")

A type represents a flag-like command line option. Total number of times a `CounterOption`
was specified becomes the option's value.
"""
struct CounterOption <: AbstractOption
    names::Union{Tuple{String},Tuple{String,String}}
    decrementers::Vector{String}
    default::Signed
    T::Type
    help::String
    decrementer_help::String

    function CounterOption(T::Type, primary_name::String, secondary_name::String = "";
                           decrementers::Union{String,Vector{String}} = String[],
                           default::Signed = 0,
                           help::String = "",
                           decrementer_help::String = "")
        names = secondary_name == "" ? (primary_name,) : (primary_name, secondary_name)
        if decrementers isa String
            decrementers = [decrementers]
        end
        _validate_option_names(CounterOption, names)
        _validate_option_names(CounterOption, decrementers; allow_nameless = true)
        if !(T <: Signed)
            throw(ArgumentError("Type of a CounterOption must be a subtype of Signed:" *
                                " \"$T\""))
        end
        if decrementer_help == ""
            decrementer_help = "Opposite of " * names[1] * " option"
        end
        new(names, [n for n ∈ decrementers], T(default), T, help, decrementer_help)
    end
end

function CounterOption(primary_name::String, secondary_name::String = "";
                       decrementers::Union{String,Vector{String}} = String[],
                       default::Signed = 0,
                       help::String = "",
                       decrementer_help::String = "")
    CounterOption(Int, primary_name, secondary_name;
                  decrementers = decrementers, default = default, help = help,
                  decrementer_help = decrementer_help)
end

function set_default!(d::Dict{String,Any}, o::CounterOption)
    for name in o.names
        d[encode(name)] = o.T(o.default)
    end
end

function consume!(d::Dict{String,Any}, o::CounterOption, args, i, ctx)
    @assert 1 ≤ i ≤ length(args)
    @assert "" ∉ o.names
    @assert all(o isa AbstractOption for o in ctx.all_options)

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
        return 0
    end
    value = o.T(get(d, encode(o.names[1]), 0) + diff)

    # Update counter
    ctx.usage_count[o] = get(ctx.usage_count, o, 0) + 1

    # Construct parsed values
    for name in o.names
        d[encode(name)] = value
    end
    i + 1
end

check_usage_count(o::CounterOption, ctx) = nothing

function to_usage_tokens(o::CounterOption)
    latter_part = 1 ≤ length(o.decrementers) ? " | " * o.decrementers[1] : ""
    ["[" * o.names[1] * latter_part * "]"]
end

function print_description(io::IO, o::CounterOption)
    print_description(io, o.names, "", o.help)
    if 1 ≤ length(o.decrementers)
        print_description(io, o.decrementers, "", o.decrementer_help)
    end
end


"""
    HelpOption(names = ("-h", "--help"); [help::String])

Options for printing help (usage) message.

The default value of `names` are `-h` and `--help`. If you do not like to have `-h` for
printing help message, just give `--help` for `names` parameter (i.e.:
`HelpOption("--help"; ...)`).

The default behavior for a help option is printing help message and exiting. If you do not
like this behavior, use `onhelp` parameter on constructing [`CliOptionSpec`](@ref).
"""
struct HelpOption <: AbstractOption
    names
    flag::FlagOption
    help::String

    function HelpOption(names::String...; help::String = "")
        help = help == "" ? "Show usage message and exit" : help
        if length(names) == 0
            names = ("-h", "--help")
        end
        _validate_option_names(HelpOption, names)  # for error message
        flag = FlagOption(names...; help = help)
        new(flag.names, flag, help)
    end
end

function set_default!(d::Dict{String,Any}, o::HelpOption)
    set_default!(d, o.flag)
end

function consume!(d::Dict{String,Any}, o::HelpOption, args, i, ctx)
    consume!(d, o.flag, args, i, ctx)
end

check_usage_count(o::HelpOption, ctx) = nothing

function to_usage_tokens(o::HelpOption)
    ["[" * o.names[1] * "]"]
end

function print_description(io::IO, o::HelpOption)
    print_description(io, o.names, "", o.help)
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
    names::Union{Tuple{String},Tuple{String,String}}
    T::Type
    multiple::Bool
    validator::Any
    default::Any
    help::String

    function Positional(T::Type,
                        singular_name::String,
                        plural_name::String = "";
                        multiple::Bool = false,
                        validator::Any = nothing,
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
            return new((singular_name,), T, multiple, validator, default, help)
        else
            return new((singular_name, plural_name), T, multiple, validator, default, help)
        end
    end
end

function Positional(singular_name::String,
                    plural_name::String = "";
                    multiple::Bool = false,
                    validator::Any = nothing,
                    default::Any = nothing,
                    help::String = "")
    Positional(String, singular_name, plural_name;
               multiple = multiple, validator = validator, default = default, help = help)
end

function set_default!(d::Dict{String,Any}, o::Positional)
    for name in o.names
        d[encode(name)] = o.default
    end
end

function consume!(d::Dict{String,Any}, o::Positional, args, i, ctx)
    @assert 1 ≤ i ≤ length(args)
    @assert "" ∉ o.names
    @assert all(o isa AbstractOption for o in ctx.all_options)

    # Skip if this node is already processed
    count::Int = get(ctx.usage_count, o, 0)
    max_nvalues = o.multiple ? Inf : 1
    if max_nvalues ≤ count
        return 0
    end
    ctx.usage_count[o] = count + 1

    # Scan values to consume
    values = Vector{o.T}()
    for arg in args[i:(o.multiple ? length(args) : i)]
        token_type = _check_option_name(arg)
        if token_type == :valid
            break  # Do not consume an argument which looks like an option
        elseif token_type == :negative
            if any(name == arg for opt in ctx.all_options for name in opt.names)
                break  # Do not consume an option which looks like a negative number
            end
        end
        push!(values, _parse(o.T, arg, o.validator))
    end
    if length(values) == 0
        return 0  # No arguments consumable
    end

    # Store parse result
    for name in o.names
        d[encode(name)] = o.multiple ? values : values[1]
    end

    return i + length(values)
end

function check_usage_count(o::Positional, ctx)
    # Throw if it's required but was omitted
    if o.default === nothing && get(ctx.usage_count, o, 0) ≤ 0
        msg = "\"$(o.names[1])\" must be specified"
        throw(CliOptionError(msg))
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
    print_description(io, (uppercase(o.names[1]),), "", o.help)
end

function Base.show(io::IO, x::Positional)
    print(io, typeof(x), "(", join([":$name" for name in x.names], ','), ")")
end
Base.show(x::Positional) = show(stdout, x)


"""
    RemainderOption(primary_name = "--"[, secondary_name];
                    [help::String])

An option type which takes all the following arguments as its value. It is similar to
`Positional` with `multiple` parameter is set `true`, but `RemainderOption` never stop
taking following arguments, even if there is an argument looking like an option.

The default name of a `RemainderOption` is `--` but any valid option name such as `-x` or
`--exec` can be assigned. Note that using `--` is tricky since it also has special meaning
for `julia` command itself. To give `--` to a program, we need to use `--` before program
file name (see the example below.)

Typical usage of this type is to create a utility command which executes another command.

#### Example: A command which executes another command for multiple times

```julia
# examples/execmany.jl
using CliOptions

spec = CliOptionSpec(
    Option(Int, "-n", "--times"; default = 1,
           help = "Number of times to execute the command"),
    RemainderOption(help = "Command line arguments to execute"),
)
args = parse_args(spec)
for _ in 1:args.times
    cmd = Cmd(String[a for a in args._remainders])
    run(cmd)
end
```

Example usage of this command:

```shell
\$ julia -- examples/execmany.jl -n 3 -- julia --version
julia version 1.0.3
julia version 1.0.3
julia version 1.0.3
```
"""
struct RemainderOption <: AbstractOption
    names::Union{Tuple{AbstractString},Tuple{AbstractString,AbstractString}}
    help::String

    function RemainderOption(primary_name::AbstractString = "--",
                             secondary_name::AbstractString = "";
                             help::String = "Take all arguments following after")
        names = secondary_name == "" ? (primary_name,) : (primary_name, secondary_name)
        _validate_option_names(RemainderOption, names)
        new(names, help)
    end
end

function set_default!(d::Dict{String,Any}, o::RemainderOption)
    for name in o.names
        key = encode(name == "--" ? "--_remainders" : name)
        d[key] = AbstractString[]
    end
end

function consume!(d::Dict{String,Any}, o::RemainderOption, args, i, ctx)
    @assert 1 ≤ i ≤ length(args)
    @assert "" ∉ o.names
    @assert all(o isa AbstractOption for o in ctx.all_options)

    # Skip if name does not match
    if args[i] ∉ o.names
        return 0
    end

    # Parse arguments
    values = AbstractString[]
    for arg in args[i + 1:end]
        push!(values, arg)
    end
    for name in o.names
        key = encode(name == "--" ? "--_remainders" : name)
        d[key] = values
    end

    # Update counter
    ctx.usage_count[o] = get(ctx.usage_count, o, 0) + 1

    return length(args) + 1
end

check_usage_count(o::RemainderOption, ctx) = nothing

function to_usage_tokens(o::RemainderOption)
    ["[$(uppercase(o.names[1])) ARGUMENT [ARGUMENT...]]"]
end

function print_description(io::IO, o::RemainderOption)
    print_description(io, o.names, "", o.help)
end

function Base.show(io::IO, x::RemainderOption)
    print(io, "RemainderOption(")
    print(io, join([":" * encode(name == "--" ? "--_remainders" : name)
                    for name in x.names],
                   ','))
    print(io, ")")
end


"""
    OptionGroup(options::AbstractOption...; name::String = "")

`OptionGroup` contains one or more `AbstractOption`s and accepts command line arguments if
one of the options is accepted. In other word, this is an OR operator for `AbstractOption`s.
"""
struct OptionGroup <: AbstractOptionGroup
    names::Tuple{String}
    options

    OptionGroup(options::AbstractOption...; name::String = "") = new((name,), options)
end

function set_default!(d::Dict{String,Any}, o::OptionGroup)
    for option in o.options
        set_default!(d, option)
    end
end

function consume!(d::Dict{String,Any}, o::OptionGroup, args, i, ctx)
    for option in o.options
        next_index = consume!(d, option, args, i, ctx)
        if 0 < next_index
            return next_index
        end
    end
    return 0
end

function check_usage_count(o::OptionGroup, ctx)
    for option in o.options
        check_usage_count(option, ctx)
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
    MutexGroup(options::AbstractOption...; name::String = "")

`MutexGroup` contains one or more `AbstractOption`s and accepts command line arguments only
if exactly one of the options was accepted.
"""
struct MutexGroup <: AbstractOptionGroup
    name::String
    options

    MutexGroup(options::AbstractOption...; name::String = "") = new(name, options)
end

function set_default!(d::Dict{String,Any}, o::MutexGroup)  # Same as from OptionGroup
    for option in o.options
        set_default!(d, option)
    end
end

function consume!(d::Dict{String,Any}, o::MutexGroup, args, i, ctx)  # Same as from OptionGroup
    for option in o.options
        next_index = consume!(d, option, args, i, ctx)
        if 0 < next_index
            return next_index
        end
    end
    return 0
end

function check_usage_count(o::MutexGroup, ctx)
    exceptions = Exception[]
    for option in o.options
        try
            check_usage_count(option, ctx)
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
    CliOptionSpec(options::AbstractOption...;
                  program = PROGRAM_FILE,
                  onhelp = 0)

A type representing a command line option specification.

`program` parameter is used for the program name which appears in help (usage) message. If
omitted, `Base.PROGRAM_FILE` will be used.

`onhelp` parameter controls what to do if a [`HelpOption`](@ref) was used. It can be either:

1. An `Integer`
   - The running program will print help message and exit using it as the status code.
2. `nothing`
   - Nothing happens. In this case, the `HelpOption` is treated just like a
     [`FlagOption`](@ref) so you can examine whether it was used or not by examining
     [`ParseResult`](@ref) using its name.
3. A function which takes no arguments
   - Do whatever you want in the function.

The default value is `0`.

#### Example: Using a function for `onhelp` parameter

```jldoctest
using CliOptions

spec = CliOptionSpec(
    HelpOption(),
    onhelp = () -> begin
        print_usage(spec, verbose = false)
        # exit(42)  # Use exit() to let the program exit inside parse_args()
    end,
    program = "onhelptest.jl"
)
args = parse_args(spec, ["-h"])  # The program does not exit here
println(args.help)

# output

Usage: onhelptest.jl [-h]
true
```
"""
struct CliOptionSpec
    root::OptionGroup
    program::String
    onhelp::Any

    function CliOptionSpec(options::AbstractOption...;
                           program = PROGRAM_FILE,
                           onhelp = 0)
        if program == ""
            program = "PROGRAM"  # may be called inside REPL
        end
        new(OptionGroup(options...), program, onhelp)
    end
end

function Base.show(io::IO, x::CliOptionSpec)
    print(io, typeof(x), "(", join([repr(o) for o in x.root], ','), ")")
end
Base.show(x::CliOptionSpec) = show(stdout, x)


"""
    print_usage([io::IO], spec::CliOptionSpec; verbose = true)

Write usage (help) message to `io`. Set `false` to `verbose` if you want to print only the
first line of the usage message. If `io` is omitted, message will be written `stdout`.
"""
function print_usage(io::IO, spec::CliOptionSpec; verbose = true)
    print(io, "Usage: $(spec.program) ")
    println(io, join(Iterators.flatten(to_usage_tokens(o) for o in spec.root), " "))
    if verbose
        println(io)
        println(io, "Options:")
        print_description(io, spec.root)
    end
end

function print_usage(spec::CliOptionSpec; verbose = true)
    print_usage(stdout, spec, verbose = verbose)
end


struct ParseContext
    usage_count
    all_options

    ParseContext() = new(Dict{AbstractOption,Int}(), Vector{AbstractOption}())
end

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
    ctx = ParseContext()

    # Store all options in a vector and pick special options
    help_option = nothing
    remainders_option = nothing
    foreach_options(spec.root) do o
        push!(ctx.all_options, o)
        if o isa HelpOption
            help_option = o
        elseif o isa RemainderOption
            remainders_option = o
        end
    end

    # Normalize argument list
    args = _normalize_args(args)

    # Scan arguments for special options
    if help_option !== nothing
        for i = 1:length(args)
            if args[i] in help_option.names
                # Found a help option
                if spec.onhelp isa Integer
                    print_usage(stdout, spec)
                    _exit(spec.onhelp)
                elseif spec.onhelp !== nothing
                    spec.onhelp()
                end
            elseif remainders_option !== nothing && args[i] in remainders_option.names
                break
            end
        end
    end

    # Setup default values
    for option in spec.root
        set_default!(result._dict, option)
    end

    # Parse arguments
    i = 1
    while i ≤ length(args)
        next_index = consume!(result._dict, spec.root, args, i, ctx)
        if next_index ≤ 0
            throw(CliOptionError("Unrecognized argument: \"$(args[i])\""))
        end

        i = next_index
    end

    # Take care of omitted options
    for option ∈ (o for o in spec.root.options if get(ctx.usage_count, o, 0) ≤ 0)
        check_usage_count(option, ctx)
    end

    result
end

# Internals
encode(s) = replace(replace(s, r"^(--|-|/)" => ""), r"[^0-9a-zA-Z]" => "_")

function foreach_options(f, option::AbstractOption)
    if option isa AbstractOptionGroup
        for o in option.options
            foreach_options(f, o)
        end
    end
    f(option)
end

_exit = Base.exit

function _mock_exit_function(mock)  # Testing utility
    global _exit
    backup = _exit
    _exit = mock
    return _exit
end

function _mock_exit_function(f, mock)  # Testing utility
    backup = _mock_exit_function(mock)
    try
        f()
    finally
        _mock_exit_function(backup)
    end
end

function _normalize_args(args)
    normalized = String[]
    for i = 1:length(args)
        if !startswith(args[i], '-')
            push!(normalized, args[i])
        elseif startswith(args[i], "--")
            kv = split(args[i], '=')
            if length(kv) == 1
                push!(normalized, args[i])  # --foo-bar
            elseif length(kv) == 2
                push!(normalized, kv[1], kv[2])  # --foo-bar=baz
            else
                throw(CliOptionError("Unrecognizable option string: \"$(args[i])\""))
            end
        elseif startswith(args[i], '-')
            append!(normalized, ["-$c" for c in args[i][2:end]])  # -abc ==> -a -b -c
        end
    end
    return normalized
end

function _check_option_name(name)
    if "" == name
        return :empty  # An empty string
    elseif name[1] != '-'
        return :not_hyphen  # Not starting with a hyphen
    elseif name == "--"
        return :two_hyphens  # It's double hyphens
    elseif match(r"^-[^-]", name) === nothing && match(r"^--[^-]", name) === nothing
        return :invalid  # At least invalid as a name of an option
    end

    if tryparse(Float64, name) !== nothing
        return :negative  # It can be a negative number or a name of an option
    end
    return :valid  # It is a name of an option
end

function _validate_option_names(T, names; allow_nameless = false)
    article(T) = occursin("$T"[1], "AEIOUaeiou") ? "an" : "a"
    if !allow_nameless && length(names) == 0
        throw(ArgumentError("At least one name must be supplied for $(article(T)) $T"))
    end
    for name in names
        result = _check_option_name(name)
        if result == :empty
            throw(ArgumentError("Name of $(article(T)) $T must not be empty"))
        elseif result == :not_hyphen
            throw(ArgumentError("Name of $(article(T)) $T must start with a hyphen:" *
                                " \"$name\""))
        elseif result in (:two_hyphens, :invalid)
            if T == RemainderOption && result == :two_hyphens
                return
            end
            throw(ArgumentError("Invalid name for $T: \"$name\""))
        end
    end
end

function _parse(T, optval::AbstractString, validator::Any, optname = "")
    parsed_value::Union{Nothing,T} = nothing
    try
        # Use `parse` if available, or use constructor of the type
        if applicable(parse, T, optval)
            parsed_value = parse(T, optval)
        else
            parsed_value = T(optval)
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

    # Return validated value
    parsed_value
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
       HelpOption,
       Positional,
       RemainderOption,
       OptionGroup,
       MutexGroup,
       parse_args,
       print_usage,
       CliOptionError

end # module
