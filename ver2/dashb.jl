#!/usr/bin/env julia
#┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
#┃ 📁File      📄 dashb.jl                                                            ┃
#┃ 📙Brief     📝 Volvo Supplier Dashboard Generator                                  ┃
#┃ 🧾Details   🔎 Parses HTML, generates JSON, creates dashboard with templates       ┃
#┃ 🚩OAuthor   🦋 Original Author: Jaewoo Joung/정재우/郑在祐                         ┃
#┃ 👨‍🔧LAuthor   👤 Last Author: Jaewoo Joung                                         ┃
#┃ 📆LastDate  📍 2025-11-19 🔄Please support to keep update🔄                     ┃
#┃ 🏭License   📜 JSD:Just Simple Distribution(Jaewoo's Simple Distribution)        ┃
#┃ ✅Guarantee ⚠️ Explicitly UN-guaranteed                                          ┃
#┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

"""
    Volvo Supplier Dashboard Generator

Complete workflow:
1. Parse supplier HTML files from VSIB
2. Extract comprehensive supplier data (audits, certifications, metrics, QPM/PPM)
3. Generate JSON data files
4. Create HTML dashboard using templates

Features:
- SW Index expiration check (5 years)
- Quality & Environmental certifications
- REACH, Sustainability, Logistic audits
- Capacity and supplier status tracking
- QPM/PPM trend analysis
- SQE assignment display
"""

using Gumbo
using Cascadia
using JSON3
using Dates
using Printf
using AbstractTrees
using TOML

# ============================================================================
# HTML PARSING FUNCTIONS
# ============================================================================

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
    haskey(attrs(elem), "class") ? attrs(elem)["class"] : ""
end

"""
    parse_quality_audits(doc) -> Dict

Parse Quality Audits section (SW Index, EE Index, SMA, Polymer Index)
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
    
    audit_panel = eachmatch(Selector("#IndexAuditPanel"), doc.root)
    isempty(audit_panel) && return metrics
    
    audit_text = extract_text(first(audit_panel))
    println("   🔍 Quality Audits section found")
    
    # Extract SMA / Criticality 1 Index
    sma_match = match(r"SMA\s*/\s*Criticality\s+1\s+Index(.+?)(?:Software Index|EE Index|Polymer Index|$)"i, audit_text)
    if !isnothing(sma_match)
        sma_text = sma_match.captures[1]
        perc_match = match(r"(\d+)%", sma_text)
        !isnothing(perc_match) && (metrics["sma"] = perc_match.captures[1] * "%")
        
        occursin("Approved", sma_text) && (metrics["smaStatus"] = "Approved")
        occursin(r"Not [Aa]pproved", sma_text) && (metrics["smaStatus"] = "Not Approved")
        
        date_match = match(r"(\d{4}-\d{2}-\d{2})", sma_text)
        !isnothing(date_match) && (metrics["smaDate"] = date_match.captures[1])
        
        println("      ✓ SMA Index: $(metrics["sma"]) - $(metrics["smaStatus"]) ($(metrics["smaDate"]))")
    end
    
    # Extract Software Index with 5-year expiration check
    sw_match = match(r"Software\s+Index(.+?)(?:EE Index|Polymer Index|$)"i, audit_text)
    if !isnothing(sw_match)
        sw_text = sw_match.captures[1]
        perc_match = match(r"(\d+)%", sw_text)
        !isnothing(perc_match) && (metrics["swIndex"] = perc_match.captures[1] * "%")
        
        occursin("Approved", sw_text) && (metrics["swStatus"] = "Approved")
        occursin(r"Not [Aa]pproved", sw_text) && (metrics["swStatus"] = "Not Approved")
        
        date_match = match(r"(\d{4}-\d{2}-\d{2})", sw_text)
        if !isnothing(date_match)
            metrics["swDate"] = date_match.captures[1]
            
            # Check 5-year expiration for SW Index
            try
                sw_date = Date(date_match.captures[1])
                current_date = Dates.today()
                years_diff = (current_date - sw_date).value / 365.25
                
                if years_diff > 5.0 && metrics["swStatus"] == "Approved"
                    metrics["swStatus"] = "Expired"
                    println("      ⚠️  SW Index: $(metrics["swIndex"]) - EXPIRED ($(metrics["swDate"])) - MORE THAN 5 YEARS OLD")
                else
                    println("      ✓ SW Index: $(metrics["swIndex"]) - $(metrics["swStatus"]) ($(metrics["swDate"]))")
                end
            catch e
                println("      ⚠️  Could not parse SW Index date: $e")
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
        perc_match = match(r"(\d+)%", ee_text)
        !isnothing(perc_match) && (metrics["eeIndex"] = perc_match.captures[1] * "%")
        
        if occursin("Approved with conditions", ee_text)
            metrics["eeStatus"] = "Approved with conditions"
        elseif occursin("Approved", ee_text)
            metrics["eeStatus"] = "Approved"
        elseif occursin(r"Not [Aa]pproved", ee_text)
            metrics["eeStatus"] = "Not Approved"
        end
        
        occursin("Restriction", ee_text) && (metrics["eeStatus"] *= " (Restriction)")
        
        date_match = match(r"(\d{4}-\d{2}-\d{2})", ee_text)
        !isnothing(date_match) && (metrics["eeDate"] = date_match.captures[1])
        
        println("      ✓ EE Index: $(metrics["eeIndex"]) - $(metrics["eeStatus"]) ($(metrics["eeDate"]))")
    end
    
    # Extract Polymer Index
    polymer_match = match(r"Polymer\s+Index(.+?)$"i, audit_text)
    if !isnothing(polymer_match)
        polymer_text = polymer_match.captures[1]
        perc_match = match(r"(\d+)%", polymer_text)
        !isnothing(perc_match) && (metrics["polymerIndex"] = perc_match.captures[1] * "%")
        
        if occursin("Approved with conditions", polymer_text)
            metrics["polymerStatus"] = "Approved with conditions"
        elseif occursin("Approved", polymer_text)
            metrics["polymerStatus"] = "Approved"
        elseif occursin(r"Not [Aa]pproved", polymer_text)
            metrics["polymerStatus"] = "Not Approved"
        end
        
        date_match = match(r"(\d{4}-\d{2}-\d{2})", polymer_text)
        !isnothing(date_match) && (metrics["polymerDate"] = date_match.captures[1])
        
        println("      ✓ Polymer Index: $(metrics["polymerIndex"]) - $(metrics["polymerStatus"]) ($(metrics["polymerDate"]))")
    end
    
    return metrics
end

"""
    parse_supplier_html(html_file_path::String) -> NamedTuple

Parse Volvo supplier scorecard HTML file and extract all data
"""
function parse_supplier_html(html_file_path::String)::NamedTuple
    println("📄 Parsing: $html_file_path")
    
    html_content = read(html_file_path, String)
    doc = parsehtml(html_content)
    
    # Extract supplier ID and name
    supplier_link = eachmatch(Selector("a[href*='SupplierInformation.aspx']"), doc.root)
    supplier_info = isempty(supplier_link) ? "Unknown Supplier" : extract_text(first(supplier_link))
    
    supplier_id = "N/A"
    supplier_name = "Unknown"
    if occursin(',', supplier_info)
        parts = split(supplier_info, ',', limit=2)
        supplier_id = strip(parts[1])
        supplier_name = strip(parts[2])
    end
    
    println("   📋 Supplier: $supplier_name (ID: $supplier_id)")
    
    # Initialize data structure with all fields
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
            "swIndex" => "N/A", "swStatus" => "N/A", "swDate" => "N/A",
            "eeIndex" => "N/A", "eeStatus" => "N/A", "eeDate" => "N/A",
            "sma" => "N/A", "smaStatus" => "N/A", "smaDate" => "N/A",
            "polymerIndex" => "N/A", "polymerStatus" => "N/A", "polymerDate" => "N/A",
            "csr" => "N/A", "csrStatus" => "N/A", "csrDate" => "N/A",
            "saq" => "N/A", "saqStatus" => "N/A"
        ),
        "certifications" => Dict{String, Any}(
            "quality" => Dict("type" => "N/A", "certifiedPlace" => "N/A", "registratedTime" => "N/A", "expirationTime" => "N/A", "status" => "N/A"),
            "environmental" => Dict("type" => "N/A", "certifiedPlace" => "N/A", "registratedTime" => "N/A", "expirationTime" => "N/A", "status" => "N/A"),
            "logistic" => Dict("grade" => "N/A", "percentage" => "N/A", "method" => "N/A", "version" => "N/A", "performedDate" => "N/A", "status" => "N/A"),
            "reach" => Dict("compliance" => "N/A", "evaluatedTime" => "N/A", "status" => "N/A"),
            "sustainability" => Dict("percentage" => "N/A", "evaluatedTime" => "N/A", "status" => "N/A")
        ),
        "capacity" => Dict("documents" => "N/A", "riskLevel" => "N/A"),
        "supplierStatus" => Dict("lowPerforming" => "N/A", "warrantySevereIssues" => "N/A"),
        "qpm" => Dict("lastPeriod" => "N/A", "actual" => "N/A", "change" => "N/A", "changePercent" => "N/A", "trend" => "neutral"),
        "ppm" => Dict("lastPeriod" => "N/A", "actual" => "N/A", "change" => "N/A", "changePercent" => "N/A", "trend" => "neutral")
    )
    
    # Get all elements for tree traversal
    all_elements = collect(PreOrderDFS(doc.root))
    
    # Extract SEM audit
    sem_panel = eachmatch(Selector("#SEMPanelFollowup"), doc.root)
    if !isempty(sem_panel)
        sem_text = extract_text(first(sem_panel))
        status = occursin("Pass", sem_text) ? "Pass" : occursin("Fail", sem_text) ? "Fail" : "N/A"
        status_class = status == "Pass" ? "status-approved" : status == "Fail" ? "status-rejected" : "status-na"
        
        date_match = match(r"(\d{4}-\d{2}-\d{2})", sem_text)
        audit_date = isnothing(date_match) ? "N/A" : date_match.captures[1]
        
        push!(data["audits"], Dict("title" => "SEM Audit", "status" => status, "statusClass" => status_class, "date" => audit_date))
        println("   📋 SEM Audit: $status ($audit_date)")
    end
    
    # Extract certifications using tree traversal
    for (idx, elem) in enumerate(all_elements)
        if elem isa HTMLElement && tag(elem) == :strong
            elem_text = extract_text(elem)
            
            # Quality Certification
            if occursin("Quality Certification:", elem_text)
                try
                    for search_elem in all_elements[idx:min(idx+20, length(all_elements))]
                        if search_elem isa HTMLElement && tag(search_elem) == :div
                            div_text = extract_text(search_elem)
                            cert_match = match(r"([^,]+),\s*([^,]+),\s*Registrated:\s*(\d{4}-\d{2}-\d{2}),\s*Expire:\s*(\d{4}-\d{2}-\d{2})", div_text)
                            if !isnothing(cert_match)
                                data["certifications"]["quality"]["type"] = strip(cert_match.captures[1])
                                data["certifications"]["quality"]["certifiedPlace"] = strip(cert_match.captures[2])
                                data["certifications"]["quality"]["registratedTime"] = cert_match.captures[3]
                                data["certifications"]["quality"]["expirationTime"] = cert_match.captures[4]
                                
                                class_attr = get_class(search_elem)
                                data["certifications"]["quality"]["status"] = occursin("Green", class_attr) ? "Valid" : occursin("Red", class_attr) ? "Expired" : occursin("Yellow", class_attr) ? "Warning" : "N/A"
                                
                                println("   📜 Quality Cert: $(data["certifications"]["quality"]["type"]) - $(data["certifications"]["quality"]["status"])")
                                break
                            end
                        end
                    end
                catch e
                    println("   ⚠️  Error parsing Quality Certification: $e")
                end
            end
            
            # Environmental Certification
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
                                data["certifications"]["environmental"]["status"] = occursin("Green", class_attr) ? "Valid" : occursin("Red", class_attr) ? "Expired" : occursin("Yellow", class_attr) ? "Warning" : "N/A"
                                
                                println("   📜 Environmental Cert: $(data["certifications"]["environmental"]["type"]) - $(data["certifications"]["environmental"]["status"])")
                                break
                            end
                        end
                    end
                catch e
                    println("   ⚠️  Error parsing Environmental Certification: $e")
                end
            end
            
            # Logistic Audit
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
                                data["certifications"]["logistic"]["status"] = occursin("Green", class_attr) ? "Pass" : occursin("Red", class_attr) ? "Fail" : occursin("Yellow", class_attr) ? "Warning" : "N/A"
                                
                                println("   📦 Logistic: $(data["certifications"]["logistic"]["grade"]) $(data["certifications"]["logistic"]["percentage"])")
                                break
                            end
                        end
                    end
                catch e
                    println("   ⚠️  Error parsing Logistic Audit: $e")
                end
            end
            
            # REACH Compliance
            if occursin("REACH EU Compliance:", elem_text)
                try
                    for search_elem in all_elements[idx:min(idx+20, length(all_elements))]
                        if search_elem isa HTMLElement && tag(search_elem) == :div
                            div_text = extract_text(search_elem)
                            if occursin("REACH", div_text)
                                data["certifications"]["reach"]["compliance"] = occursin("Compliant", div_text) && !occursin("Non-Compliant", div_text) ? "Compliant" : occursin("Non-Compliant", div_text) ? "Non-Compliant" : "N/A"
                                
                                date_match = match(r"Evaluated:\s*(\d{4}-\d{2}-\d{2})", div_text)
                                !isnothing(date_match) && (data["certifications"]["reach"]["evaluatedTime"] = date_match.captures[1])
                                
                                class_attr = get_class(search_elem)
                                data["certifications"]["reach"]["status"] = occursin("Green", class_attr) ? "Pass" : occursin("Red", class_attr) ? "Fail" : occursin("Yellow", class_attr) ? "Warning" : "N/A"
                                
                                println("   ♻️  REACH: $(data["certifications"]["reach"]["compliance"])")
                                break
                            end
                        end
                    end
                catch e
                    println("   ⚠️  Error parsing REACH: $e")
                end
            end
            
            # Sustainability Self-Assessment
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
                                data["certifications"]["sustainability"]["status"] = occursin("Green", class_attr) ? "Good" : occursin("Red", class_attr) ? "Poor" : occursin("Yellow", class_attr) ? "Fair" : "N/A"
                                
                                println("   🌱 Sustainability: $(data["certifications"]["sustainability"]["percentage"])")
                                break
                            end
                        end
                    end
                catch e
                    println("   ⚠️  Error parsing Sustainability: $e")
                end
            end
            
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
                    println("   ⚠️  Error parsing Low Performing: $e")
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
                    println("   ⚠️  Error parsing Warranty: $e")
                end
            end
        end
    end
    
    # Extract Capacity Documents
    capacity_panel = eachmatch(Selector("#CapacityAuditPanel"), doc.root)
    if !isempty(capacity_panel)
        capacity_text = extract_text(first(capacity_panel))
        data["capacity"]["documents"] = occursin("No Capacity Documents", capacity_text) ? "None" : capacity_text
    end
    
    # Extract APQP/PPAP
    apqp_panel = eachmatch(Selector("#APQPPanel"), doc.root)
    if !isempty(apqp_panel)
        apqp_text = extract_text(first(apqp_panel))
        data["apqp"] = occursin("Approved", apqp_text) ? "Approved" : occursin("Not Approved", apqp_text) ? "Not Approved" : "N/A"
        println("   📋 APQP: $(data["apqp"])")
    end
    
    ppap_panel = eachmatch(Selector("#PPAPPanel"), doc.root)
    if !isempty(ppap_panel)
        ppap_text = extract_text(first(ppap_panel))
        data["ppap"] = occursin("Approved", ppap_text) ? "Approved" : occursin("Not Approved", ppap_text) ? "Not Approved" : "N/A"
        println("   📋 PPAP: $(data["ppap"])")
    end
    
    # Parse quality audits
    quality_metrics = parse_quality_audits(doc)
    merge!(data["metrics"], quality_metrics)
    
    # Extract Performance Metrics (QPM, PPM)
    performance_table = eachmatch(Selector("#tblSales2"), doc.root)
    if !isempty(performance_table)
        table = first(performance_table)
        rows = eachmatch(Selector("tr"), table)
        
        for row in rows
            cells = eachmatch(Selector("td"), row)
            length(cells) < 15 && continue
            
            brand_text = extract_text(cells[1])
            (isempty(brand_text) || occursin("Brand/Consignee", brand_text) || brand_text == "&nbsp;") && continue
            
            try
                ppm_last = extract_text(cells[3])
                ppm_actual = extract_text(cells[4])
                qpm_last = extract_text(cells[7])
                qpm_actual = extract_text(cells[8])
                
                if occursin("Supplier Total", brand_text) || occursin("ShowHeading", get(attrs(row), "id", ""))
                    # Parse QPM
                    try
                        qpm_last_val = tryparse(Float64, replace(qpm_last, r"[^0-9.-]" => ""))
                        qpm_actual_val = tryparse(Float64, replace(qpm_actual, r"[^0-9.-]" => ""))
                        
                        data["qpm"]["lastPeriod"] = isnothing(qpm_last_val) ? "N/A" : qpm_last
                        data["qpm"]["actual"] = isnothing(qpm_actual_val) ? "N/A" : qpm_actual
                        
                        if !isnothing(qpm_last_val) && !isnothing(qpm_actual_val)
                            qpm_change = qpm_actual_val - qpm_last_val
                            data["qpm"]["change"] = @sprintf("%+.1f", qpm_change)
                            
                            if qpm_last_val != 0
                                qpm_change_percent = (qpm_change / qpm_last_val) * 100
                                data["qpm"]["changePercent"] = @sprintf("%+.1f%%", qpm_change_percent)
                            end
                            
                            data["qpm"]["trend"] = qpm_change > 0 ? "up" : qpm_change < 0 ? "down" : "neutral"
                        end
                    catch e
                        println("   ⚠️  Error parsing QPM: $e")
                    end
                    
                    # Parse PPM
                    try
                        ppm_last_val = tryparse(Float64, replace(ppm_last, r"[^0-9.-]" => ""))
                        ppm_actual_val = tryparse(Float64, replace(ppm_actual, r"[^0-9.-]" => ""))
                        
                        data["ppm"]["lastPeriod"] = isnothing(ppm_last_val) ? "N/A" : ppm_last
                        data["ppm"]["actual"] = isnothing(ppm_actual_val) ? "N/A" : ppm_actual
                        
                        if !isnothing(ppm_last_val) && !isnothing(ppm_actual_val)
                            ppm_change = ppm_actual_val - ppm_last_val
                            data["ppm"]["change"] = @sprintf("%+.1f", ppm_change)
                            
                            if ppm_last_val != 0
                                ppm_change_percent = (ppm_change / ppm_last_val) * 100
                                data["ppm"]["changePercent"] = @sprintf("%+.1f%%", ppm_change_percent)
                            end
                            
                            data["ppm"]["trend"] = ppm_change > 0 ? "up" : ppm_change < 0 ? "down" : "neutral"
                        end
                    catch e
                        println("   ⚠️  Error parsing PPM: $e")
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
    
    # Fill remaining audits to 6
    while length(data["audits"]) < 6
        push!(data["audits"], Dict("title" => "N/A", "status" => "N/A", "statusClass" => "status-na", "date" => "N/A"))
    end
    
    return (; (Symbol(k) => v for (k, v) in data)...)
end

# ============================================================================
# HTML GENERATION FUNCTIONS
# ============================================================================

"""
    load_hr_database(hr_file::String) -> Vector

Load HR database from TOML file for SQE assignments
"""
function load_hr_database(hr_file::String="./conf/hr.toml")
    if !isfile(hr_file)
        println("⚠️  Warning: $hr_file not found, SQE names will not be shown")
        return nothing
    end
    
    println("📋 Loading HR database from: $hr_file")
    hr_data = TOML.parsefile(hr_file)
    people = hr_data["people"]
    println("   ✓ Loaded $(length(people)) people")
    return people
end

"""
    find_sqe_for_parma(parma_code::AbstractString, people) -> Vector

Find SQEs responsible for a PARMA code
"""
function find_sqe_for_parma(parma_code::AbstractString, people)
    people === nothing && return []
    
    # Convert parma_code to integer for comparison
    parma_int = tryparse(Int, parma_code)
    parma_int === nothing && return []
    
    sqes = []
    for person in people
        if haskey(person, "parma_codes") && parma_int in person["parma_codes"]
            push!(sqes, person)
        end
    end
    return sqes
end

"""
    calculate_qpm_statistics(suppliers_data::Vector) -> Tuple

Calculate QPM/PPM statistics across all suppliers
"""
function calculate_qpm_statistics(suppliers_data::Vector)
    total_suppliers = length(suppliers_data)
    qpm_over_50 = 0
    ppm_over_50 = 0
    qpm_sum_last = 0.0
    qpm_sum_actual = 0.0
    
    for supplier in suppliers_data
        # QPM actual
        qpm_data = get(supplier, :qpm, Dict())
        qpm_actual_str = get(qpm_data, "actual", "N/A")
        qpm_last_str = get(qpm_data, "lastPeriod", "N/A")
        
        qpm_actual_val = tryparse(Float64, qpm_actual_str)
        qpm_last_val = tryparse(Float64, qpm_last_str)
        
        if qpm_actual_val !== nothing
            qpm_sum_actual += qpm_actual_val
            qpm_actual_val > 50 && (qpm_over_50 += 1)
        end
        
        if qpm_last_val !== nothing
            qpm_sum_last += qpm_last_val
        end
        
        # PPM actual
        ppm_data = get(supplier, :ppm, Dict())
        ppm_actual_str = get(ppm_data, "actual", "N/A")
        ppm_actual_val = tryparse(Float64, ppm_actual_str)
        
        if ppm_actual_val !== nothing
            ppm_actual_val > 50 && (ppm_over_50 += 1)
        end
    end
    
    # PPM color class: red if > 0, black if 0
    ppm_color_class = ppm_over_50 > 0 ? "red" : "black"
    
    # Calculate average QPM ratios
    qpm_ratio_last = total_suppliers > 0 ? round(qpm_sum_last / total_suppliers, digits=1) : 0.0
    qpm_ratio_actual = total_suppliers > 0 ? round(qpm_sum_actual / total_suppliers, digits=1) : 0.0
    
    # Determine QPM trend (last to actual)
    # DOWN is GOOD (improvement), UP is BAD (deterioration)
    qpm_trend = if qpm_ratio_actual < qpm_ratio_last
        "down"  # Improvement - GOOD
    elseif qpm_ratio_actual > qpm_ratio_last
        "up"    # Deterioration - BAD
    else
        "neutral"
    end
    
    # Trend icon - Unicode arrows
    qpm_trend_icon = if qpm_trend == "down"
        "↓"  # Down arrow - GOOD
    elseif qpm_trend == "up"
        "↑"  # Up arrow - BAD
    else
        "→"  # Right arrow - Neutral
    end
    
    qpm_trend_text = if qpm_trend == "down"
        "Risk down"
    elseif qpm_trend == "up"
        "Risk up"
    else
        "Stable"
    end
    
    qpm_trend_class = qpm_trend
    
    return (qpm_over_50, ppm_over_50, ppm_color_class, qpm_ratio_actual, total_suppliers, qpm_trend, qpm_trend_icon, qpm_trend_text, qpm_trend_class)
end

"""
    load_template(template_file::String) -> String

Load HTML template from file
"""
function load_template(template_file::String)::String
    if !isfile(template_file)
        error("Template file not found: $template_file")
    end
    return read(template_file, String)
end

"""
    substitute_template(template::String, vars::Dict) -> String

Replace \$variables in template with values from dict
"""
function substitute_template(template::String, vars::Dict)::String
    result = template
    for (key, value) in vars
        result = replace(result, "\$$key" => string(value))
    end
    return result
end

"""
    generate_supplier_card(supplier, people) -> String

Generate HTML card for single supplier in index page
"""
function generate_supplier_card(supplier, people)::String
    supplier_id = get(supplier, :id, "N/A")
    supplier_name = get(supplier, :name, "Unknown")
    logo = get(supplier, :logo, "??")
    
    # Get QPM/PPM
    qpm_data = get(supplier, :qpm, Dict())
    ppm_data = get(supplier, :ppm, Dict())
    qpm_actual = get(qpm_data, "actual", "N/A")
    ppm_actual = get(ppm_data, "actual", "N/A")
    qpm_trend = get(qpm_data, "trend", "neutral")
    ppm_trend = get(ppm_data, "trend", "neutral")
    
    # Get metrics
    metrics = get(supplier, :metrics, Dict())
    sw_status = get(metrics, "swStatus", "N/A")
    ee_status = get(metrics, "eeStatus", "N/A")
    
    # Get SQEs
    sqes = find_sqe_for_parma(supplier_id, people)
    sqe_html = ""
    if !isempty(sqes)
        for sqe in sqes
            name = get(sqe, "name", "Unknown")
            email = get(sqe, "email", "")
            if !isempty(email)
                sqe_html *= """<div class="sqe-badge"><a href="mailto:$email" style="color: inherit; text-decoration: none;">👤 $name</a></div>"""
            else
                sqe_html *= """<div class="sqe-badge">👤 $name</div>"""
            end
        end
    end
    
    # Status badges
    sw_class = sw_status == "Approved" ? "badge-success" : sw_status == "Expired" ? "badge-danger" : "badge-secondary"
    ee_class = ee_status == "Approved" ? "badge-success" : ee_status == "Not Approved" ? "badge-danger" : "badge-secondary"
    
    qpm_class = qpm_trend == "down" ? "metric-good" : qpm_trend == "up" ? "metric-bad" : "metric-neutral"
    ppm_class = ppm_trend == "down" ? "metric-good" : ppm_trend == "up" ? "metric-bad" : "metric-neutral"
    
    return """
    <div class="supplier-card">
        <div class="supplier-header">
            <div class="supplier-logo">$logo</div>
            <div class="supplier-info">
                <h3><a href="supplier_$supplier_id.html">$supplier_name</a></h3>
                <div class="supplier-id">ID: $supplier_id</div>
            </div>
        </div>
        <div class="supplier-metrics">
            <div class="metric $qpm_class">
                <div class="metric-label">QPM</div>
                <div class="metric-value">$qpm_actual</div>
            </div>
            <div class="metric $ppm_class">
                <div class="metric-label">PPM</div>
                <div class="metric-value">$ppm_actual</div>
            </div>
        </div>
        <div class="supplier-status">
            <span class="badge $sw_class">SW: $sw_status</span>
            <span class="badge $ee_class">EE: $ee_status</span>
        </div>
        <div class="supplier-sqe">
            $sqe_html
        </div>
    </div>
    """
end

"""
    generate_audit_card(audit::Dict) -> String

Generate HTML for audit card in supplier page
"""
function generate_audit_card(audit::Dict)::String
    title = get(audit, "title", "N/A")
    status = get(audit, "status", "N/A")
    status_class = get(audit, "statusClass", "status-na")
    date = get(audit, "date", "N/A")
    
    return """
    <div class="audit-box">
        <div class="audit-title">$title</div>
        <div class="audit-status $status_class">$status</div>
        <div class="audit-date">$date</div>
    </div>
    """
end

"""
    generate_certification_section(certifications::Dict) -> String

Generate HTML section for certifications
"""
function generate_certification_section(certifications::Dict)::String
    quality = get(certifications, "quality", Dict())
    environmental = get(certifications, "environmental", Dict())
    logistic = get(certifications, "logistic", Dict())
    reach = get(certifications, "reach", Dict())
    sustainability = get(certifications, "sustainability", Dict())
    
    html = """<div class="certifications-section">"""
    
    # Quality Certification
    if get(quality, "type", "N/A") != "N/A"
        html *= """
        <div class="cert-item">
            <strong>Quality Cert:</strong> $(quality["type"]) | 
            $(quality["certifiedPlace"]) | 
            Registered: $(quality["registratedTime"]) | 
            Expires: $(quality["expirationTime"]) | 
            <span class="cert-status-$(quality["status"])">$(quality["status"])</span>
        </div>
        """
    end
    
    # Environmental Certification
    if get(environmental, "type", "N/A") != "N/A"
        html *= """
        <div class="cert-item">
            <strong>Environmental Cert:</strong> $(environmental["type"]) | 
            $(environmental["certifiedPlace"]) | 
            Registered: $(environmental["registratedTime"]) | 
            Expires: $(environmental["expirationTime"]) | 
            <span class="cert-status-$(environmental["status"])">$(environmental["status"])</span>
        </div>
        """
    end
    
    # Logistic Audit
    if get(logistic, "grade", "N/A") != "N/A"
        html *= """
        <div class="cert-item">
            <strong>Logistic Audit:</strong> Grade $(logistic["grade"]) $(logistic["percentage"]) | 
            Method: $(logistic["method"]) | Version: $(logistic["version"]) | 
            Performed: $(logistic["performedDate"]) | 
            <span class="cert-status-$(logistic["status"])">$(logistic["status"])</span>
        </div>
        """
    end
    
    # REACH Compliance
    if get(reach, "compliance", "N/A") != "N/A"
        html *= """
        <div class="cert-item">
            <strong>REACH EU:</strong> $(reach["compliance"]) | 
            Evaluated: $(reach["evaluatedTime"]) | 
            <span class="cert-status-$(reach["status"])">$(reach["status"])</span>
        </div>
        """
    end
    
    # Sustainability
    if get(sustainability, "percentage", "N/A") != "N/A"
        html *= """
        <div class="cert-item">
            <strong>Sustainability:</strong> $(sustainability["percentage"]) | 
            Evaluated: $(sustainability["evaluatedTime"]) | 
            <span class="cert-status-$(sustainability["status"])">$(sustainability["status"])</span>
        </div>
        """
    end
    
    html *= """</div>"""
    return html
end

"""
    generate_index_html(suppliers_data::Vector, output_dir::String, people, template_file::String)

Generate index.html dashboard
"""
function generate_index_html(suppliers_data::Vector, output_dir::String, people, template_file::String)
    println("\n📊 Generating index.html...")
    
    # Calculate statistics
    (qpm_over_50, ppm_over_50, ppm_color_class, qpm_ratio, total_suppliers, qpm_trend, qpm_trend_icon, qpm_trend_text, qpm_trend_class) = calculate_qpm_statistics(suppliers_data)
    
    # Generate supplier cards
    supplier_cards_html = ""
    for supplier in suppliers_data
        supplier_cards_html *= generate_supplier_card(supplier, people)
    end
    
    # Load and substitute template
    template = load_template(template_file)
    vars = Dict(
        "TOTAL_SUPPLIERS" => total_suppliers,
        "QPM_OVER_50" => qpm_over_50,
        "PPM_OVER_50" => ppm_over_50,
        "PPM_COLOR_CLASS" => ppm_color_class,
        "QPM_RATIO" => qpm_ratio,
        "QPM_TREND" => qpm_trend,
        "QPM_TREND_ICON" => qpm_trend_icon,
        "QPM_TREND_TEXT" => qpm_trend_text,
        "QPM_TREND_CLASS" => qpm_trend_class,
        "SUPPLIER_CARDS" => supplier_cards_html,
        "GENERATED_DATE" => Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
    )
    
    html_content = substitute_template(template, vars)
    
    # Save
    output_file = joinpath(output_dir, "index.html")
    open(output_file, "w") do f
        write(f, html_content)
    end
    
    println("   ✓ Generated: $output_file")
    println("   📊 Statistics: $total_suppliers suppliers | QPM>50: $qpm_over_50 | PPM>50: $ppm_over_50 ($ppm_color_class) | Trend: $qpm_trend_text ($qpm_trend_icon)")
end

"""
    generate_supplier_html(supplier, output_dir::String, people, template_file::String)

Generate individual supplier HTML page
"""
function generate_supplier_html(supplier, output_dir::String, people, template_file::String)
    supplier_id = get(supplier, :id, "N/A")
    supplier_name = get(supplier, :name, "Unknown")
    
    println("   📄 Generating supplier_$supplier_id.html...")
    
    # Get all data
    logo = get(supplier, :logo, "??")
    parma_id = get(supplier, :parmaId, "N/A")
    apqp = get(supplier, :apqp, "N/A")
    ppap = get(supplier, :ppap, "N/A")
    
    # Metrics
    metrics = get(supplier, :metrics, Dict())
    sw_index = get(metrics, "swIndex", "N/A")
    sw_status = get(metrics, "swStatus", "N/A")
    sw_date = get(metrics, "swDate", "N/A")
    ee_index = get(metrics, "eeIndex", "N/A")
    ee_status = get(metrics, "eeStatus", "N/A")
    ee_date = get(metrics, "eeDate", "N/A")
    sma = get(metrics, "sma", "N/A")
    sma_status = get(metrics, "smaStatus", "N/A")
    sma_date = get(metrics, "smaDate", "N/A")
    polymer_index = get(metrics, "polymerIndex", "N/A")
    polymer_status = get(metrics, "polymerStatus", "N/A")
    polymer_date = get(metrics, "polymerDate", "N/A")
    
    # QPM/PPM
    qpm_data = get(supplier, :qpm, Dict())
    ppm_data = get(supplier, :ppm, Dict())
    qpm_last = get(qpm_data, "lastPeriod", "N/A")
    qpm_actual = get(qpm_data, "actual", "N/A")
    qpm_change = get(qpm_data, "change", "N/A")
    qpm_trend = get(qpm_data, "trend", "neutral")
    ppm_last = get(ppm_data, "lastPeriod", "N/A")
    ppm_actual = get(ppm_data, "actual", "N/A")
    ppm_change = get(ppm_data, "change", "N/A")
    ppm_trend = get(ppm_data, "trend", "neutral")
    
    # Audits
    audits = get(supplier, :audits, [])
    audits_html = join([generate_audit_card(audit) for audit in audits], "\n")
    
    # Certifications
    certifications = get(supplier, :certifications, Dict())
    certifications_html = generate_certification_section(certifications)
    
    # Capacity
    capacity = get(supplier, :capacity, Dict())
    capacity_docs = get(capacity, "documents", "N/A")
    capacity_risk = get(capacity, "riskLevel", "N/A")
    
    # Supplier Status
    supplier_status = get(supplier, :supplierStatus, Dict())
    low_performing = get(supplier_status, "lowPerforming", "N/A")
    warranty_issues = get(supplier_status, "warrantySevereIssues", "N/A")
    
    # SQEs
    sqes = find_sqe_for_parma(parma_id, people)
    sqe_html = ""
    if !isempty(sqes)
        for sqe in sqes
            name = get(sqe, "name", "Unknown")
            email = get(sqe, "email", "")
            if !isempty(email)
                sqe_html *= """<div class="sqe-info"><i class="fas fa-user-tie"></i> <a href="mailto:$email" style="color: #3498db; text-decoration: none; font-weight: 600;">$name</a> <span style="color: #7f8c8d;">($email)</span></div>"""
            else
                sqe_html *= """<div class="sqe-info"><i class="fas fa-user-tie"></i> $name</div>"""
            end
        end
    else
        sqe_html = """<div class="sqe-info"><i class="fas fa-exclamation-circle"></i> No SQE assigned</div>"""
    end
    
    # Status classes
    sw_class = sw_status == "Approved" ? "status-approved" : sw_status == "Expired" ? "status-expired" : "status-na"
    ee_class = ee_status == "Approved" ? "status-approved" : "status-na"
    qpm_class = qpm_trend == "down" ? "trend-down" : qpm_trend == "up" ? "trend-up" : "trend-neutral"
    ppm_class = ppm_trend == "down" ? "trend-down" : ppm_trend == "up" ? "trend-up" : "trend-neutral"
    
    # Load and substitute template
    template = load_template(template_file)
    vars = Dict(
        "SUPPLIER_NAME" => supplier_name,
        "SUPPLIER_ID" => supplier_id,
        "SUPPLIER_LOGO" => logo,
        "PARMA_ID" => parma_id,
        "APQP" => apqp,
        "PPAP" => ppap,
        "SW_INDEX" => sw_index,
        "SW_STATUS" => sw_status,
        "SW_DATE" => sw_date,
        "SW_CLASS" => sw_class,
        "EE_INDEX" => ee_index,
        "EE_STATUS" => ee_status,
        "EE_DATE" => ee_date,
        "EE_CLASS" => ee_class,
        "SMA" => sma,
        "SMA_STATUS" => sma_status,
        "SMA_DATE" => sma_date,
        "POLYMER_INDEX" => polymer_index,
        "POLYMER_STATUS" => polymer_status,
        "POLYMER_DATE" => polymer_date,
        "QPM_LAST" => qpm_last,
        "QPM_ACTUAL" => qpm_actual,
        "QPM_CHANGE" => qpm_change,
        "QPM_CLASS" => qpm_class,
        "PPM_LAST" => ppm_last,
        "PPM_ACTUAL" => ppm_actual,
        "PPM_CHANGE" => ppm_change,
        "PPM_CLASS" => ppm_class,
        "AUDITS_HTML" => audits_html,
        "CERTIFICATIONS_HTML" => certifications_html,
        "CAPACITY_DOCS" => capacity_docs,
        "CAPACITY_RISK" => capacity_risk,
        "LOW_PERFORMING" => low_performing,
        "WARRANTY_ISSUES" => warranty_issues,
        "SQE_HTML" => sqe_html,
        "GENERATED_DATE" => Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
    )
    
    html_content = substitute_template(template, vars)
    
    # Save
    output_file = joinpath(output_dir, "supplier_$supplier_id.html")
    open(output_file, "w") do f
        write(f, html_content)
    end
end

# ============================================================================
# MAIN WORKFLOW
# ============================================================================

"""
    main(args::Vector{String})

Main workflow: Parse HTML → Generate JSON → Create Dashboard
"""
function main(args::Vector{String}=String[])
    println("=" ^ 80)
    println("VOLVO SUPPLIER DASHBOARD GENERATOR")
    println("=" ^ 80)
    
    # Configuration
    current_dir = pwd()
    input_dir = joinpath(current_dir, "data")
    json_output_dir = joinpath(current_dir, "dashboard", "suppliers")
    html_output_dir = joinpath(current_dir, "dashboard")
    template_dir = joinpath(current_dir, "temp")
    hr_file = joinpath(current_dir, "conf", "hr.toml")
    
    # Parse command line args
    if length(args) >= 1
        input_dir = args[1]
    end
    if length(args) >= 2
        html_output_dir = args[2]
    end
    
    println("\n📂 Input directory: $input_dir")
    println("📂 JSON output: $json_output_dir")
    println("📂 HTML output: $html_output_dir")
    println("📂 Templates: $template_dir")
    
    # Create directories
    mkpath(json_output_dir)
    mkpath(html_output_dir)
    
    # Find HTML files
    html_files = filter(f -> endswith(f, ".html"), readdir(input_dir))
    
    if isempty(html_files)
        println("\n❌ No HTML files found in $input_dir")
        return
    end
    
    println("\n🔍 Found $(length(html_files)) HTML files")
    println("=" ^ 80)
    
    # Parse all suppliers
    suppliers_data = []
    for html_file in html_files
        html_path = joinpath(input_dir, html_file)
        try
            supplier_data = parse_supplier_html(html_path)
            push!(suppliers_data, supplier_data)
            
            # Generate JSON
            json_file = joinpath(json_output_dir, "supplier_$(supplier_data.id).json")
            open(json_file, "w") do io
                write(io, JSON3.write(supplier_data))
            end
            println("   💾 Generated: $json_file")
            
        catch e
            println("   ❌ Error parsing $html_file: $e")
            println(sprint(showerror, e, catch_backtrace()))
            continue
        end
        
        println()
    end
    
    # Generate suppliers index JSON
    if !isempty(suppliers_data)
        index = [Dict("id" => s.id, "parmaId" => s.parmaId, "name" => s.name) for s in suppliers_data]
        index_file = joinpath(json_output_dir, "suppliers_index.json")
        open(index_file, "w") do io
            write(io, JSON3.write(index))
        end
        println("\n📋 Generated suppliers index: $index_file")
    end
    
    # Load HR database
    people = load_hr_database(hr_file)
    
    # Generate HTML dashboard
    println("\n" * "=" ^ 80)
    println("GENERATING HTML DASHBOARD")
    println("=" ^ 80)
    
    # Check templates
    index_template = joinpath(template_dir, "index.html")
    supplier_template = joinpath(template_dir, "supplier.html")
    
    if !isfile(index_template)
        println("❌ Error: Template not found: $index_template")
        println("   Please create template files in $template_dir")
        return
    end
    
    if !isfile(supplier_template)
        println("❌ Error: Template not found: $supplier_template")
        println("   Please create template files in $template_dir")
        return
    end
    
    # Generate index page
    generate_index_html(suppliers_data, html_output_dir, people, index_template)
    
    # Generate individual supplier pages
    for supplier in suppliers_data
        generate_supplier_html(supplier, html_output_dir, people, supplier_template)
    end
    
    # Summary
    println("\n" * "=" ^ 80)
    println("✅ DASHBOARD GENERATION COMPLETE!")
    println("=" ^ 80)
    println("📊 Processed: $(length(suppliers_data)) suppliers")
    println("📁 JSON files: $json_output_dir")
    println("📁 HTML dashboard: $html_output_dir")
    println("🌐 Open: $(joinpath(html_output_dir, "index.html"))")
end

# Run main if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end