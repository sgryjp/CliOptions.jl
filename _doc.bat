@pushd "%~dp0\docs"
@julia --color=yes make.jl
@popd
