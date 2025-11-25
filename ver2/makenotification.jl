#!/usr/bin/env julia
#┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
#┃ 📁File      📄 makenotification.jl                                                  ┃
#┃ 📙Brief     📝 Volvo Supplier Notification Queue Generator                          ┃
#┃ 🧾Details   🔎 Analyzes supplier data and generates email notification queue        ┃
#┃ 🚩OAuthor   🦋 Original Author: Jaewoo Joung/정재우/郑在祐                         ┃
#┃ 👨‍🔧LAuthor   👤 Last Author: Jaewoo Joung                                         ┃
#┃ 📆LastDate  📍 2025-11-20 🔄Please support to keep update🔄                     ┃
#┃ 🏭License   📜 JSD:Just Simple Distribution(Jaewoo's Simple Distribution)        ┃
#┃ ✅Guarantee ⚠️ Explicitly UN-guaranteed                                          ┃
#┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

using TOML
using JSON
using Dates

# Configuration
const HR_FILE = "./conf/hr.toml"
const SUPPLIER_DIR = "./dashboard/suppliers"
const OUTPUT_FILE = "./dashboard/notification/notify.toml"

# Load HR database
function load_hr_database()
    """Load people information from HR TOML file"""
    println("📋 Loading HR database from: $HR_FILE")
    
    if !isfile(HR_FILE)
        error("❌ HR file not found: $HR_FILE")
    end
    
    hr_data = TOML.parsefile(HR_FILE)
    people = hr_data["people"]
    println("   ✓ Loaded $(length(people)) people")
    return people
end

# Find SQE for a given PARMA code
function find_sqe_for_parma(parma_code, people)
    """Find SQE responsible for a specific PARMA code"""
    for person in people
        if haskey(person, "parma_codes") && parma_code in person["parma_codes"]
            return person
        end
    end
    return nothing
end

# Find manager
function find_manager(people)
    """Find the manager from people list"""
    for person in people
        if get(person, "role", "") == "manager"
            return person
        end
    end
    return nothing
end

# Generate notification ID
function generate_notification_id()
    """Generate unique notification ID"""
    return "NOTIF_$(Dates.format(now(), "yyyymmdd_HHMMSS"))_$(rand(1000:9999))"
end

# Create notification entry
function create_notification(notif_id, recipient, subject, body_text, priority, cc=nothing, bcc=nothing, metadata=Dict())
    """Create a notification dictionary"""
    notification = Dict(
        "id" => notif_id,
        "recipient" => recipient,
        "subject" => subject,
        "body_text" => body_text,
        "priority" => priority,
        "created_at" => Dates.format(now(), "yyyy-mm-dd HH:MM:SS"),
        "status" => "pending",
        "metadata" => metadata
    )
    
    if cc !== nothing
        notification["cc"] = cc
    end
    
    if bcc !== nothing
        notification["bcc"] = bcc
    end
    
    return notification
end

# Process QPM notifications
function process_qpm_notifications!(notifications, supplier_data, people, manager)
    """Generate QPM-related notifications based on Last Period vs Actual comparison"""
    println("\n📊 Processing QPM notifications...")
    
    parma_id = get(supplier_data, "parmaId", "UNKNOWN")
    parma_code = tryparse(Int, parma_id)
    supplier_name = get(supplier_data, "name", "Unknown Supplier")
    
    # Find responsible SQE
    sqe = nothing
    if parma_code !== nothing
        sqe = find_sqe_for_parma(parma_code, people)
    end
    
    if sqe === nothing
        println("   ⚠️  No SQE found for PARMA $parma_id - skipping")
        return
    end
    
    sqe_email = get(sqe, "email", "")
    sqe_name = get(sqe, "name", "SQE")
    
    # Get QPM data
    qpm_data = get(supplier_data, "qpm", Dict())
    qpm_last_str = string(get(qpm_data, "lastPeriod", "N/A"))
    qpm_actual_str = string(get(qpm_data, "actual", "N/A"))
    qpm_change_str = string(get(qpm_data, "change", "N/A"))
    qpm_change_percent = string(get(qpm_data, "changePercent", "N/A"))
    
    # Parse to float
    qpm_last = tryparse(Float64, qpm_last_str)
    qpm_actual = tryparse(Float64, qpm_actual_str)
    
    if qpm_last === nothing || qpm_actual === nothing
        println("   ⚠️  No valid QPM data for PARMA $parma_id")
        return
    end
    
    println("   📈 PARMA $parma_id: QPM $qpm_last → $qpm_actual")
    
    # Check for 10% increase
    if qpm_actual >= qpm_last * 1.1 && qpm_last > 0
        notif_id = generate_notification_id()
        subject = "QPM Alert: 10% Increase for PARMA $parma_id"
        body = """
        <html>
        <body style="font-family: Arial, sans-serif;">
            <h2 style="color: #0066cc;">QPM Score Increase Alert</h2>
            <p>Dear $sqe_name,</p>
            <p>Please note that Supplier Partner under <a href="https://vsib.srv.volvo.com/vsib/Content/sus/SupplierScorecard.aspx?SupplierId=$parma_id" title="Supplier scorecard of $parma_id"><strong>PARMA $parma_id</strong></a> ($supplier_name) has increased the QPM score by more than 10%.</p>
            <table style="border-collapse: collapse; margin: 20px 0;">
                <tr>
                    <td style="padding: 8px; border: 1px solid #ddd;"><strong>Last Period QPM:</strong></td>
                    <td style="padding: 8px; border: 1px solid #ddd;">$qpm_last</td>
                </tr>
                <tr>
                    <td style="padding: 8px; border: 1px solid #ddd;"><strong>Actual QPM:</strong></td>
                    <td style="padding: 8px; border: 1px solid #ddd;">$qpm_actual</td>
                </tr>
                <tr>
                    <td style="padding: 8px; border: 1px solid #ddd;"><strong>Change:</strong></td>
                    <td style="padding: 8px; border: 1px solid #ddd;">$qpm_change_str ($qpm_change_percent)</td>
                </tr>
            </table>
            <p><strong>Action Required:</strong> Please investigate the root cause and coordinate with the supplier.</p>
            <p>Best regards,<br>QPrism</p>
<hr style="border: none; border-top: 1px solid #ddd; margin: 20px 0;">
<p style="font-size: 12px; color: #666;">
    If QPrism isn't for you, please 
    <a href="mailto:81147176.groups.volvo.com@emea.teams.ms?subject=Unsubscribe%20from%20QPrism&body=Hello%20QPrism%20Admin%2C%0A%0AI%20would%20like%20to%20unsubscribe%20from%20QPrism%20notifications.%0A%0ARegards" 
       style="color: #0066cc; text-decoration: none;">
        unsubscribe
    </a>
</p>
        </body>
        </html>
        """
        
        push!(notifications, create_notification(
            notif_id, sqe_email, subject, body, 3,
            nothing, nothing,
            Dict("type" => "qpm_increase_10", "parma_id" => parma_id, "qpm_actual" => qpm_actual)
        ))
        println("   ✓ Added: QPM 10% increase notification for $sqe_name")
    end
    
    # Check QPM ranges based on Actual value
    if qpm_actual >= 30 && qpm_actual <= 50
        notif_id = generate_notification_id()
        subject = "QPM Warning: Approaching 50 for PARMA $parma_id"
        body = """
        <html>
        <body style="font-family: Arial, sans-serif;">
            <h2 style="color: #ff9900;">QPM Warning</h2>
            <p>Dear $sqe_name,</p>
            <p>Please note that the Supplier Partner under <a href="https://vsib.srv.volvo.com/vsib/Content/sus/SupplierScorecard.aspx?SupplierId=$parma_id" title="Supplier scorecard of $parma_id"><strong>PARMA $parma_id</strong></a> ($supplier_name) has a QPM close to 50.</p>
            <table style="border-collapse: collapse; margin: 20px 0;">
                <tr>
                    <td style="padding: 8px; border: 1px solid #ddd;"><strong>Last Period QPM:</strong></td>
                    <td style="padding: 8px; border: 1px solid #ddd;">$qpm_last</td>
                </tr>
                <tr>
                    <td style="padding: 8px; border: 1px solid #ddd;"><strong>Actual QPM:</strong></td>
                    <td style="padding: 8px; border: 1px solid #ddd;"><strong style="color: #ff9900;">$qpm_actual</strong></td>
                </tr>
            </table>
            <p style="color: #cc0000;"><strong>Action Required:</strong> Please take the necessary actions to address this situation.</p>
            <p>Best regards,<br>QPrism</p>
<hr style="border: none; border-top: 1px solid #ddd; margin: 20px 0;">
<p style="font-size: 12px; color: #666;">
    If QPrism isn't for you, please 
    <a href="mailto:81147176.groups.volvo.com@emea.teams.ms?subject=Unsubscribe%20from%20QPrism&body=Hello%20QPrism%20Admin%2C%0A%0AI%20would%20like%20to%20unsubscribe%20from%20QPrism%20notifications.%0A%0ARegards" 
       style="color: #0066cc; text-decoration: none;">
        unsubscribe
    </a>
</p>
        </body>
        </html>
        """
        
        push!(notifications, create_notification(
            notif_id, sqe_email, subject, body, 2,
            nothing, nothing,
            Dict("type" => "qpm_warning_30_50", "parma_id" => parma_id, "qpm_actual" => qpm_actual)
        ))
        println("   ✓ Added: QPM Warning (30-50) notification for $sqe_name")
        
    elseif qpm_actual > 50
        notif_id = generate_notification_id()
        subject = "URGENT: QPM Over 50 for PARMA $parma_id - LPS Actions Required"
        
        manager_email = manager !== nothing ? get(manager, "email", "") : ""
        manager_name = manager !== nothing ? get(manager, "name", "Manager") : "Manager"
        
        body = """
        <html>
        <body style="font-family: Arial, sans-serif;">
            <h2 style="color: #cc0000;">🚨 URGENT: QPM Over 50</h2>
            <p>Dear $sqe_name,</p>
            <p>Please note that the Supplier Partner under <a href="https://vsib.srv.volvo.com/vsib/Content/sus/SupplierScorecard.aspx?SupplierId=$parma_id" title="Supplier scorecard of $parma_id"><strong>PARMA $parma_id</strong></a> ($supplier_name) has exceeded QPM threshold of 50.</p>
            <table style="border-collapse: collapse; margin: 20px 0;">
                <tr>
                    <td style="padding: 8px; border: 1px solid #ddd;"><strong>Last Period QPM:</strong></td>
                    <td style="padding: 8px; border: 1px solid #ddd;">$qpm_last</td>
                </tr>
                <tr>
                    <td style="padding: 8px; border: 1px solid #ddd;"><strong>Actual QPM:</strong></td>
                    <td style="padding: 8px; border: 1px solid #ddd;"><strong style="color: #cc0000;">$qpm_actual</strong></td>
                </tr>
            </table>
            <p style="color: #cc0000; font-weight: bold;">⚠️ CRITICAL ACTION REQUIRED:</p>
            <ul>
                <li>Initiate LPS (Local Problem Solving) immediately</li>
                <li>Schedule supplier meeting within 48 hours</li>
                <li>Prepare containment action plan</li>
                <li>Inform management ($manager_name)</li>
            </ul>
            <p>Best regards,<br>QPrism</p>
<hr style="border: none; border-top: 1px solid #ddd; margin: 20px 0;">
<p style="font-size: 12px; color: #666;">
    If QPrism isn't for you, please 
    <a href="mailto:81147176.groups.volvo.com@emea.teams.ms?subject=Unsubscribe%20from%20QPrism&body=Hello%20QPrism%20Admin%2C%0A%0AI%20would%20like%20to%20unsubscribe%20from%20QPrism%20notifications.%0A%0ARegards" 
       style="color: #0066cc; text-decoration: none;">
        unsubscribe
    </a>
</p>
        </body>
        </html>
        """
        
        # CC to manager if available
        cc_list = manager_email != "" ? [manager_email] : nothing
        
        push!(notifications, create_notification(
            notif_id, sqe_email, subject, body, 1,
            cc_list, nothing,
            Dict("type" => "qpm_critical_over_50", "parma_id" => parma_id, "qpm_actual" => qpm_actual)
        ))
        println("   ✓ Added: CRITICAL QPM >50 notification for $sqe_name (CC: $manager_name)")
    end
end

# Process audit notifications
function process_audit_notifications!(notifications, supplier_data, people)
    """Generate audit expiry notifications (excluding SEM Audit)"""
    println("\n📋 Processing audit notifications...")
    
    parma_id = get(supplier_data, "parmaId", "UNKNOWN")
    parma_code = tryparse(Int, parma_id)
    supplier_name = get(supplier_data, "name", "Unknown Supplier")
    
    # Find responsible SQE
    sqe = nothing
    if parma_code !== nothing
        sqe = find_sqe_for_parma(parma_code, people)
    end
    
    if sqe === nothing
        println("   ⚠️  No SQE found for PARMA $parma_id - skipping")
        return
    end
    
    sqe_email = get(sqe, "email", "")
    sqe_name = get(sqe, "name", "SQE")
    
    # Get audit data
    audits = get(supplier_data, "audits", [])
    
    if isempty(audits)
        println("   ⚠️  No audit data for PARMA $parma_id")
        return
    end
    
    # Process each audit
    for audit in audits
        audit_title = get(audit, "title", "N/A")
        audit_date_str = get(audit, "date", "N/A")
        audit_status = get(audit, "status", "N/A")
        
        # Skip N/A entries and SEM Audit (no notification needed)
        if audit_title == "N/A" || audit_date_str == "N/A" || audit_title == "" || occursin("SEM Audit", audit_title)
            continue
        end
        
        try
            # Parse date
            audit_date = Date(audit_date_str, "yyyy-mm-dd")
            today = Date(now())
            days_until_expiry = Dates.value(audit_date - today)
            
            println("   📅 $audit_title: $audit_date_str ($(days_until_expiry) days)")
            
            # 6 months warning (180 days)
            if days_until_expiry <= 180 && days_until_expiry > 90
                notif_id = generate_notification_id()
                subject = "Audit Expiry Notice: 6 Months - PARMA $parma_id"
                body = """
                <html>
                <body style="font-family: Arial, sans-serif;">
                    <h2 style="color: #0066cc;">📋 Audit Expiry Notice</h2>
                    <p>Dear $sqe_name,</p>
                    <p>Please note that the Audit <strong>$audit_title</strong> under the Supplier Partner <strong>(PARMA $parma_id)</strong> ($supplier_name) will expire within 6 months.</p>
                    <p><strong>Expiry Date:</strong> $audit_date_str</p>
                    <p><strong>Days Remaining:</strong> $days_until_expiry days</p>
                    <p><strong>Action Required:</strong> Please plan for audit renewal.</p>
                    <p>Best regards,<br>QPrism</p>
<hr style="border: none; border-top: 1px solid #ddd; margin: 20px 0;">
<p style="font-size: 12px; color: #666;">
    If QPrism isn't for you, please 
    <a href="mailto:81147176.groups.volvo.com@emea.teams.ms?subject=Unsubscribe%20from%20QPrism&body=Hello%20QPrism%20Admin%2C%0A%0AI%20would%20like%20to%20unsubscribe%20from%20QPrism%20notifications.%0A%0ARegards" 
       style="color: #0066cc; text-decoration: none;">
        unsubscribe
    </a>
</p>
                </body>
                </html>
                """
                
                push!(notifications, create_notification(
                    notif_id, sqe_email, subject, body, 3,
                    nothing, nothing,
                    Dict("type" => "audit_expiry_6months", "parma_id" => parma_id, "audit_name" => audit_title, "days_remaining" => days_until_expiry)
                ))
                println("   ✓ Added: 6-month audit expiry for $audit_title")
                
            # 3 months warning (90 days)
            elseif days_until_expiry <= 90 && days_until_expiry > 0
                notif_id = generate_notification_id()
                subject = "Audit Expiry Warning: 3 Months - PARMA $parma_id"
                body = """
                <html>
                <body style="font-family: Arial, sans-serif;">
                    <h2 style="color: #ff9900;">⚠️ Audit Expiry Warning</h2>
                    <p>Dear $sqe_name,</p>
                    <p>Please note that the Audit <strong>$audit_title</strong> under the Supplier Partner <strong>(PARMA $parma_id)</strong> ($supplier_name) will expire within 3 months.</p>
                    <p><strong>Expiry Date:</strong> $audit_date_str</p>
                    <p><strong>Days Remaining:</strong> $days_until_expiry days</p>
                    <p style="color: #ff9900;"><strong>Action Required:</strong> Please expedite renewal process.</p>
                    <p>Best regards,<br>QPrism</p>
<hr style="border: none; border-top: 1px solid #ddd; margin: 20px 0;">
<p style="font-size: 12px; color: #666;">
    If QPrism isn't for you, please 
    <a href="mailto:81147176.groups.volvo.com@emea.teams.ms?subject=Unsubscribe%20from%20QPrism&body=Hello%20QPrism%20Admin%2C%0A%0AI%20would%20like%20to%20unsubscribe%20from%20QPrism%20notifications.%0A%0ARegards" 
       style="color: #0066cc; text-decoration: none;">
        unsubscribe
    </a>
</p>
                </body>
                </html>
                """
                
                push!(notifications, create_notification(
                    notif_id, sqe_email, subject, body, 2,
                    nothing, nothing,
                    Dict("type" => "audit_expiry_3months", "parma_id" => parma_id, "audit_name" => audit_title, "days_remaining" => days_until_expiry)
                ))
                println("   ✓ Added: 3-month audit expiry for $audit_title")
                
            # Expired audit
            elseif days_until_expiry <= 0
                days_expired = abs(days_until_expiry)
                notif_id = generate_notification_id()
                subject = "URGENT: Audit EXPIRED - PARMA $parma_id"
                body = """
                <html>
                <body style="font-family: Arial, sans-serif;">
                    <h2 style="color: #cc0000;">🚨 URGENT: Audit Expired</h2>
                    <p>Dear $sqe_name,</p>
                    <p>Please note that the Audit <strong>$audit_title</strong> under the Supplier Partner <strong>(PARMA $parma_id)</strong> ($supplier_name) is <span style="color: #cc0000; font-weight: bold;">EXPIRED</span>.</p>
                    <p><strong>Expired On:</strong> $audit_date_str</p>
                    <p><strong>Days Expired:</strong> $days_expired days</p>
                    <p style="color: #cc0000; font-weight: bold;">⚠️ IMMEDIATE ACTION REQUIRED</p>
                    <p>Best regards,<br>QPrism</p>
<hr style="border: none; border-top: 1px solid #ddd; margin: 20px 0;">
<p style="font-size: 12px; color: #666;">
    If QPrism isn't for you, please 
    <a href="mailto:81147176.groups.volvo.com@emea.teams.ms?subject=Unsubscribe%20from%20QPrism&body=Hello%20QPrism%20Admin%2C%0A%0AI%20would%20like%20to%20unsubscribe%20from%20QPrism%20notifications.%0A%0ARegards" 
       style="color: #0066cc; text-decoration: none;">
        unsubscribe
    </a>
</p>
                </body>
                </html>
                """
                
                push!(notifications, create_notification(
                    notif_id, sqe_email, subject, body, 1,
                    nothing, nothing,
                    Dict("type" => "audit_expired", "parma_id" => parma_id, "audit_name" => audit_title, "days_expired" => days_expired)
                ))
                println("   ✓ Added: EXPIRED audit notification for $audit_title")
            end
            
            # Check for conditional approval
            if occursin("with conditions", lowercase(audit_status)) || occursin("not approved", lowercase(audit_status))
                notif_id = generate_notification_id()
                subject = "Index Audit Status: $audit_status - PARMA $parma_id"
                body = """
                <html>
                <body style="font-family: Arial, sans-serif;">
                    <h2 style="color: #ff9900;">Index Audit Status Notification</h2>
                    <p>Dear $sqe_name,</p>
                    <p>Please note that the Index Audit <strong>$audit_title</strong> under the Supplier Partner <strong>(PARMA $parma_id)</strong> ($supplier_name) is in <strong>$audit_status</strong> status.</p>
                    <p>Please review the audit findings and coordinate improvement actions with the supplier.</p>
                    <p>Best regards,<br>QPrism</p>
<hr style="border: none; border-top: 1px solid #ddd; margin: 20px 0;">
<p style="font-size: 12px; color: #666;">
    If QPrism isn't for you, please 
    <a href="mailto:81147176.groups.volvo.com@emea.teams.ms?subject=Unsubscribe%20from%20QPrism&body=Hello%20QPrism%20Admin%2C%0A%0AI%20would%20like%20to%20unsubscribe%20from%20QPrism%20notifications.%0A%0ARegards" 
       style="color: #0066cc; text-decoration: none;">
        unsubscribe
    </a>
</p>
                </body>
                </html>
                """
                
                push!(notifications, create_notification(
                    notif_id, sqe_email, subject, body, 3,
                    nothing, nothing,
                    Dict("type" => "audit_conditional", "parma_id" => parma_id, "audit_name" => audit_title, "status" => audit_status)
                ))
                println("   ✓ Added: Conditional audit status for $audit_title")
            end
            
        catch e
            println("   ⚠️  Error parsing date for $audit_title: $e")
            continue
        end
    end
end

# Process SW index 5-year assessment notifications
function process_sw_index_notifications!(notifications, supplier_data, people)
    """Generate SW index 5-year assessment notifications"""
    println("\n🔧 Processing SW index assessment notifications...")
    
    parma_id = get(supplier_data, "parmaId", "UNKNOWN")
    parma_code = tryparse(Int, parma_id)
    supplier_name = get(supplier_data, "name", "Unknown Supplier")
    
    # Find responsible SQE
    sqe = nothing
    if parma_code !== nothing
        sqe = find_sqe_for_parma(parma_code, people)
    end
    
    if sqe === nothing
        println("   ⚠️  No SQE found for PARMA $parma_id - skipping")
        return
    end
    
    sqe_email = get(sqe, "email", "")
    sqe_name = get(sqe, "name", "SQE")
    
    # Get metrics data for SW index
    metrics = get(supplier_data, "metrics", Dict())
    sw_date_str = get(metrics, "swDate", "N/A")
    sw_status = get(metrics, "swStatus", "N/A")
    sw_index = get(metrics, "swIndex", "N/A")
    
    # Skip if no SW date
    if sw_date_str == "N/A" || sw_date_str == ""
        println("   ⚠️  No SW index date for PARMA $parma_id")
        return
    end
    
    try
        # Parse SW assessment date
        sw_date = Date(sw_date_str, "yyyy-mm-dd")
        today = Date(now())
        
        # Calculate years since assessment
        years_since = Dates.value(today - sw_date) / 365.25
        days_since = Dates.value(today - sw_date)
        
        # Calculate days until 5-year mark
        five_year_date = sw_date + Year(5)
        days_until_5years = Dates.value(five_year_date - today)
        
        println("   📅 SW Index: $sw_date_str ($(round(years_since, digits=1)) years ago)")
        
        # 5 years passed - needs re-assessment
        if years_since >= 5.0
            notif_id = generate_notification_id()
            subject = "URGENT: SW Index 5-Year Assessment Required - PARMA $parma_id"
            body = """
            <html>
            <body style="font-family: Arial, sans-serif;">
                <h2 style="color: #cc0000;">🚨 URGENT: SW Index 5-Year Assessment Required</h2>
                <p>Dear $sqe_name,</p>
                <p>Please note that the SW Index assessment for Supplier Partner <a href="https://vsib.srv.volvo.com/vsib/Content/sus/SupplierScorecard.aspx?SupplierId=$parma_id" title="Supplier scorecard of $parma_id"><strong>PARMA $parma_id</strong></a> ($supplier_name) requires re-assessment as 5 years have passed.</p>
                <table style="border-collapse: collapse; margin: 20px 0;">
                    <tr>
                        <td style="padding: 8px; border: 1px solid #ddd;"><strong>Last Assessment Date:</strong></td>
                        <td style="padding: 8px; border: 1px solid #ddd;">$sw_date_str</td>
                    </tr>
                    <tr>
                        <td style="padding: 8px; border: 1px solid #ddd;"><strong>Years Since Assessment:</strong></td>
                        <td style="padding: 8px; border: 1px solid #ddd;"><strong style="color: #cc0000;">$(round(years_since, digits=1)) years</strong></td>
                    </tr>
                    <tr>
                        <td style="padding: 8px; border: 1px solid #ddd;"><strong>Current SW Index:</strong></td>
                        <td style="padding: 8px; border: 1px solid #ddd;">$sw_index</td>
                    </tr>
                    <tr>
                        <td style="padding: 8px; border: 1px solid #ddd;"><strong>Current Status:</strong></td>
                        <td style="padding: 8px; border: 1px solid #ddd;">$sw_status</td>
                    </tr>
                </table>
                <p style="color: #cc0000; font-weight: bold;">⚠️ IMMEDIATE ACTION REQUIRED:</p>
                <ul>
                    <li>Schedule SW Index re-assessment</li>
                    <li>Update supplier evaluation status</li>
                    <li>Coordinate with supplier for documentation update</li>
                </ul>
                <p>Best regards,<br>QPrism</p>
<hr style="border: none; border-top: 1px solid #ddd; margin: 20px 0;">
<p style="font-size: 12px; color: #666;">
    If QPrism isn't for you, please 
    <a href="mailto:81147176.groups.volvo.com@emea.teams.ms?subject=Unsubscribe%20from%20QPrism&body=Hello%20QPrism%20Admin%2C%0A%0AI%20would%20like%20to%20unsubscribe%20from%20QPrism%20notifications.%0A%0ARegards" 
       style="color: #0066cc; text-decoration: none;">
        unsubscribe
    </a>
</p>
            </body>
            </html>
            """
            
            push!(notifications, create_notification(
                notif_id, sqe_email, subject, body, 1,
                nothing, nothing,
                Dict("type" => "sw_index_5year_overdue", "parma_id" => parma_id, "years_since" => round(years_since, digits=1), "last_date" => sw_date_str)
            ))
            println("   ✓ Added: SW Index 5-year overdue notification")
            
        # Approaching 5 years (within 3 months)
        elseif days_until_5years <= 90 && days_until_5years > 0
            notif_id = generate_notification_id()
            subject = "SW Index 5-Year Assessment Due Soon - PARMA $parma_id"
            body = """
            <html>
            <body style="font-family: Arial, sans-serif;">
                <h2 style="color: #ff9900;">⚠️ SW Index 5-Year Assessment Approaching</h2>
                <p>Dear $sqe_name,</p>
                <p>Please note that the SW Index assessment for Supplier Partner <a href="https://vsib.srv.volvo.com/vsib/Content/sus/SupplierScorecard.aspx?SupplierId=$parma_id" title="Supplier scorecard of $parma_id"><strong>PARMA $parma_id</strong></a> ($supplier_name) will reach the 5-year mark soon.</p>
                <table style="border-collapse: collapse; margin: 20px 0;">
                    <tr>
                        <td style="padding: 8px; border: 1px solid #ddd;"><strong>Last Assessment Date:</strong></td>
                        <td style="padding: 8px; border: 1px solid #ddd;">$sw_date_str</td>
                    </tr>
                    <tr>
                        <td style="padding: 8px; border: 1px solid #ddd;"><strong>5-Year Mark Date:</strong></td>
                        <td style="padding: 8px; border: 1px solid #ddd;">$(Dates.format(five_year_date, "yyyy-mm-dd"))</td>
                    </tr>
                    <tr>
                        <td style="padding: 8px; border: 1px solid #ddd;"><strong>Days Remaining:</strong></td>
                        <td style="padding: 8px; border: 1px solid #ddd;"><strong style="color: #ff9900;">$days_until_5years days</strong></td>
                    </tr>
                    <tr>
                        <td style="padding: 8px; border: 1px solid #ddd;"><strong>Current SW Index:</strong></td>
                        <td style="padding: 8px; border: 1px solid #ddd;">$sw_index</td>
                    </tr>
                </table>
                <p style="color: #ff9900;"><strong>Action Required:</strong> Please plan for SW Index re-assessment.</p>
                <p>Best regards,<br>QPrism</p>
<hr style="border: none; border-top: 1px solid #ddd; margin: 20px 0;">
<p style="font-size: 12px; color: #666;">
    If QPrism isn't for you, please 
    <a href="mailto:81147176.groups.volvo.com@emea.teams.ms?subject=Unsubscribe%20from%20QPrism&body=Hello%20QPrism%20Admin%2C%0A%0AI%20would%20like%20to%20unsubscribe%20from%20QPrism%20notifications.%0A%0ARegards" 
       style="color: #0066cc; text-decoration: none;">
        unsubscribe
    </a>
</p>
            </body>
            </html>
            """
            
            push!(notifications, create_notification(
                notif_id, sqe_email, subject, body, 2,
                nothing, nothing,
                Dict("type" => "sw_index_5year_warning", "parma_id" => parma_id, "days_remaining" => days_until_5years, "last_date" => sw_date_str)
            ))
            println("   ✓ Added: SW Index 5-year warning notification")
        end
        
    catch e
        println("   ⚠️  Error parsing SW index date for PARMA $parma_id: $e")
    end
end

# Process certification expiry notifications
function process_certification_notifications!(notifications, supplier_data, people)
    """Generate certification expiry notifications (quality, environmental, etc.)"""
    println("\n📜 Processing certification expiry notifications...")
    
    parma_id = get(supplier_data, "parmaId", "UNKNOWN")
    parma_code = tryparse(Int, parma_id)
    supplier_name = get(supplier_data, "name", "Unknown Supplier")
    
    # Find responsible SQE
    sqe = nothing
    if parma_code !== nothing
        sqe = find_sqe_for_parma(parma_code, people)
    end
    
    if sqe === nothing
        println("   ⚠️  No SQE found for PARMA $parma_id - skipping")
        return
    end
    
    sqe_email = get(sqe, "email", "")
    sqe_name = get(sqe, "name", "SQE")
    
    # Get certifications data
    certifications = get(supplier_data, "certifications", Dict())
    
    if isempty(certifications)
        println("   ⚠️  No certification data for PARMA $parma_id")
        return
    end
    
    # Process each certification type
    cert_types = ["quality", "environmental"]
    
    for cert_type in cert_types
        cert_data = get(certifications, cert_type, Dict())
        
        if isempty(cert_data)
            continue
        end
        
        cert_name = get(cert_data, "type", cert_type)
        expiry_str = get(cert_data, "expirationTime", "N/A")
        cert_status = get(cert_data, "status", "N/A")
        certified_place = get(cert_data, "certifiedPlace", "N/A")
        
        # Skip if no expiration date
        if expiry_str == "N/A" || expiry_str == ""
            continue
        end
        
        try
            # Parse expiration date
            expiry_date = Date(expiry_str, "yyyy-mm-dd")
            today = Date(now())
            days_until_expiry = Dates.value(expiry_date - today)
            
            println("   📅 $cert_name: $expiry_str ($(days_until_expiry) days)")
            
            # 6 months warning (180 days)
            if days_until_expiry <= 180 && days_until_expiry > 90
                notif_id = generate_notification_id()
                subject = "Certification Expiry Notice: 6 Months - $cert_name (PARMA $parma_id)"
                body = """
                <html>
                <body style="font-family: Arial, sans-serif;">
                    <h2 style="color: #0066cc;">📜 Certification Expiry Notice</h2>
                    <p>Dear $sqe_name,</p>
                    <p>Please note that the <strong>$cert_name</strong> certification for Supplier Partner <strong>(PARMA $parma_id)</strong> ($supplier_name) will expire within 6 months.</p>
                    <table style="border-collapse: collapse; margin: 20px 0;">
                        <tr>
                            <td style="padding: 8px; border: 1px solid #ddd;"><strong>Certification:</strong></td>
                            <td style="padding: 8px; border: 1px solid #ddd;">$cert_name</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px; border: 1px solid #ddd;"><strong>Certified Place:</strong></td>
                            <td style="padding: 8px; border: 1px solid #ddd;">$certified_place</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px; border: 1px solid #ddd;"><strong>Expiry Date:</strong></td>
                            <td style="padding: 8px; border: 1px solid #ddd;">$expiry_str</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px; border: 1px solid #ddd;"><strong>Days Remaining:</strong></td>
                            <td style="padding: 8px; border: 1px solid #ddd;">$days_until_expiry days</td>
                        </tr>
                    </table>
                    <p><strong>Action Required:</strong> Please plan for certification renewal.</p>
                    <p>Best regards,<br>QPrism</p>
<hr style="border: none; border-top: 1px solid #ddd; margin: 20px 0;">
<p style="font-size: 12px; color: #666;">
    If QPrism isn't for you, please 
    <a href="mailto:81147176.groups.volvo.com@emea.teams.ms?subject=Unsubscribe%20from%20QPrism&body=Hello%20QPrism%20Admin%2C%0A%0AI%20would%20like%20to%20unsubscribe%20from%20QPrism%20notifications.%0A%0ARegards" 
       style="color: #0066cc; text-decoration: none;">
        unsubscribe
    </a>
</p>
                </body>
                </html>
                """
                
                push!(notifications, create_notification(
                    notif_id, sqe_email, subject, body, 3,
                    nothing, nothing,
                    Dict("type" => "cert_expiry_6months", "parma_id" => parma_id, "cert_name" => cert_name, "days_remaining" => days_until_expiry)
                ))
                println("   ✓ Added: 6-month certification expiry for $cert_name")
                
            # 3 months warning (90 days)
            elseif days_until_expiry <= 90 && days_until_expiry > 0
                notif_id = generate_notification_id()
                subject = "Certification Expiry Warning: 3 Months - $cert_name (PARMA $parma_id)"
                body = """
                <html>
                <body style="font-family: Arial, sans-serif;">
                    <h2 style="color: #ff9900;">⚠️ Certification Expiry Warning</h2>
                    <p>Dear $sqe_name,</p>
                    <p>Please note that the <strong>$cert_name</strong> certification for Supplier Partner <strong>(PARMA $parma_id)</strong> ($supplier_name) will expire within 3 months.</p>
                    <table style="border-collapse: collapse; margin: 20px 0;">
                        <tr>
                            <td style="padding: 8px; border: 1px solid #ddd;"><strong>Certification:</strong></td>
                            <td style="padding: 8px; border: 1px solid #ddd;">$cert_name</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px; border: 1px solid #ddd;"><strong>Certified Place:</strong></td>
                            <td style="padding: 8px; border: 1px solid #ddd;">$certified_place</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px; border: 1px solid #ddd;"><strong>Expiry Date:</strong></td>
                            <td style="padding: 8px; border: 1px solid #ddd;">$expiry_str</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px; border: 1px solid #ddd;"><strong>Days Remaining:</strong></td>
                            <td style="padding: 8px; border: 1px solid #ddd;"><strong style="color: #ff9900;">$days_until_expiry days</strong></td>
                        </tr>
                    </table>
                    <p style="color: #ff9900;"><strong>Action Required:</strong> Please expedite certification renewal process.</p>
                    <p>Best regards,<br>QPrism</p>
<hr style="border: none; border-top: 1px solid #ddd; margin: 20px 0;">
<p style="font-size: 12px; color: #666;">
    If QPrism isn't for you, please 
    <a href="mailto:81147176.groups.volvo.com@emea.teams.ms?subject=Unsubscribe%20from%20QPrism&body=Hello%20QPrism%20Admin%2C%0A%0AI%20would%20like%20to%20unsubscribe%20from%20QPrism%20notifications.%0A%0ARegards" 
       style="color: #0066cc; text-decoration: none;">
        unsubscribe
    </a>
</p>
                </body>
                </html>
                """
                
                push!(notifications, create_notification(
                    notif_id, sqe_email, subject, body, 2,
                    nothing, nothing,
                    Dict("type" => "cert_expiry_3months", "parma_id" => parma_id, "cert_name" => cert_name, "days_remaining" => days_until_expiry)
                ))
                println("   ✓ Added: 3-month certification expiry for $cert_name")
                
            # Expired certification
            elseif days_until_expiry <= 0
                days_expired = abs(days_until_expiry)
                notif_id = generate_notification_id()
                subject = "URGENT: Certification EXPIRED - $cert_name (PARMA $parma_id)"
                body = """
                <html>
                <body style="font-family: Arial, sans-serif;">
                    <h2 style="color: #cc0000;">🚨 URGENT: Certification Expired</h2>
                    <p>Dear $sqe_name,</p>
                    <p>Please note that the <strong>$cert_name</strong> certification for Supplier Partner <strong>(PARMA $parma_id)</strong> ($supplier_name) is <span style="color: #cc0000; font-weight: bold;">EXPIRED</span>.</p>
                    <table style="border-collapse: collapse; margin: 20px 0;">
                        <tr>
                            <td style="padding: 8px; border: 1px solid #ddd;"><strong>Certification:</strong></td>
                            <td style="padding: 8px; border: 1px solid #ddd;">$cert_name</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px; border: 1px solid #ddd;"><strong>Certified Place:</strong></td>
                            <td style="padding: 8px; border: 1px solid #ddd;">$certified_place</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px; border: 1px solid #ddd;"><strong>Expired On:</strong></td>
                            <td style="padding: 8px; border: 1px solid #ddd;">$expiry_str</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px; border: 1px solid #ddd;"><strong>Days Expired:</strong></td>
                            <td style="padding: 8px; border: 1px solid #ddd;"><strong style="color: #cc0000;">$days_expired days</strong></td>
                        </tr>
                    </table>
                    <p style="color: #cc0000; font-weight: bold;">⚠️ IMMEDIATE ACTION REQUIRED - Supplier may not be compliant!</p>
                    <p>Best regards,<br>QPrism</p>
<hr style="border: none; border-top: 1px solid #ddd; margin: 20px 0;">
<p style="font-size: 12px; color: #666;">
    If QPrism isn't for you, please 
    <a href="mailto:81147176.groups.volvo.com@emea.teams.ms?subject=Unsubscribe%20from%20QPrism&body=Hello%20QPrism%20Admin%2C%0A%0AI%20would%20like%20to%20unsubscribe%20from%20QPrism%20notifications.%0A%0ARegards" 
       style="color: #0066cc; text-decoration: none;">
        unsubscribe
    </a>
</p>
                </body>
                </html>
                """
                
                push!(notifications, create_notification(
                    notif_id, sqe_email, subject, body, 1,
                    nothing, nothing,
                    Dict("type" => "cert_expired", "parma_id" => parma_id, "cert_name" => cert_name, "days_expired" => days_expired)
                ))
                println("   ✓ Added: EXPIRED certification notification for $cert_name")
            end
            
        catch e
            println("   ⚠️  Error parsing date for $cert_name: $e")
            continue
        end
    end
end

# Main function
function main()
    println("="^70)
    println("WHO SHOULD BE INFORMED - NOTIFICATION QUEUE GENERATOR")
    println("="^70)
    
    # Load HR database
    people = load_hr_database()
    manager = find_manager(people)
    
    if manager !== nothing
        println("   ✓ Manager found: $(get(manager, "name", "Unknown"))")
    end
    
    # Check supplier directory
    if !isdir(SUPPLIER_DIR)
        println("\n❌ Error: Supplier directory '$SUPPLIER_DIR' not found")
        println("   Please run data extraction scripts first (getweb.py, gethtm.jl)")
        return
    end
    
    json_files = filter(f -> endswith(f, ".json") && occursin("supplier_", f), readdir(SUPPLIER_DIR))
    
    if isempty(json_files)
        println("\n❌ Error: No supplier JSON files found in '$SUPPLIER_DIR'")
        return
    end
    
    println("\n📂 Found $(length(json_files)) supplier files")
    
    # Initialize notifications array
    notifications = []
    
    # Process each supplier
    for json_file in json_files
        json_path = joinpath(SUPPLIER_DIR, json_file)
        
        try
            supplier_data = JSON.parsefile(json_path)
            parma_id = get(supplier_data, "parmaId", "UNKNOWN")
            supplier_name = get(supplier_data, "name", "Unknown")
            
            println("\n" * "="^70)
            println("Processing: $supplier_name (PARMA $parma_id)")
            println("="^70)
            
            # Process different notification types
            process_qpm_notifications!(notifications, supplier_data, people, manager)
            process_audit_notifications!(notifications, supplier_data, people)
            process_sw_index_notifications!(notifications, supplier_data, people)
            process_certification_notifications!(notifications, supplier_data, people)
            
        catch e
            println("   ❌ Error processing $json_file: $e")
            continue
        end
    end
    
    # Save notifications to TOML
    if !isempty(notifications)
        # Create output directory if it doesn't exist
        output_dir = dirname(OUTPUT_FILE)
        if !isdir(output_dir)
            mkpath(output_dir)
            println("\n📁 Created directory: $output_dir")
        end
        
        # Convert to TOML-compatible structure
        toml_data = Dict("notifications" => notifications)
        
        open(OUTPUT_FILE, "w") do f
            TOML.print(f, toml_data)
        end
        
        println("\n" * "="^70)
        println("✅ NOTIFICATION QUEUE GENERATED")
        println("="^70)
        println("📧 Total notifications queued: $(length(notifications))")
        println("📁 Output file: $OUTPUT_FILE")
        println("\nNotification breakdown:")
        
        # Count by type
        type_counts = Dict{String, Int}()
        for notif in notifications
            notif_type = get(get(notif, "metadata", Dict()), "type", "unknown")
            type_counts[notif_type] = get(type_counts, notif_type, 0) + 1
        end
        
        for (type, count) in sort(collect(type_counts), by=x->x[2], rev=true)
            println("   • $type: $count")
        end
        
        println("\n💡 Next step: Run 'julia notifyall.jl' to send all notifications")
        
    else
        println("\n" * "="^70)
        println("ℹ️  NO NOTIFICATIONS GENERATED")
        println("="^70)
        println("All suppliers are within normal parameters")
    end
    
    println("="^70)
end

# Run
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end