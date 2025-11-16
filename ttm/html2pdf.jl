using Dates

# Create output directory if it doesn't exist
mkpath("./scorepdf")

# Get all HTML files
html_files = readdir("./scorehtmls", join=true)
html_files = filter(f -> endswith(f, ".html"), html_files)

println("Found $(length(html_files)) HTML files to convert")

# Convert each HTML file
for html_file in html_files
    # Get base filename and create PDF path
    basename_file = basename(html_file)
    pdf_name = replace(basename_file, ".html" => ".pdf")
    pdf_file = joinpath("./scorepdf", pdf_name)
    
    println("Converting: $basename_file -> $pdf_name")
    
    # Convert using wkhtmltopdf (simplest option)
    try
        run(`wkhtmltopdf $html_file $pdf_file`)
        println("  ✓ Success")
    catch e
        println("  ✗ Failed: $e")
    end
end

println("\nConversion complete!")
