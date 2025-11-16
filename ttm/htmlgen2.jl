#!/usr/bin/env julia
"""
htmlgen1.jl
Generate static HTML pages for each supplier using parsed JSON data
"""

using JSON
using Dates

# Include the template
include("html_template2.jl")

function load_supplier_json(json_file::String)
    """Load supplier data from JSON file"""
    println("📄 Loading: $json_file")
    
    open(json_file, "r") do f
        data = JSON.parse(f)
        return data
    end
end

function save_html(html_content::String, output_file::String)
    """Save HTML content to file"""
    # Create directory if it doesn't exist
    output_dir = dirname(output_file)
    if !isdir(output_dir)
        mkpath(output_dir)
        println("   📁 Created directory: $output_dir")
    end
    
    open(output_file, "w") do f
        write(f, html_content)
    end
    
    println("   💾 Saved: $output_file")
end

function generate_index_html(suppliers_data::Vector, output_dir::String)
    """Generate index.html with list of all suppliers"""
    
    # Create supplier cards HTML
    cards_html = ""
    for supplier in suppliers_data
        supplier_id = get(supplier, "id", "N/A")
        supplier_name = get(supplier, "name", "Unknown")
        logo = get(supplier, "logo", "??")
        parma_id = get(supplier, "parmaId", "N/A")
        
        # Get audit count
        audits = get(supplier, "audits", [])
        approved_count = count(a -> get(a, "statusClass", "") == "status-approved", audits)
        total_audits = length(audits)
        
        # Get latest QPM/PPM
        qpm_data = get(supplier, "qpm", Dict())
        qpm_values = get(qpm_data, "values", [])
        qpm_latest = length(qpm_values) > 0 ? qpm_values[end] : 0
        
        ppm_data = get(supplier, "ppm", Dict())
        ppm_values = get(ppm_data, "values", [])
        ppm_latest = length(ppm_values) > 0 ? ppm_values[end] : 0
        
        cards_html *= """
        <div class="supplier-card" onclick="window.location.href='scorehtmls/$supplier_id.html'">
            <div class="card-header">
                <div class="supplier-logo-small">$logo</div>
                <div class="supplier-name-container">
                    <div class="supplier-name">$supplier_name</div>
                    <div class="supplier-id">PARMA: $parma_id</div>
                </div>
            </div>
            <div class="card-body">
                <div class="card-metric">
                    <div class="metric-label-small">Audits</div>
                    <div class="metric-value-small">$approved_count/$total_audits</div>
                </div>
                <div class="card-metric">
                    <div class="metric-label-small">QPM</div>
                    <div class="metric-value-small">$qpm_latest</div>
                </div>
                <div class="card-metric">
                    <div class="metric-label-small">PPM</div>
                    <div class="metric-value-small">$ppm_latest</div>
                </div>
            </div>
        </div>
        """
    end
    
    current_time = Dates.format(Dates.now(), "yyyy-mm-dd HH:MM")
    
    html = """
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Volvo Supplier Quality Dashboard</title>
    <style>
<style>
    @page {
    size: A3 landscape;
    margin: 10mm;
          }    
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: #f5f5f5;
        }
        
        .header {
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            color: white;
            padding: 20px 30px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.2);
        }
        
        .header-content {
            max-width: 1400px;
            margin: 0 auto;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .header h1 {
            font-size: 28px;
            font-weight: 600;
        }
        
        .last-update {
            font-size: 13px;
            opacity: 0.9;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 30px;
        }
        
        .stats-row {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .stat-card {
            background: white;
            border-radius: 8px;
            padding: 20px;
            box-shadow: 0 2px 6px rgba(0,0,0,0.08);
        }
        
        .stat-label {
            font-size: 12px;
            color: #666;
            font-weight: 600;
            text-transform: uppercase;
            margin-bottom: 10px;
        }
        
        .stat-value {
            font-size: 32px;
            font-weight: bold;
            color: #2c5f8d;
        }
        
        .suppliers-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 20px;
        }
        
        .supplier-card {
            background: white;
            border-radius: 8px;
            padding: 20px;
            box-shadow: 0 2px 6px rgba(0,0,0,0.08);
            cursor: pointer;
            transition: all 0.3s;
        }
        
        .supplier-card:hover {
            transform: translateY(-4px);
            box-shadow: 0 6px 20px rgba(0,0,0,0.15);
        }
        
        .card-header {
            display: flex;
            gap: 15px;
            margin-bottom: 15px;
            padding-bottom: 15px;
            border-bottom: 2px solid #f0f0f0;
        }
        
        .supplier-logo-small {
            width: 60px;
            height: 60px;
            background: linear-gradient(135deg, #ff6b6b 0%, #ff8e53 100%);
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-size: 24px;
            font-weight: bold;
            flex-shrink: 0;
        }
        
        .supplier-name-container {
            flex: 1;
            display: flex;
            flex-direction: column;
            justify-content: center;
        }
        
        .supplier-name {
            font-size: 16px;
            font-weight: 600;
            color: #333;
            margin-bottom: 4px;
        }
        
        .supplier-id {
            font-size: 12px;
            color: #666;
        }
        
        .card-body {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 15px;
        }
        
        .card-metric {
            text-align: center;
        }
        
        .metric-label-small {
            font-size: 11px;
            color: #666;
            font-weight: 600;
            text-transform: uppercase;
            margin-bottom: 6px;
        }
        
        .metric-value-small {
            font-size: 20px;
            font-weight: bold;
            color: #2c5f8d;
        }
        
        .section-title {
            font-size: 20px;
            font-weight: 600;
            color: #333;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 2px solid #2c5f8d;
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="header-content">
            <h1>Volvo Supplier Quality Dashboard</h1>
            <div class="last-update">Last Update: $current_time</div>
        </div>
    </div>
    
    <div class="container">
        <div class="stats-row">
            <div class="stat-card">
                <div class="stat-label">Total Suppliers</div>
                <div class="stat-value">$(length(suppliers_data))</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Active Audits</div>
                <div class="stat-value">$(length(suppliers_data) * 6)</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Avg QPM</div>
                <div class="stat-value">--</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Avg PPM</div>
                <div class="stat-value">--</div>
            </div>
        </div>
        
        <div class="section-title">Supplier Partners</div>
        
        <div class="suppliers-grid">
            $cards_html
        </div>
    </div>
</body>
</html>
"""
    
    index_file = joinpath(output_dir, "index.html")
    save_html(html, index_file)
    println("\n✅ Generated index page: $index_file")
end

function process_all_suppliers(json_dir::String, output_dir::String)
    """Process all supplier JSON files and generate HTML pages"""
    
    println()
    println(repeat("=", 70))
    println("VOLVO SUPPLIER HTML GENERATOR")
    println(repeat("=", 70))
    println("\n📂 JSON Directory: $json_dir")
    println("📂 Output Directory: $output_dir")
    println()
    
    # Find all supplier JSON files
    json_files = filter(f -> occursin(r"supplier_\d+\.json$", f), readdir(json_dir))
    
    if isempty(json_files)
        println("❌ No supplier JSON files found in $json_dir")
        println("   Expected files like: supplier_23629.json")
        return
    end
    
    println("🔍 Found $(length(json_files)) supplier JSON files")
    println(repeat("=", 70))
    
    # Process each supplier
    suppliers_data = []
    for json_file in json_files
        json_path = joinpath(json_dir, json_file)
        
        try
            # Load JSON data
            supplier_data = load_supplier_json(json_path)
            
            # Generate HTML
            html_content = generate_supplier_html(supplier_data)
            
            # Save HTML
            supplier_id = get(supplier_data, "id", "unknown")
            output_file = joinpath(output_dir, "scorehtmls", "$supplier_id.html")
            save_html(html_content, output_file)
            
            # Store for index generation
            push!(suppliers_data, supplier_data)
            
            println()
            
        catch e
            println("   ❌ Error processing $json_file: $e")
            println()
        end
    end
    
    # Generate index page
    if !isempty(suppliers_data)
        generate_index_html(suppliers_data, output_dir)
    end
    
    # Summary
    println()
    println(repeat("=", 70))
    println("✅ HTML GENERATION COMPLETE!")
    println(repeat("=", 70))
    println("📊 Processed: $(length(suppliers_data)) suppliers")
    println("📁 Output: $output_dir")
    println()
    println("💡 To view:")
    println("   Open: $(output_dir)\\index.html")
    println(repeat("=", 70))
end

# Main execution
function main()
    # Default directories
    json_dir = "dashboard/suppliers"
    output_dir = "."  # Current directory, will create ./scorehtmls/
    
    # Allow command line arguments
    if length(ARGS) >= 1
        json_dir = ARGS[1]
    end
    if length(ARGS) >= 2
        output_dir = ARGS[2]
    end
    
    # Process all suppliers
    process_all_suppliers(json_dir, output_dir)
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()

end
