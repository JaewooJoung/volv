#!/usr/bin/env julia
#┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
#┃ 📁File      📄 gethtm.jl                                                           ┃
#┃ 📙Brief     📝 Volvo Supplier Scorecard HTML Parser                                ┃
#┃ 🧾Details   🔎 Extracts supplier metrics, audits, QPM/PPM from VSIB HTML files     ┃
#┃ 🚩OAuthor   🦋 Original Author: Jaewoo Joung/정재우/郑在祐                         ┃
#┃ 👨‍🔧LAuthor   👤 Last Author: Jaewoo Joung                                         ┃
#┃ 📆LastDate  📍 2025-11-19 🔄Please support to keep update🔄                     ┃
#┃ 🏭License   📜 JSD:Just Simple Distribution(Jaewoo's Simple Distribution)        ┃
#┃ ✅Guarantee ⚠️ Explicitly UN-guaranteed                                          ┃
#┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

"""
    Volvo Supplier Scorecard HTML Parser

Parses Volvo Supplier Scorecard HTML files to extract:
- Supplier information (ID, name, contact)
- Quality audit metrics (SW Index, EE Index, SMA)
- Performance metrics (QPM, PPM with trends)
- APQP/PPAP status
- Audit results and status

Modified to compare Last Period vs Actual QPM/PPM values only
"""

using Gumbo
using Cascadia
using JSON3
using Dates
using Printf
using AbstractTrees

# Type definitions for structured data
struct AuditInfo
    title::String
    status::String
    statusClass::String
    date::String
end

struct MetricsInfo
    swIndex::String
    swStatus::String
    swDate::String
    eeIndex::String
    eeStatus::String
    eeDate::String
    sma::String
    smaStatus::String
    smaDate::String
    csr::String
    csrStatus::String
    csrDate::String
    saq::String
    saqStatus::String
end

struct PerformanceMetric
    lastPeriod::String
    actual::String
    change::String
    changePercent::String
    trend::String  # "up", "down", "neutral"
end

struct SupplierData
    id::String
    parmaId::String
    name::String
    logo::String
    address::String
    projectLink::String
    timeplanLink::String
    apqp::String
    ppap::String
    audits::Vector{AuditInfo}
    metrics::MetricsInfo
    qpm::PerformanceMetric
    ppm::PerformanceMetric
end

"""
    extract_text(elem) -> String

Safely extract text from HTML element, returns "N/A" if element is nothing
"""
function extract_text(elem)::String
    isnothing(elem) && return "N/A"
    text = strip(nodeText(elem))
    isempty(text) ? "N/A" : text
end

"""
    get_class(elem) -> String

Get the class attribute from HTML element, returns empty string if not found
"""
function get_class(elem)::String
    isnothing(elem) && return ""
    # Get attributes from Gumbo HTML node
    haskey(attrs(elem), "class") ? attrs(elem)["class"] : ""
end

"""
    parse_quality_audits(doc) -> Dict

Parse Quality Audits section (SW Index, Software Index, EE Index, SMA, Polymer Index)
from the IndexAuditPanel div
"""
function parse_quality_audits(doc)::Dict{String, String}
    metrics = Dict{String, String}(
        "swIndex" => "N/A",
        "swStatus" => "N/A",
        "swDate" => "N/A",
        "eeIndex" => "N/A",
        "eeStatus" => "N/A",
        "eeDate" => "N/A",
        "sma" => "N/A",
        "smaStatus" => "N/A",
        "smaDate" => "N/A",
        "polymerIndex" => "N/A",
        "polymerStatus" => "N/A",
        "polymerDate" => "N/A"
    )
    
    # Find the IndexAuditPanel div
    audit_panel = eachmatch(Selector("#IndexAuditPanel"), doc.root)
    isempty(audit_panel) && return metrics
    
    audit_text = extract_text(first(audit_panel))
    println("   🔍 Quality Audits section found")
    
    # Extract SMA / Criticality 1 Index
    sma_match = match(r"SMA\s*/\s*Criticality\s+1\s+Index(.+?)(?:Software Index|EE Index|Polymer Index|$)"i, audit_text)
    if !isnothing(sma_match)
        sma_text = sma_match.captures[1]
        
        # Extract percentage
        perc_match = match(r"(\d+)%", sma_text)
        if !isnothing(perc_match)
            metrics["sma"] = perc_match.captures[1] * "%"
        end
        
        # Extract status
        if occursin("Approved", sma_text)
            metrics["smaStatus"] = "Approved"
        elseif occursin(r"Not [Aa]pproved", sma_text)
            metrics["smaStatus"] = "Not Approved"
        end
        
        # Extract date
        date_match = match(r"(\d{4}-\d{2}-\d{2})", sma_text)
        if !isnothing(date_match)
            metrics["smaDate"] = date_match.captures[1]
        end
        
        println("      ✓ SMA Index: $(metrics["sma"]) - $(metrics["smaStatus"]) ($(metrics["smaDate"]))")
    end
    
    # Extract Software Index
    sw_match = match(r"Software\s+Index(.+?)(?:EE Index|Polymer Index|$)"i, audit_text)
    if !isnothing(sw_match)
        sw_text = sw_match.captures[1]
        
        # Extract percentage
        perc_match = match(r"(\d+)%", sw_text)
        if !isnothing(perc_match)
            metrics["swIndex"] = perc_match.captures[1] * "%"
        end
        
        # Extract status
        if occursin("Approved", sw_text)
            metrics["swStatus"] = "Approved"
        elseif occursin(r"Not [Aa]pproved", sw_text)
            metrics["swStatus"] = "Not Approved"
        end
        
        # Extract date
        date_match = match(r"(\d{4}-\d{2}-\d{2})", sw_text)
        if !isnothing(date_match)
            metrics["swDate"] = date_match.captures[1]
            
            # Check if SW Index is expired (more than 5 years old)
            try
                sw_date = Date(date_match.captures[1])
                current_date = Dates.today()
                years_diff = (current_date - sw_date).value / 365.25  # Average days per year accounting for leap years
                
                if years_diff > 5.0 && metrics["swStatus"] == "Approved"
                    metrics["swStatus"] = "Expired"
                    println("      ⚠️  SW Index: $(metrics["swIndex"]) - $(metrics["swStatus"]) ($(metrics["swDate"])) - MORE THAN 5 YEARS OLD")
                else
                    println("      ✓ SW Index: $(metrics["swIndex"]) - $(metrics["swStatus"]) ($(metrics["swDate"]))")
                end
            catch e
                println("      ⚠️  Could not parse SW Index date for expiration check: $e")
                println("      ✓ SW Index: $(metrics["swIndex"]) - $(metrics["swStatus"]) ($(metrics["swDate"]))")
            end
        else
            println("      ✓ SW Index: $(metrics["swIndex"]) - $(metrics["swStatus"]) ($(metrics["swDate"]))")
        end
    end
    
    # Extract EE Index
    ee_match = match(r"EE\s+Index(.+?)(?:Polymer Index|$)"i, audit_text)
    if !isnothing(ee_match)
        ee_text = ee_match.captures[1]
        
        # Extract percentage
        perc_match = match(r"(\d+)%", ee_text)
        if !isnothing(perc_match)
            metrics["eeIndex"] = perc_match.captures[1] * "%"
        end
        
        # Extract status (can be "Approved with conditions")
        if occursin("Approved with conditions", ee_text)
            metrics["eeStatus"] = "Approved with conditions"
        elseif occursin("Approved", ee_text)
            metrics["eeStatus"] = "Approved"
        elseif occursin(r"Not [Aa]pproved", ee_text)
            metrics["eeStatus"] = "Not Approved"
        end
        
        # Check for Restriction
        if occursin("Restriction", ee_text)
            metrics["eeStatus"] *= " (Restriction)"
        end
        
        # Extract date
        date_match = match(r"(\d{4}-\d{2}-\d{2})", ee_text)
        if !isnothing(date_match)
            metrics["eeDate"] = date_match.captures[1]
        end
        
        println("      ✓ EE Index: $(metrics["eeIndex"]) - $(metrics["eeStatus"]) ($(metrics["eeDate"]))")
    end
    
    # Extract Polymer Index
    polymer_match = match(r"Polymer\s+Index(.+?)$"i, audit_text)
    if !isnothing(polymer_match)
        polymer_text = polymer_match.captures[1]
        
        # Extract percentage
        perc_match = match(r"(\d+)%", polymer_text)
        if !isnothing(perc_match)
            metrics["polymerIndex"] = perc_match.captures[1] * "%"
        end
        
        # Extract status
        if occursin("Approved with conditions", polymer_text)
            metrics["polymerStatus"] = "Approved with conditions"
        elseif occursin("Approved", polymer_text)
            metrics["polymerStatus"] = "Approved"
        elseif occursin(r"Not [Aa]pproved", polymer_text)
            metrics["polymerStatus"] = "Not Approved"
        end
        
        # Extract date
        date_match = match(r"(\d{4}-\d{2}-\d{2})", polymer_text)
        if !isnothing(date_match)
            metrics["polymerDate"] = date_match.captures[1]
        end
        
        println("      ✓ Polymer Index: $(metrics["polymerIndex"]) - $(metrics["polymerStatus"]) ($(metrics["polymerDate"]))")
    end
    
    return metrics
end

"""
    parse_supplier_html(html_file_path::String) -> SupplierData

Parse a Volvo supplier scorecard HTML file and extract all relevant data
"""
function parse_supplier_html(html_file_path::String)::NamedTuple
    println("📄 Parsing: $html_file_path")
    
    # Read and parse HTML
    html_content = read(html_file_path, String)
    doc = parsehtml(html_content)
    
    # Extract supplier ID and name
    supplier_link = eachmatch(Selector("a[href*='SupplierInformation.aspx']"), doc.root)
    supplier_info = isempty(supplier_link) ? "Unknown Supplier" : extract_text(first(supplier_link))
    
    # Parse supplier ID and name
    supplier_id = "N/A"
    supplier_name = "Unknown"
    if occursin(',', supplier_info)
        parts = split(supplier_info, ',', limit=2)
        supplier_id = strip(parts[1])
        supplier_name = strip(parts[2])
    end
    
    println("   📋 Supplier: $supplier_name (ID: $supplier_id)")
    
    # Initialize data structure
    data = Dict{String, Any}(
        "id" => supplier_id,
        "parmaId" => supplier_id,
        "name" => supplier_name,
        "logo" => supplier_name != "Unknown" ? uppercase(supplier_name[1:min(2, length(supplier_name))]) : "??",
        "address" => "N/A",
        "projectLink" => "#",
        "timeplanLink" => "#",
        "apqp" => "N/A",
        "ppap" => "N/A",
        "audits" => [],
        "metrics" => Dict{String, String}(
            "swIndex" => "N/A",
            "swStatus" => "N/A",
            "swDate" => "N/A",
            "eeIndex" => "N/A",
            "eeStatus" => "N/A",
            "eeDate" => "N/A",
            "sma" => "N/A",
            "smaStatus" => "N/A",
            "smaDate" => "N/A",
            "polymerIndex" => "N/A",
            "polymerStatus" => "N/A",
            "polymerDate" => "N/A",
            "csr" => "N/A",
            "csrStatus" => "N/A",
            "csrDate" => "N/A",
            "saq" => "N/A",
            "saqStatus" => "N/A"
        ),
        "certifications" => Dict{String, Any}(
            "quality" => Dict{String, String}(
                "type" => "N/A",
                "certifiedPlace" => "N/A",
                "registratedTime" => "N/A",
                "expirationTime" => "N/A",
                "status" => "N/A"
            ),
            "environmental" => Dict{String, String}(
                "type" => "N/A",
                "certifiedPlace" => "N/A",
                "registratedTime" => "N/A",
                "expirationTime" => "N/A",
                "status" => "N/A"
            ),
            "logistic" => Dict{String, String}(
                "grade" => "N/A",
                "percentage" => "N/A",
                "method" => "N/A",
                "version" => "N/A",
                "performedDate" => "N/A",
                "status" => "N/A"
            ),
            "reach" => Dict{String, String}(
                "compliance" => "N/A",
                "evaluatedTime" => "N/A",
                "status" => "N/A"
            ),
            "sustainability" => Dict{String, String}(
                "percentage" => "N/A",
                "evaluatedTime" => "N/A",
                "status" => "N/A"
            )
        ),
        "capacity" => Dict{String, String}(
            "documents" => "N/A",
            "riskLevel" => "N/A"
        ),
        "supplierStatus" => Dict{String, String}(
            "lowPerforming" => "N/A",  # "Low", "High", "No", "N/A"
            "warrantySevereIssues" => "N/A"  # "Yes", "No", "N/A"
        ),
        "qpm" => Dict{String, String}(
            "lastPeriod" => "N/A",
            "actual" => "N/A",
            "change" => "N/A",
            "changePercent" => "N/A",
            "trend" => "neutral"
        ),
        "ppm" => Dict{String, String}(
            "lastPeriod" => "N/A",
            "actual" => "N/A",
            "change" => "N/A",
            "changePercent" => "N/A",
            "trend" => "neutral"
        )
    )
    
    # Extract SEM audit
    sem_panel = eachmatch(Selector("#SEMPanelFollowup"), doc.root)
    if !isempty(sem_panel)
        sem_text = extract_text(first(sem_panel))
        
        # Find status
        status = "N/A"
        status_class = "status-na"
        if occursin("Pass", sem_text)
            status = "Pass"
            status_class = "status-approved"
        elseif occursin("Fail", sem_text)
            status = "Fail"
            status_class = "status-rejected"
        end
        
        # Extract date
        date_match = match(r"(\d{4}-\d{2}-\d{2})", sem_text)
        audit_date = isnothing(date_match) ? "N/A" : date_match.captures[1]
        
        push!(data["audits"], Dict(
            "title" => "SEM Audit",
            "status" => status,
            "statusClass" => status_class,
            "date" => audit_date
        ))
        
        println("   📋 SEM Audit: $status ($audit_date)")
    end
    
    # Extract Quality Certification
    # Search for the strong tag containing "Quality Certification:"
    all_elements = collect(PreOrderDFS(doc.root))
    for (idx, elem) in enumerate(all_elements)
        if elem isa HTMLElement && tag(elem) == :strong
            elem_text = extract_text(elem)
            if occursin("Quality Certification:", elem_text)
                # Look for sibling or parent's next sibling containing the data
                # The data is typically in a div with SSColorRating class
                try
                    # Search forward for div with certificate data
                    for search_elem in all_elements[idx:min(idx+20, length(all_elements))]
                        if search_elem isa HTMLElement && tag(search_elem) == :div
                            div_text = extract_text(search_elem)
                            cert_match = match(r"([^,]+),\s*([^,]+),\s*Registrated:\s*(\d{4}-\d{2}-\d{2}),\s*Expire:\s*(\d{4}-\d{2}-\d{2})", div_text)
                            if !isnothing(cert_match)
                                data["certifications"]["quality"]["type"] = strip(cert_match.captures[1])
                                data["certifications"]["quality"]["certifiedPlace"] = strip(cert_match.captures[2])
                                data["certifications"]["quality"]["registratedTime"] = cert_match.captures[3]
                                data["certifications"]["quality"]["expirationTime"] = cert_match.captures[4]
                                
                                # Check CSS class for status
                                class_attr = get_class(search_elem)
                                if occursin("Green", class_attr)
                                    data["certifications"]["quality"]["status"] = "Valid"
                                elseif occursin("Red", class_attr)
                                    data["certifications"]["quality"]["status"] = "Expired"
                                elseif occursin("Yellow", class_attr)
                                    data["certifications"]["quality"]["status"] = "Warning"
                                end
                                
                                println("   📜 Quality Cert: $(data["certifications"]["quality"]["type"]) - $(data["certifications"]["quality"]["status"])")
                                break
                            end
                        end
                    end
                catch e
                    println("   ⚠️  Error parsing Quality Certification: $e")
                end
                break
            end
        end
    end
    
    # Extract Environmental Certification
    for (idx, elem) in enumerate(all_elements)
        if elem isa HTMLElement && tag(elem) == :strong
            elem_text = extract_text(elem)
            if occursin("Environmental Certification:", elem_text)
                try
                    for search_elem in all_elements[idx:min(idx+20, length(all_elements))]
                        if search_elem isa HTMLElement && tag(search_elem) == :div
                            div_text = extract_text(search_elem)
                            cert_match = match(r"([^,]+),\s*([^,]+),\s*Registrated:\s*(\d{4}-\d{2}-\d{2}),\s*Expire:\s*(\d{4}-\d{2}-\d{2})", div_text)
                            if !isnothing(cert_match)
                                data["certifications"]["environmental"]["type"] = strip(cert_match.captures[1])
                                data["certifications"]["environmental"]["certifiedPlace"] = strip(cert_match.captures[2])
                                data["certifications"]["environmental"]["registratedTime"] = cert_match.captures[3]
                                data["certifications"]["environmental"]["expirationTime"] = cert_match.captures[4]
                                
                                class_attr = get_class(search_elem)
                                if occursin("Green", class_attr)
                                    data["certifications"]["environmental"]["status"] = "Valid"
                                elseif occursin("Red", class_attr)
                                    data["certifications"]["environmental"]["status"] = "Expired"
                                elseif occursin("Yellow", class_attr)
                                    data["certifications"]["environmental"]["status"] = "Warning"
                                end
                                
                                println("   📜 Environmental Cert: $(data["certifications"]["environmental"]["type"]) - $(data["certifications"]["environmental"]["status"])")
                                break
                            end
                        end
                    end
                catch e
                    println("   ⚠️  Error parsing Environmental Certification: $e")
                end
                break
            end
        end
    end
    
    # Extract Logistic Audit
    for (idx, elem) in enumerate(all_elements)
        if elem isa HTMLElement && tag(elem) == :strong
            elem_text = extract_text(elem)
            if occursin("Logistic Audit:", elem_text)
                try
                    for search_elem in all_elements[idx:min(idx+20, length(all_elements))]
                        if search_elem isa HTMLElement && tag(search_elem) == :div
                            div_text = extract_text(search_elem)
                            logistic_match = match(r"([A-Z])\s+(\d+)%,\s*Method:\s*([^,]+),\s*Version:\s*(\d+),\s*\((\d{4}-\d{2}-\d{2})\)", div_text)
                            if !isnothing(logistic_match)
                                data["certifications"]["logistic"]["grade"] = logistic_match.captures[1]
                                data["certifications"]["logistic"]["percentage"] = logistic_match.captures[2] * "%"
                                data["certifications"]["logistic"]["method"] = strip(logistic_match.captures[3])
                                data["certifications"]["logistic"]["version"] = logistic_match.captures[4]
                                data["certifications"]["logistic"]["performedDate"] = logistic_match.captures[5]
                                
                                class_attr = get_class(search_elem)
                                if occursin("Green", class_attr)
                                    data["certifications"]["logistic"]["status"] = "Pass"
                                elseif occursin("Red", class_attr)
                                    data["certifications"]["logistic"]["status"] = "Fail"
                                elseif occursin("Yellow", class_attr)
                                    data["certifications"]["logistic"]["status"] = "Warning"
                                end
                                
                                println("   📦 Logistic Audit: $(data["certifications"]["logistic"]["grade"]) $(data["certifications"]["logistic"]["percentage"]) - $(data["certifications"]["logistic"]["status"])")
                                break
                            end
                        end
                    end
                catch e
                    println("   ⚠️  Error parsing Logistic Audit: $e")
                end
                break
            end
        end
    end
    
    # Extract REACH EU Compliance
    for (idx, elem) in enumerate(all_elements)
        if elem isa HTMLElement && tag(elem) == :strong
            elem_text = extract_text(elem)
            if occursin("REACH EU Compliance:", elem_text)
                try
                    for search_elem in all_elements[idx:min(idx+20, length(all_elements))]
                        if search_elem isa HTMLElement && tag(search_elem) == :div
                            div_text = extract_text(search_elem)
                            if occursin("REACH", div_text)
                                if occursin("Compliant", div_text) && !occursin("Non-Compliant", div_text)
                                    data["certifications"]["reach"]["compliance"] = "Compliant"
                                elseif occursin("Non-Compliant", div_text)
                                    data["certifications"]["reach"]["compliance"] = "Non-Compliant"
                                end
                                
                                date_match = match(r"Evaluated:\s*(\d{4}-\d{2}-\d{2})", div_text)
                                if !isnothing(date_match)
                                    data["certifications"]["reach"]["evaluatedTime"] = date_match.captures[1]
                                end
                                
                                class_attr = get_class(search_elem)
                                if occursin("Green", class_attr)
                                    data["certifications"]["reach"]["status"] = "Pass"
                                elseif occursin("Red", class_attr)
                                    data["certifications"]["reach"]["status"] = "Fail"
                                elseif occursin("Yellow", class_attr)
                                    data["certifications"]["reach"]["status"] = "Warning"
                                end
                                
                                println("   ♻️  REACH: $(data["certifications"]["reach"]["compliance"]) ($(data["certifications"]["reach"]["evaluatedTime"]))")
                                break
                            end
                        end
                    end
                catch e
                    println("   ⚠️  Error parsing REACH: $e")
                end
                break
            end
        end
    end
    
    # Extract Sustainability Self-Assessment
    for (idx, elem) in enumerate(all_elements)
        if elem isa HTMLElement && tag(elem) == :strong
            elem_text = extract_text(elem)
            if occursin("Sustainability Self-Assessment:", elem_text)
                try
                    for search_elem in all_elements[idx:min(idx+20, length(all_elements))]
                        if search_elem isa HTMLElement && tag(search_elem) == :div
                            div_text = extract_text(search_elem)
                            sustainability_match = match(r"(\d+)%,\s*Evaluated:\s*(\d{4}-\d{2}-\d{2})", div_text)
                            if !isnothing(sustainability_match)
                                data["certifications"]["sustainability"]["percentage"] = sustainability_match.captures[1] * "%"
                                data["certifications"]["sustainability"]["evaluatedTime"] = sustainability_match.captures[2]
                                
                                class_attr = get_class(search_elem)
                                if occursin("Green", class_attr)
                                    data["certifications"]["sustainability"]["status"] = "Good"
                                elseif occursin("Red", class_attr)
                                    data["certifications"]["sustainability"]["status"] = "Poor"
                                elseif occursin("Yellow", class_attr)
                                    data["certifications"]["sustainability"]["status"] = "Fair"
                                end
                                
                                println("   🌱 Sustainability: $(data["certifications"]["sustainability"]["percentage"]) - $(data["certifications"]["sustainability"]["status"])")
                                break
                            end
                        end
                    end
                catch e
                    println("   ⚠️  Error parsing Sustainability: $e")
                end
                break
            end
        end
    end
    
    # Extract Capacity Documents
    capacity_panel = eachmatch(Selector("#CapacityAuditPanel"), doc.root)
    if !isempty(capacity_panel)
        capacity_text = extract_text(first(capacity_panel))
        if !occursin("No Capacity Documents", capacity_text)
            data["capacity"]["documents"] = capacity_text
            println("   📊 Capacity Documents: Present")
        else
            data["capacity"]["documents"] = "None"
        end
    end
    
    # Extract Capacity Risk Level and Supplier Status
    for (idx, elem) in enumerate(all_elements)
        if elem isa HTMLElement && tag(elem) == :strong
            elem_text = extract_text(elem)
            
            # Capacity Risk Level
            if occursin("Capacity Risk Level:", elem_text)
                try
                    for search_elem in all_elements[idx:min(idx+15, length(all_elements))]
                        if search_elem isa HTMLElement && tag(search_elem) == :div
                            risk_text = extract_text(search_elem)
                            if !occursin("No Capacity Risk Level", risk_text) && !isempty(risk_text) && risk_text != "N/A"
                                data["capacity"]["riskLevel"] = risk_text
                                println("   ⚠️  Capacity Risk: $risk_text")
                                break
                            end
                        end
                    end
                catch e
                    println("   ⚠️  Error parsing Capacity Risk: $e")
                end
            end
            
            # Low Performing Supplier
            if occursin("Low Performing Supplier:", elem_text)
                try
                    for search_elem in all_elements[idx:min(idx+15, length(all_elements))]
                        if search_elem isa HTMLElement && tag(search_elem) == :div
                            lps_text = extract_text(search_elem)
                            if occursin(r"High"i, lps_text)
                                data["supplierStatus"]["lowPerforming"] = "High"
                            elseif occursin(r"^Low$"i, lps_text)
                                data["supplierStatus"]["lowPerforming"] = "Low"
                            elseif occursin(r"^No$"i, lps_text)
                                data["supplierStatus"]["lowPerforming"] = "No"
                            end
                            
                            if data["supplierStatus"]["lowPerforming"] != "N/A"
                                println("   📉 Low Performing: $(data["supplierStatus"]["lowPerforming"])")
                                break
                            end
                        end
                    end
                catch e
                    println("   ⚠️  Error parsing Low Performing status: $e")
                end
            end
            
            # Warranty Severe Issues
            if occursin("Warranty Severe Issues:", elem_text)
                try
                    for search_elem in all_elements[idx:min(idx+20, length(all_elements))]
                        if search_elem isa HTMLElement && tag(search_elem) == :div
                            warranty_text = extract_text(search_elem)
                            if occursin(r"^Yes$"i, warranty_text)
                                data["supplierStatus"]["warrantySevereIssues"] = "Yes"
                                println("   ⚠️  Warranty Issues: Yes")
                                break
                            elseif occursin(r"^No$"i, warranty_text)
                                data["supplierStatus"]["warrantySevereIssues"] = "No"
                                println("   ✓ Warranty Issues: No")
                                break
                            end
                        end
                    end
                catch e
                    println("   ⚠️  Error parsing Warranty status: $e")
                end
            end
        end
    end
    
    # Extract APQP/PPAP status
    apqp_panel = eachmatch(Selector("#APQPPanel"), doc.root)
    if !isempty(apqp_panel)
        apqp_text = extract_text(first(apqp_panel))
        
        if occursin("Approved", apqp_text)
            data["apqp"] = "Approved"
        elseif occursin("Not Approved", apqp_text)
            data["apqp"] = "Not Approved"
        end
        
        println("   📋 APQP: $(data["apqp"])")
    end
    
    ppap_panel = eachmatch(Selector("#PPAPPanel"), doc.root)
    if !isempty(ppap_panel)
        ppap_text = extract_text(first(ppap_panel))
        
        if occursin("Approved", ppap_text)
            data["ppap"] = "Approved"
        elseif occursin("Not Approved", ppap_text)
            data["ppap"] = "Not Approved"
        end
        
        println("   📋 PPAP: $(data["ppap"])")
    end
    
    # Parse quality audits (SW Index, EE Index, SMA)
    quality_metrics = parse_quality_audits(doc)
    merge!(data["metrics"], quality_metrics)
    
    # Extract Performance Metrics (QPM, PPM) - Last Period vs Actual only
    performance_table = eachmatch(Selector("#tblSales2"), doc.root)
    if !isempty(performance_table)
        table = first(performance_table)
        rows = eachmatch(Selector("tr"), table)
        
        for row in rows
            cells = eachmatch(Selector("td"), row)
            length(cells) < 15 && continue
            
            brand_text = extract_text(cells[1])
            
            # Skip if it's header or empty
            (isempty(brand_text) || occursin("Brand/Consignee", brand_text) || brand_text == "&nbsp;") && continue
            
            # Extract PPM and QPM values
            try
                ppm_last = extract_text(cells[3])
                ppm_actual = extract_text(cells[4])
                qpm_last = extract_text(cells[7])
                qpm_actual = extract_text(cells[8])
                
                # If this is supplier total, use these values
                if occursin("Supplier Total", brand_text) || occursin("ShowHeading", get(attrs(row), "id", ""))
                    # Parse QPM values
                    try
                        qpm_last_val = tryparse(Float64, replace(qpm_last, r"[^0-9.-]" => ""))
                        qpm_actual_val = tryparse(Float64, replace(qpm_actual, r"[^0-9.-]" => ""))
                        
                        data["qpm"]["lastPeriod"] = isnothing(qpm_last_val) ? "N/A" : qpm_last
                        data["qpm"]["actual"] = isnothing(qpm_actual_val) ? "N/A" : qpm_actual
                        
                        # Calculate QPM change
                        if !isnothing(qpm_last_val) && !isnothing(qpm_actual_val)
                            qpm_change = qpm_actual_val - qpm_last_val
                            data["qpm"]["change"] = @sprintf("%+.1f", qpm_change)
                            
                            if qpm_last_val != 0
                                qpm_change_percent = (qpm_change / qpm_last_val) * 100
                                data["qpm"]["changePercent"] = @sprintf("%+.1f%%", qpm_change_percent)
                            end
                            
                            # Determine trend (note: for QPM, lower is better)
                            data["qpm"]["trend"] = if qpm_change > 0
                                "up"  # Worse
                            elseif qpm_change < 0
                                "down"  # Better
                            else
                                "neutral"
                            end
                        end
                    catch e
                        println("   ⚠️  Error parsing QPM values: $e")
                    end
                    
                    # Parse PPM values
                    try
                        ppm_last_val = tryparse(Float64, replace(ppm_last, r"[^0-9.-]" => ""))
                        ppm_actual_val = tryparse(Float64, replace(ppm_actual, r"[^0-9.-]" => ""))
                        
                        data["ppm"]["lastPeriod"] = isnothing(ppm_last_val) ? "N/A" : ppm_last
                        data["ppm"]["actual"] = isnothing(ppm_actual_val) ? "N/A" : ppm_actual
                        
                        # Calculate PPM change
                        if !isnothing(ppm_last_val) && !isnothing(ppm_actual_val)
                            ppm_change = ppm_actual_val - ppm_last_val
                            data["ppm"]["change"] = @sprintf("%+.1f", ppm_change)
                            
                            if ppm_last_val != 0
                                ppm_change_percent = (ppm_change / ppm_last_val) * 100
                                data["ppm"]["changePercent"] = @sprintf("%+.1f%%", ppm_change_percent)
                            end
                            
                            # Determine trend (note: for PPM, lower is better)
                            data["ppm"]["trend"] = if ppm_change > 0
                                "up"  # Worse
                            elseif ppm_change < 0
                                "down"  # Better
                            else
                                "neutral"
                            end
                        end
                    catch e
                        println("   ⚠️  Error parsing PPM values: $e")
                    end
                    
                    println("   📊 QPM: Last=$qpm_last → Actual=$qpm_actual ($(data["qpm"]["change"]))")
                    println("   📊 PPM: Last=$ppm_last → Actual=$ppm_actual ($(data["ppm"]["change"]))")
                end
            catch e
                println("   ⚠️  Error parsing performance metrics: $e")
                continue
            end
        end
    end
    
    # Fill in remaining audits if less than 6
    while length(data["audits"]) < 6
        push!(data["audits"], Dict(
            "title" => "N/A",
            "status" => "N/A",
            "statusClass" => "status-na",
            "date" => "N/A"
        ))
    end
    
    return (; (Symbol(k) => v for (k, v) in data)...)
end

"""
    generate_suppliers_index(suppliers_data::Vector, output_dir::String) -> String

Generate suppliers index JSON file
"""
function generate_suppliers_index(suppliers_data::Vector, output_dir::String)::String
    index = [Dict("id" => s.id, "parmaId" => s.parmaId, "name" => s.name) for s in suppliers_data]
    
    index_file = joinpath(output_dir, "suppliers_index.json")
    open(index_file, "w") do io
        write(io, JSON3.write(index))
    end
    
    println("\n📋 Generated suppliers index: $index_file")
    return index_file
end

"""
    generate_individual_supplier_json(supplier_data::NamedTuple, output_dir::String) -> String

Generate individual supplier JSON file
"""
function generate_individual_supplier_json(supplier_data::NamedTuple, output_dir::String)::String
    json_file = joinpath(output_dir, "supplier_$(supplier_data.id).json")
    
    open(json_file, "w") do io
        write(io, JSON3.write(supplier_data))
    end
    
    println("   💾 Generated: $json_file")
    return json_file
end

"""
    main(args::Vector{String}=String[])

Main function to process all supplier HTML files
"""
function main(args::Vector{String}=String[])
    println("=" ^ 70)
    println("VOLVO SUPPLIER SCORECARD PARSER (Julia)")
    println("=" ^ 70)
    
    # Configuration - use current directory
    current_dir = pwd()
    input_dir = joinpath(current_dir, "data")
    output_dir = joinpath(current_dir, "dashboard", "suppliers")
    
    # Allow command line arguments
    if length(args) >= 1
        input_dir = args[1]
    end
    if length(args) >= 2
        output_dir = args[2]
    end
    
    println("\n📂 Input directory: $input_dir")
    println("📂 Output directory: $output_dir")
    
    # Create output directory
    mkpath(output_dir)
    
    # Find all HTML files
    html_files = filter(f -> endswith(f, ".html"), readdir(input_dir))
    
    if isempty(html_files)
        println("\n❌ No HTML files found in $input_dir")
        return
    end
    
    println("\n🔍 Found $(length(html_files)) HTML files")
    println("=" ^ 70)
    
    # Parse all suppliers
    suppliers_data = []
    for html_file in html_files
        html_path = joinpath(input_dir, html_file)
        try
            supplier_data = parse_supplier_html(html_path)
            push!(suppliers_data, supplier_data)
            
            # Generate individual JSON file
            generate_individual_supplier_json(supplier_data, output_dir)
            
        catch e
            println("   ❌ Error parsing $html_file: $e")
            println(sprint(showerror, e, catch_backtrace()))
            continue
        end
        
        println()
    end
    
    # Generate suppliers index
    if !isempty(suppliers_data)
        generate_suppliers_index(suppliers_data, output_dir)
    end
    
    # Summary
    println("\n" * "=" ^ 70)
    println("✅ PROCESSING COMPLETE!")
    println("=" ^ 70)
    println("📊 Processed: $(length(suppliers_data)) suppliers")
    println("📁 Output: $output_dir")
end

# Run main if script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end