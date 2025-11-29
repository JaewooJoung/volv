using Pkg

# First, install all dependencies individually
Pkg.add("HTTP")
Pkg.add("JSON3") 
Pkg.add("Gumbo")
Pkg.add("Cascadia")
Pkg.add("AbstractTrees")
Pkg.add("WebDriver")
Pkg.add("TOML")

# Install Sendmail
Pkg.add(url="https://github.com/JaewooJoung/Sendmail.jl")

# install Qprism
Pkg.add(url="https://github.com/JaewooJoung/Qprism.jl")

# Force resolve dependencies
Pkg.resolve()
Pkg.instantiate()

# Test if it works
try
    using Qprism
    println("SUCCESS: Qprism is working!")
catch e
    println("ERROR: ", e)
end
