#!/usr/bin/env julia
#┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
#┃ 📁File      📄 order.jl                                                             ┃
#┃ 📙Brief     📝 Volvo Supplier Quality Pipeline Orchestrator                         ┃
#┃ 🧾Details   🔎 Executes web scraping, HTML parsing, and dashboard generation        ┃
#┃ 🚩OAuthor   🦋 Original Author: Jaewoo Joung/정재우/郑在祐                         ┃
#┃ 👨‍🔧LAuthor   👤 Last Author: Jaewoo Joung                                         ┃
#┃ 📆LastDate  📍 2025-11-20 🔄Please support to keep update🔄                     ┃
#┃ 🏭License   📜 JSD:Just Simple Distribution(Jaewoo's Simple Distribution)        ┃
#┃ ✅Guarantee ⚠️ Explicitly UN-guaranteed                                          ┃
#┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

# Get the directory where this script is located
script_dir = @__DIR__

# Change to script directory
cd(script_dir)
println("Working directory: $(pwd())\n")

# Create required directories

# Run Python script using run()
run(`python getweb.py`)

# Run Julia scripts using include()
include("gethtm.jl")
include("dashb.jl")
include("makenotification.jl ")
include("schedule.jl")
include("sendEmail.jl")