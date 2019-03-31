module CliOptions


"""
    CliOptionError(msg::String)

An error occurred inside CliOptions module.
"""
struct CliOptionError <: Exception
    msg::String
end


"""
    AbstractOption

A definition of a command line option. Defined subtypes of this type are:

- NamedOption
- Positional
"""
abstract type AbstractOption end

#
# NamedOption
#
struct NamedOption <: AbstractOption
    names::Vector{String}

    function NamedOption(names::String...)
        if "" ∈ names
            throw(CliOptionError("Empty string is not allowed as an option's name"))
        end
        if any(name[1] != '-' for name ∈ names)
            throw(CliOptionError("Named option must start with '-'"))
        end
        new([n for n ∈ names])
    end
end

"""
    consume!(ctx, option, args, i)

Consumes zero or more arguments from `args` starting from index `i` according to the
`option`. This function returns a tuple of an index of next parsing position and a tuple of
key-value pairs. If the option is not matched for the argument, `(-1, nothing)` will be
returned.
"""
function consume!(ctx, o::NamedOption, args, i)
    @assert i ≤ length(args)
    if args[i] ∉ o.names
        return -1, nothing
    end
    if length(args) < i + 1
        throw(CliOptionError("A value is needed for option `" * args[i] * "`"))
    end

    # Get how many times this option was evaluated
    count::Int = get(ctx, o, -1)
    if count == -1
        ctx[o] = 0
    end

    # Skip if this node is already processed
    if 1 ≤ count
        return -1, nothing
    end
    ctx[o] += 1

    value = args[i + 1]
    i + 2, Tuple(encode(name) => value for name in o.names)
end


"""
    FlagOption

`FlagOption` represents a so-called "flag" command line option. An option of this type takes
no value and whether it was specified becomes a boolean value.
"""
struct FlagOption <: AbstractOption
    names::Vector{String}
    negators::Vector{String}

    function FlagOption(names::String...; negators::Vector{String}=String[])
        for name in unique(vcat(collect(names), negators))
            if match(r"^-[^-]", name) == nothing && match(r"^--[^-]", name) == nothing
                if name == ""
                    throw(ArgumentError("Name of a FlagOption must not be empty: " * name))
                elseif match(r"^[^-]", name) != nothing
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

#
# Positional
#
struct Positional <: AbstractOption
    names::Vector{String}
    quantity::Char

    function Positional(singular_name, plural_name = ""; quantity='1')
        if singular_name == ""
            throw(CliOptionError("Name of positional argument must not be an empty string"))
        end
        if quantity ∉ ('1', '+')
            throw(CliOptionError("Quantity of positional argument must be" *
                                 " one of '1' or '+'"))
        end

        if plural_name == ""
            return new([singular_name], quantity)
        else
            return new([singular_name, plural_name], quantity)
        end
    end
end

function consume!(ctx, o::Positional, args, i)
    @assert i ≤ length(args)
    @assert "" ∉ o.names
    if length(args) < i
        throw(CliOptionError("`" * o.names[1] * "` must be specified"))
    end

    # Get how many times this option was evaluated
    count::Int = get(ctx, o, -1)
    if count == -1
        ctx[o] = 0
    end

    # Skip if this node is already processed
    max_nvalues = Dict('1' => 1, '+' => Inf)[o.quantity]
    if max_nvalues ≤ count
        return -1, nothing
    end

    if o.quantity ∈ ('+',)
        value = args[i:end]
        ctx[o] += length(value)
        next_index = i + length(value)
    else
        value = args[i]
        ctx[o] += 1
        next_index = i + 1
    end

    next_index, Tuple(encode(name) => value for name ∈ o.names)
end

#
# OneOf
#
struct OneOf <: AbstractOption
    options::Vector{AbstractOption}

    OneOf(options::AbstractOption...) = new([o for o ∈ options])
end

function consume!(ctx, o::OneOf, args, i)
    for option in o.options
        next_index, pairs = consume!(ctx, option, args, i)
        if 0 < next_index
            return next_index, pairs
        end
    end
    return -1, nothing
end


"""
    ParsedArguments

Dict-like object holding parsing result of command line options.
"""
struct ParsedArguments
    _dict
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
    else
        return getfield(args, :_dict)[String(name)]
    end
end


"""
    parse_args(options, args::Vector{String}=ARGS)

Parse command line options.

`options` defines the specification of command line options.

`args` is the command line arguments to be parsed. If omitted, this function parses
`Base.ARGS` which is an array of command line arguments passed to the Julia script.
"""
function parse_args(options, args::Vector{AbstractString} = ARGS)
    dict = Dict{String,String}()
    root = OneOf(options...)
    ctx = Dict{AbstractOption,Int}()

    i = 1
    while i ≤ length(args)
        next_index, pairs = consume!(ctx, root, args, i)
        if next_index < 0
            throw(CliOptionError("Unrecognizable argument: " * args[i]))
        end

        for (k, v) ∈ pairs
            dict[k] = v
        end
        i = next_index
    end
    ParsedArguments(dict)
end

# Internals
encode(s) = replace(replace(s, r"^(--|-|/)" => ""), r"[^0-9a-zA-Z]" => "_")
is_option(names) = any([startswith(name, '-') && 2 ≤ length(name) for name ∈ names])


export AbstractOption, CliOptionError, NamedOption, OneOf, parse_args, Positional

end # module
