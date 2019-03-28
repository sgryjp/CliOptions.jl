"""

    CliOptionError(msg::String)

Represents an error emitted by CliOptions module.
"""
struct CliOptionError <: Exception
    msg::String
end

throw_error(msg) = throw(CliOptionError(msg))

export CliOptionError
