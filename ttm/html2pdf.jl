mkpath("./scorepdf")

html_files = readdir("./scorehtmls", join=true)
html_files = filter(f -> endswith(f, ".html"), html_files)

println("Found $(length(html_files)) HTML files to convert")

# Try to find Chrome/Chromium executable
chrome_paths = [
    "/usr/bin/google-chrome",
    "/usr/bin/chromium-browser",
    "/usr/bin/chromium",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
    "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe"
]

chrome = findfirst(isfile, chrome_paths)
if isnothing(chrome)
    error("Chrome/Chromium not found. Please install Google Chrome or Chromium.")
end
chrome_exe = chrome_paths[chrome]

println("Using Chrome: $chrome_exe\n")

for html_file in html_files
    pdf_name = replace(basename(html_file), ".html" => ".pdf")
    pdf_file = abspath(joinpath("./scorepdf", pdf_name))
    abs_html = abspath(html_file)
    
    println("Converting: $(basename(html_file)) -> $pdf_name")
    
    try
        # Use Chrome DevTools Protocol for better control
        run(`$chrome_exe --headless --disable-gpu --run-all-compositor-stages-before-draw --print-to-pdf-no-header --print-to-pdf=$pdf_file file://$abs_html`)
        println("  ✓ Success")
    catch e
        println("  ✗ Failed: $e")
    end
end

println("\nConversion complete!")
