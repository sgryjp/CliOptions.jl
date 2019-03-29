abstract type Option end

#
# NamedOption
#
struct NamedOption <: Option
    names

    function NamedOption(names::String...)
        if "" ∈ names
            throw_error("Empty string is not allowed as an option's name")
        end
        new(names)
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

    # Skip if this node is already processed
    if 1 ≤ ctx[o]
        return -1, nothing
    end

    value = args[i + 1]
    ctx[o] += 1
    i + 2, Tuple(encode(name) => value for name in o.names)
end

#
# Positional
#
struct Positional <: Option
    names

    function Positional(singular_name, plural_name = "")
        if singular_name == ""
            throw_error("Name of positional argument must not be an empty string")
        end
        plural_name == "" ? new((singular_name,)) : new((singular_name, plural_name))
    end
end

function consume!(ctx, o::Positional, args, i)
    @assert i ≤ length(args)
    @assert "" ∉ o.names
    if length(args) < i
        throw_error("`" * o.names[1] * "` must be specified")
    end

    # Skip if this node is already processed
    if 1 ≤ ctx[o]
        return -1, nothing
    end

    value = args[i]
    ctx[o] += 1
    i + 1, Tuple(encode(name) => value for name ∈ o.names)
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

export NamedOption, Positional, OneOf
