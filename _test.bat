@echo off
julia --color=yes --project -e "using Test; include(\"test/runtests.jl\")"
