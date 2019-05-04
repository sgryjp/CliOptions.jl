@echo off
for /r %%I in (*.cov) do (
    del %%I
)
julia --color=yes --project --code-cover=user -e "include(\"test/runtests.jl\")"
