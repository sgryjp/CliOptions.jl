module CliOptions

include("nodes.jl")


"""
    CliOptionError(msg::String)

An error occurred inside CliOptions module.
"""
struct CliOptionError <: Exception
    msg::String
end

throw_error(msg) = throw(CliOptionError(msg))


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
function parse_args(options, args::Vector{String} = ARGS)
    dict = Dict{String,String}()
    root = OneOf(options...)
    ctx = Dict{Option,Int}()

    i = 1
    while i ≤ length(args)
        next_index, pairs = consume!(ctx, root, args, i)
        if next_index < 0
            throw_error("Unrecognizable argument: " * args[i])
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

export CliOptionError, parse_args

end # module
