using Pkg

# 1. Activate the current directory as the project environment.
# This ensures Qprism and its dependencies are installed locally.
Pkg.activate(".")

# 2. Add dependencies using a single call for efficiency.
println("Installing dependencies...")
Pkg.add([
    "HTTP",
    "JSON3",
    "Gumbo",
    "Cascadia",
    "AbstractTrees",
    "WebDriver",
    "TOML"
])

# 3. Add packages from specific URLs.
println("Installing Sendmail.jl...")
Pkg.add(url="https://github.com/JaewooJoung/Sendmail.jl")

println("Installing Qprism.jl...")
Pkg.add(url="https://github.com/JaewooJoung/Qprism.jl")

# 4. Instantiation/Resolution is often automatic, but running it is safe.
Pkg.resolve()
Pkg.instantiate()

# 5. Test if it works.
try
    using Qprism
    println("\nSUCCESS: Qprism is installed and working!")
catch e
    println("\n❌ ERROR: Qprism installation failed to load: ", e)
    # Return a non-zero exit code to signal failure back to the batch file
    exit(1)
end
