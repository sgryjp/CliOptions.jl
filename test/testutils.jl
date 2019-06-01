sorted_keys = sort ∘ collect ∘ keys

function Base.redirect_stdout(f::Function, stream::IOBuffer)
    backup = stdout
    rd, wr = redirect_stdout()
    try
        f()
    finally
        redirect_stdout(backup)
        close(wr)
        write(stream, read(rd))
        close(rd)
    end
end

function Base.redirect_stderr(f::Function, stream::IOBuffer)
    backup = stderr
    rd, wr = redirect_stderr()
    try
        f()
    finally
        redirect_stderr(backup)
        close(wr)
        write(stream, read(rd))
        close(rd)
    end
end

function stringify(e::Exception)
    buf = IOBuffer()
    showerror(buf, e)
    String(take!(buf))
end
