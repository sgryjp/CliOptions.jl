"""
    Option

A definition of a command line option. Defined subtypes of this type are:

- NamedOption
- Positional
"""
abstract type Option end

#
# NamedOption
#
struct NamedOption <: Option
    names::Vector{String}

    function NamedOption(names::String...)
        if "" ∈ names
            throw_error("Empty string is not allowed as an option's name")
        end
        if any(name[1] != '-' for name ∈ names)
            throw_error("Named option must start with '-'")
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
        throw_error("A value is needed for option `" * args[i] * "`")
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

#
# Positional
#
struct Positional <: Option
    names::Vector{String}
    quantity::Char

    function Positional(singular_name, plural_name = ""; quantity='1')
        if singular_name == ""
            throw_error("Name of positional argument must not be an empty string")
        end
        if quantity ∉ ('1', '+')
            throw_error("Quantity of positional argument must be" *
                        " one of '1' or '+'")
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
        throw_error("`" * o.names[1] * "` must be specified")
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
struct OneOf <: Option
    options::Vector{Option}

    OneOf(options::Option...) = new([o for o ∈ options])
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

export NamedOption, OneOf, Option, Positional
