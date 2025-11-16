#!/usr/bin/env julia

# Run Python script using run()
run(`python gethtmls4.py`)

# Run Julia scripts using include()
include("htmlgen2.jl")
include("html2pdf.jl")
