#!/usr/bin/env julia
#┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
#┃ 📁File      📄 sendEmail.jl                                                         ┃
#┃ 📙Brief     📝 Volvo Supplier Email Notification Sender                             ┃
#┃ 🧾Details   🔎 Reads DuckDB and sends scheduled notifications via Sendmail          ┃
#┃ 🚩OAuthor   🦋 Original Author: Jaewoo Joung/정재우/郑在祐                         ┃
#┃ 👨‍🔧LAuthor   👤 Last Author: Jaewoo Joung                                         ┃
#┃ 📆LastDate  📍 2025-11-20 🔄Please support to keep update🔄                     ┃
#┃ 🏭License   📜 JSD:Just Simple Distribution(Jaewoo's Simple Distribution)        ┃
#┃ ✅Guarantee ⚠️ Explicitly UN-guaranteed                                          ┃
#┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

using DuckDB
using TOML
using Sendmail
using Dates

# Configuration
const DB_FILE = "./db/notifications.duckdb"
const NOTIFY_FILE = "./dashboard/notification/notify.toml"
const SENDMAIL_CONFIG = "./conf/config.toml"
const REPORT_DIR = "./dashboard/notification/reports"

# Initialize Sendmail
function init_sendmail()
    """Initialize Sendmail with configuration"""
    println("📧 Initializing Sendmail...")
    
    if !isfile(SENDMAIL_CONFIG)
        println("   ⚠️  Warning: Sendmail config not found: $SENDMAIL_CONFIG")
        println("   Please create config.toml with SMTP settings")
        return false
    end
    
    try
        Sendmail.configure(SENDMAIL_CONFIG)
        println("   ✓ Sendmail configured")
        return true
    catch e
        println("   ✗ Error configuring Sendmail: $e")
        return false
    end
end

# Connect to database
function connect_database()
    """Connect to DuckDB database"""
    println("\n📊 Connecting to database: $DB_FILE")
    
    if !isfile(DB_FILE)
        println("   ❌ Database not found: $DB_FILE")
        println("   Please run 'julia schedule.jl' first")
        return nothing
    end
    
    try
        con = DBInterface.connect(DuckDB.DB, DB_FILE)
        println("   ✓ Connected to database")
        return con
    catch e
        println("   ✗ Error connecting to database: $e")
        return nothing
    end
end

# Load immediate notifications from TOML
function load_immediate_notifications()
    """Load immediate notifications from notify.toml"""
    if !isfile(NOTIFY_FILE)
        return []
    end
    
    try
        data = TOML.parsefile(NOTIFY_FILE)
        notifications = get(data, "notifications", [])
        
        # Filter only immediate notifications
        immediate_notifs = filter(notifications) do notif
            metadata = get(notif, "metadata", Dict())
            notification_type = get(metadata, "type", "unknown")
            # Immediate types: qpm_increase_10
            return notification_type == "qpm_increase_10"
        end
        
        if !isempty(immediate_notifs)
            println("   ✓ Loaded $(length(immediate_notifs)) immediate notifications from TOML")
        end
        
        return immediate_notifs
    catch e
        println("   ⚠️  Error loading notify.toml: $e")
        return []
    end
end

# Get scheduled notifications from database
function get_scheduled_notifications(con, today)
    """Get notifications scheduled to be sent today from database"""
    println("\n📋 Fetching scheduled notifications for: $today")
    
    try
        result = DBInterface.execute(con, """
            SELECT * FROM notifications 
            WHERE status = 'pending' 
            AND (next_send_date IS NULL OR next_send_date <= ?)
            ORDER BY priority ASC, first_created_date ASC
        """, [today])
        
        notifications = collect(result)
        println("   ✓ Found $(length(notifications)) scheduled notifications")
        
        return notifications
    catch e
        println("   ✗ Error fetching notifications: $e")
        return []
    end
end

# Convert database row to notification dict for sending
function db_row_to_notification(row)
    """Convert database row to notification dictionary"""
    
    # Parse metadata
    metadata = try
        eval(Meta.parse(row.metadata))
    catch
        Dict()
    end
    
    # Build notification dict
    notification = Dict(
        "id" => row.notification_id,
        "recipient" => row.recipient_email,
        "subject" => row.subject,
        "body_text" => "",  # Body text needs to be generated or stored separately
        "priority" => row.priority,
        "metadata" => metadata
    )
    
    # Add CC/BCC if needed (for priority 1 notifications to manager)
    if row.priority == 1
        # CC to manager for critical notifications
        # This could be loaded from hr.toml or stored in DB
        notification["cc"] = nothing
        notification["bcc"] = nothing
    end
    
    return notification
end

# Generate email body for scheduled notification
function generate_email_body(row)
    """Generate HTML email body for scheduled notification"""
    
    parma_id = row.parma_id
    notification_type = row.notification_type
    
    # Parse metadata
    metadata = try
        eval(Meta.parse(row.metadata))
    catch
        Dict()
    end
    
    # Get recipient name (simplified - could be enhanced)
    recipient_name = split(row.recipient_email, "@")[1]
    
    # Generate body based on notification type
    if occursin("qpm", notification_type)
        qpm_actual = get(metadata, "qpm_actual", "N/A")
        
        if notification_type == "qpm_warning_30_50"
            return """
            <html>
            <body style="font-family: Arial, sans-serif;">
                <h2 style="color: #ff9900;">QPM Warning - Recurring Reminder</h2>
                <p>Dear $recipient_name,</p>
                <p>This is a recurring reminder that Supplier Partner <strong>PARMA $parma_id</strong> continues to have QPM in the warning range.</p>
                <p><strong>Current QPM:</strong> <span style="color: #ff9900;">$qpm_actual</span></p>
                <p><strong>Action Required:</strong> Please continue monitoring and coordinating improvement actions with the supplier.</p>
                <p>This notification will be sent every 4 weeks while QPM remains in this range.</p>
                <p>Best regards,<br>Automated Supplier Quality Management System</p>
            </body>
            </html>
            """
        elseif notification_type == "qpm_critical_over_50"
            return """
            <html>
            <body style="font-family: Arial, sans-serif;">
                <h2 style="color: #cc0000;">🚨 CRITICAL: QPM Over 50 - Recurring Alert</h2>
                <p>Dear $recipient_name,</p>
                <p>This is a recurring critical alert that Supplier Partner <strong>PARMA $parma_id</strong> continues to exceed QPM threshold of 50.</p>
                <p><strong>Current QPM:</strong> <span style="color: #cc0000; font-weight: bold;">$qpm_actual</span></p>
                <p style="color: #cc0000; font-weight: bold;">⚠️ CRITICAL ACTION REQUIRED:</p>
                <ul>
                    <li>Continue LPS (Local Problem Solving) actions</li>
                    <li>Review supplier improvement plan progress</li>
                    <li>Escalate if no improvement shown</li>
                </ul>
                <p>This notification will be sent every 4 weeks while QPM remains above 50.</p>
                <p>Best regards,<br>Automated Supplier Quality Management System</p>
            </body>
            </html>
            """
        end
    elseif occursin("audit", notification_type)
        if notification_type == "audit_expired"
            audit_name = get(metadata, "audit_name", "Audit")
            days_expired = get(metadata, "days_expired", "N/A")
            
            return """
            <html>
            <body style="font-family: Arial, sans-serif;">
                <h2 style="color: #cc0000;">🚨 Monthly Reminder: Audit Expired</h2>
                <p>Dear $recipient_name,</p>
                <p>This is a monthly reminder that the Audit <strong>$audit_name</strong> for Supplier Partner <strong>PARMA $parma_id</strong> remains expired.</p>
                <p><strong>Days Expired:</strong> <span style="color: #cc0000;">$days_expired days</span></p>
                <p style="color: #cc0000; font-weight: bold;">⚠️ IMMEDIATE ACTION REQUIRED</p>
                <p>This reminder will be sent monthly (1st Monday) until the audit is renewed.</p>
                <p>Best regards,<br>Automated Supplier Quality Management System</p>
            </body>
            </html>
            """
        elseif notification_type == "audit_conditional"
            audit_name = get(metadata, "audit_name", "Audit")
            
            return """
            <html>
            <body style="font-family: Arial, sans-serif;">
                <h2 style="color: #ff9900;">6-Month Reminder: Conditional Audit Status</h2>
                <p>Dear $recipient_name,</p>
                <p>This is a 6-month reminder about the conditional status of <strong>$audit_name</strong> for Supplier Partner <strong>PARMA $parma_id</strong>.</p>
                <p>Please review progress on addressing the audit conditions and coordinate with the supplier.</p>
                <p>Best regards,<br>Automated Supplier Quality Management System</p>
            </body>
            </html>
            """
        end
    elseif occursin("sw_index", notification_type)
        years_since = get(metadata, "years_since", "N/A")
        
        return """
        <html>
        <body style="font-family: Arial, sans-serif;">
            <h2 style="color: #cc0000;">🚨 Monthly Reminder: SW Index 5-Year Assessment Overdue</h2>
            <p>Dear $recipient_name,</p>
            <p>This is a monthly reminder that the SW Index assessment for Supplier Partner <strong>PARMA $parma_id</strong> is overdue.</p>
            <p><strong>Years Since Last Assessment:</strong> <span style="color: #cc0000;">$years_since years</span></p>
            <p style="color: #cc0000; font-weight: bold;">⚠️ IMMEDIATE ACTION REQUIRED: Schedule re-assessment</p>
            <p>This reminder will be sent monthly until the assessment is completed.</p>
            <p>Best regards,<br>Automated Supplier Quality Management System</p>
        </body>
        </html>
        """
    elseif occursin("cert", notification_type)
        cert_name = get(metadata, "cert_name", "Certification")
        days_expired = get(metadata, "days_expired", "N/A")
        
        return """
        <html>
        <body style="font-family: Arial, sans-serif;">
            <h2 style="color: #cc0000;">🚨 Monthly Reminder: Certification Expired</h2>
            <p>Dear $recipient_name,</p>
            <p>This is a monthly reminder that the <strong>$cert_name</strong> certification for Supplier Partner <strong>PARMA $parma_id</strong> remains expired.</p>
            <p><strong>Days Expired:</strong> <span style="color: #cc0000;">$days_expired days</span></p>
            <p style="color: #cc0000; font-weight: bold;">⚠️ IMMEDIATE ACTION REQUIRED</p>
            <p>This reminder will be sent monthly until the certification is renewed.</p>
            <p>Best regards,<br>Automated Supplier Quality Management System</p>
        </body>
        </html>
        """
    end
    
    # Default body if type not recognized
    return """
    <html>
    <body style="font-family: Arial, sans-serif;">
        <h2>Supplier Quality Notification</h2>
        <p>Dear $recipient_name,</p>
        <p>This is a scheduled notification regarding Supplier Partner <strong>PARMA $parma_id</strong>.</p>
        <p>Please review and take appropriate action.</p>
        <p>Best regards,<br>Automated Supplier Quality Management System</p>
    </body>
    </html>
    """
end

# Send email notification
function send_email_notification(notification)
    """Send a single email notification"""
    recipient = get(notification, "recipient", "")
    subject = get(notification, "subject", "")
    body_text = get(notification, "body_text", "")
    priority = get(notification, "priority", 3)
    cc = get(notification, "cc", nothing)
    bcc = get(notification, "bcc", nothing)
    notif_id = get(notification, "id", "UNKNOWN")
    
    if isempty(recipient)
        println("   ⚠️  [$notif_id] No recipient specified - skipping")
        return false
    end
    
    try
        # Send email
        success = Sendmail.send_email(
            recipient, 
            subject, 
            body_text, 
            priority=priority, 
            cc=cc, 
            bcc=bcc
        )
        
        if success
            println("   ✓ [$notif_id] Sent to: $recipient")
            if cc !== nothing && !isempty(cc)
                println("      CC: $cc")
            end
            return true
        else
            println("   ✗ [$notif_id] Failed to send to: $recipient")
            return false
        end
        
    catch e
        println("   ✗ [$notif_id] Error sending: $e")
        return false
    end
end

# Update notification status in database
function update_notification_status!(con, notification_id, status, today)
    """Update notification status in database"""
    try
        if status == "sent"
            # Update last_sent_date, send_count, and calculate next_send_date
            # Use the frequency_days from the table itself
            DBInterface.execute(con, """
                UPDATE notifications 
                SET status = 'sent',
                    last_sent_date = ?,
                    send_count = send_count + 1,
                    next_send_date = CASE 
                        WHEN frequency_type = 'recurring' THEN CAST(? AS DATE) + CAST(frequency_days AS INTEGER)
                        ELSE NULL
                    END,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = ?
            """, [today, today, notification_id])
            
            # For recurring, set back to pending for next cycle
            DBInterface.execute(con, """
                UPDATE notifications 
                SET status = 'pending'
                WHERE id = ?
                AND frequency_type = 'recurring'
            """, [notification_id])
        else
            # Just update status for failed notifications
            DBInterface.execute(con, """
                UPDATE notifications 
                SET status = ?,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = ?
            """, [status, notification_id])
        end
        
        return true
    catch e
        println("   ⚠️  Error updating notification status: $e")
        return false
    end
end

# Generate delivery report
function generate_delivery_report(sent_notifications, failed_notifications)
    """Generate and save delivery report"""
    
    # Create reports directory if it doesn't exist
    if !isdir(REPORT_DIR)
        mkpath(REPORT_DIR)
    end
    
    report_filename = joinpath(REPORT_DIR, "delivery_report_$(Dates.format(now(), "yyyymmdd_HHMMSS")).txt")
    
    try
        open(report_filename, "w") do f
            println(f, "="^70)
            println(f, "EMAIL DELIVERY REPORT")
            println(f, "="^70)
            println(f, "Generated: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")
            println(f, "Total Processed: $(length(sent_notifications) + length(failed_notifications))")
            println(f, "Successfully Sent: $(length(sent_notifications))")
            println(f, "Failed: $(length(failed_notifications))")
            println(f, "="^70)
            println(f, "")
            
            if !isempty(sent_notifications)
                println(f, "SUCCESSFULLY SENT NOTIFICATIONS:")
                println(f, "-"^70)
                for (idx, notif) in enumerate(sent_notifications)
                    println(f, "[$idx] $(notif["subject"])")
                    println(f, "    To: $(notif["recipient"])")
                    println(f, "    Type: $(get(get(notif, "metadata", Dict()), "type", "N/A"))")
                    println(f, "    PARMA: $(get(get(notif, "metadata", Dict()), "parma_id", "N/A"))")
                    println(f, "")
                end
            end
            
            if !isempty(failed_notifications)
                println(f, "FAILED NOTIFICATIONS:")
                println(f, "-"^70)
                for (idx, notif) in enumerate(failed_notifications)
                    println(f, "[$idx] $(notif["subject"])")
                    println(f, "    To: $(notif["recipient"])")
                    println(f, "    Type: $(get(get(notif, "metadata", Dict()), "type", "N/A"))")
                    println(f, "    PARMA: $(get(get(notif, "metadata", Dict()), "parma_id", "N/A"))")
                    println(f, "")
                end
            end
            
            println(f, "="^70)
            println(f, "END OF REPORT")
            println(f, "="^70)
        end
        
        println("\n📄 Delivery report saved: $report_filename")
        return report_filename
        
    catch e
        println("\n⚠️  Warning: Could not generate delivery report: $e")
        return nothing
    end
end

# Main function
function main()
    println("="^70)
    println("EMAIL NOTIFICATION SENDER")
    println("="^70)
    println("🗓️  Run Date: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")
    println()
    
    today = Date(now())
    
    # Initialize Sendmail
    if !init_sendmail()
        println("\n❌ Cannot proceed without Sendmail configuration")
        return
    end
    
    # Connect to database
    con = connect_database()
    if con === nothing
        println("\n❌ Cannot proceed without database connection")
        return
    end
    
    try
        # Get scheduled notifications from database
        scheduled_notifs = get_scheduled_notifications(con, today)
        
        # Get immediate notifications from TOML
        immediate_notifs = load_immediate_notifications()
        
        # Combine all notifications to send
        all_notifications = []
        
        # Convert scheduled DB notifications to email format
        for row in scheduled_notifs
            notif = db_row_to_notification(row)
            notif["body_text"] = generate_email_body(row)
            notif["db_id"] = row.id  # Store DB id for updating
            push!(all_notifications, notif)
        end
        
        # Add immediate notifications (already in correct format)
        append!(all_notifications, immediate_notifs)
        
        if isempty(all_notifications)
            println("\nℹ️  No notifications to send today")
            return
        end
        
        println("\n📧 Sending $(length(all_notifications)) notifications...")
        println("   • Scheduled (from DB): $(length(scheduled_notifs))")
        println("   • Immediate (from TOML): $(length(immediate_notifs))")
        println("="^70)
        println()
        
        # Statistics
        sent_notifications = []
        failed_notifications = []
        
        # Send each notification
        for (idx, notification) in enumerate(all_notifications)
            notif_id = get(notification, "id", "UNKNOWN")
            subject = get(notification, "subject", "N/A")
            metadata = get(notification, "metadata", Dict())
            notif_type = get(metadata, "type", "unknown")
            
            println("[$idx/$(length(all_notifications))] Processing: $notif_type")
            println("   ID: $notif_id")
            println("   Subject: $subject")
            
            # Send notification
            success = send_email_notification(notification)
            
            # Track results
            if success
                push!(sent_notifications, notification)
                
                # Update database if this was a scheduled notification
                if haskey(notification, "db_id")
                    update_notification_status!(con, notification["db_id"], "sent", today)
                end
            else
                push!(failed_notifications, notification)
                
                # Update database if this was a scheduled notification
                if haskey(notification, "db_id")
                    update_notification_status!(con, notification["db_id"], "failed", today)
                end
            end
            
            println()
            
            # Small delay between emails
            sleep(0.5)
        end
        
        # Generate delivery report
        report_file = generate_delivery_report(sent_notifications, failed_notifications)
        
        # Summary
        println("\n" * "="^70)
        println("✅ EMAIL SENDING COMPLETE")
        println("="^70)
        println("📊 Summary:")
        println("   • Total processed: $(length(all_notifications))")
        println("   • Successfully sent: $(length(sent_notifications))")
        println("   • Failed: $(length(failed_notifications))")
        
        if !isempty(all_notifications)
            success_rate = round((length(sent_notifications) / length(all_notifications)) * 100, digits=1)
            println("   • Success rate: $success_rate%")
        end
        
        if report_file !== nothing
            println("\n📄 Detailed report: $report_file")
        end
        
        println("="^70)
        
    finally
        # Close database connection
        DBInterface.close!(con)
        println("\n✓ Database connection closed")
    end
end

# Run
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end