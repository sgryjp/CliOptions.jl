module CliOptions

include("errors.jl")
include("nodes.jl")

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

    make_option(name...)

# Examples
```julia-repl
julia> make_option("-i", "--ignore-case")
hoge
```
"""
function make_option(names::String...)
    @assert 0 < length(names)
    if is_option(names)
        return NamedOption(names...)
    else
        singular_name = names[1]
        if singular_name == ""
            throw_error("Singular name of a positional argument must be specified")
        end
        plural_name = 2 ≤ length(names) ? names[2] : ""
        return Positional(singular_name, plural_name)
    end
end

"""

    parse_args(options, args::Vector{String}=ARGS)

Parse command line options.

`options` defines the specification of command line options. Use [`make_option`](@ref) to
construct option specification.

`args` is the command line arguments to be parsed. If omitted, this function parses
`Base.ARGS` which is an array of command line arguments passed to the Julia script.
"""
function parse_args(options, args::Vector{String} = ARGS)
    dict = Dict{String,String}()
    root = OneOf([o for o ∈ options])
    ctx = Dict{Any,Int}(o => 0 for o ∈ options)

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

export make_option, parse_args

end # module
