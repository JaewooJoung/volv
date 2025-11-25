#!/usr/bin/env julia
#┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
#┃ 📁File      📄 schedule.jl                                                          ┃
#┃ 📙Brief     📝 Volvo Supplier Notification Scheduler                                ┃
#┃ 🧾Details   🔎 Manages notification schedule using DuckDB database                  ┃
#┃ 🚩OAuthor   🦋 Original Author: Jaewoo Joung/정재우/郑在祐                         ┃
#┃ 👨‍🔧LAuthor   👤 Last Author: Jaewoo Joung                                         ┃
#┃ 📆LastDate  📍 2025-11-20 🔄Please support to keep update🔄                     ┃
#┃ 🏭License   📜 JSD:Just Simple Distribution(Jaewoo's Simple Distribution)        ┃
#┃ ✅Guarantee ⚠️ Explicitly UN-guaranteed                                          ┃
#┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

using DuckDB
using TOML
using Dates

# Configuration
const NOTIFY_FILE = "./dashboard/notification/notify.toml"
const DB_FILE = "./db/notifications.duckdb"
const DB_DIR = "./db"

# Notification frequency rules (in days)
const FREQUENCY_RULES = Dict(
    "qpm_increase_10" => Dict("frequency" => 0, "priority" => 3, "type" => "immediate"),
    "qpm_warning_30_50" => Dict("frequency" => 28, "priority" => 2, "type" => "recurring"),
    "qpm_critical_over_50" => Dict("frequency" => 28, "priority" => 1, "type" => "recurring"),
    "audit_expiry_6months" => Dict("frequency" => 0, "priority" => 3, "type" => "one-time"),
    "audit_expiry_3months" => Dict("frequency" => 0, "priority" => 2, "type" => "one-time"),
    "audit_expired" => Dict("frequency" => 28, "priority" => 1, "type" => "recurring"),
    "audit_conditional" => Dict("frequency" => 180, "priority" => 3, "type" => "recurring"),
    "sw_index_5year_overdue" => Dict("frequency" => 28, "priority" => 1, "type" => "recurring"),
    "sw_index_5year_warning" => Dict("frequency" => 0, "priority" => 2, "type" => "one-time"),
    "cert_expiry_6months" => Dict("frequency" => 0, "priority" => 3, "type" => "one-time"),
    "cert_expiry_3months" => Dict("frequency" => 0, "priority" => 2, "type" => "one-time"),
    "cert_expired" => Dict("frequency" => 28, "priority" => 1, "type" => "recurring")
)

# Initialize database
function init_database()
    """Create database and notifications table if they don't exist"""
    println("📊 Initializing notification database...")
    
    # Create db directory if it doesn't exist
    if !isdir(DB_DIR)
        mkpath(DB_DIR)
        println("   ✓ Created directory: $DB_DIR")
    end
    
    # Connect to DuckDB
    con = DBInterface.connect(DuckDB.DB, DB_FILE)
    
    # Create notifications table
    DBInterface.execute(con, """
        CREATE TABLE IF NOT EXISTS notifications (
            id VARCHAR PRIMARY KEY,
            notification_id VARCHAR NOT NULL,
            parma_id VARCHAR NOT NULL,
            notification_type VARCHAR NOT NULL,
            first_created_date DATE NOT NULL,
            last_sent_date DATE,
            next_send_date DATE,
            send_count INTEGER DEFAULT 0,
            status VARCHAR DEFAULT 'pending',
            priority INTEGER NOT NULL,
            recipient_email VARCHAR NOT NULL,
            subject VARCHAR,
            frequency_days INTEGER DEFAULT 0,
            frequency_type VARCHAR DEFAULT 'one-time',
            metadata VARCHAR,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    println("   ✓ Database initialized: $DB_FILE")
    
    return con
end

# Load notifications from TOML
function load_notify_toml()
    """Load notifications from notify.toml"""
    println("\n📋 Loading notifications from: $NOTIFY_FILE")
    
    if !isfile(NOTIFY_FILE)
        println("   ⚠️  No notify.toml found - no new notifications to process")
        return []
    end
    
    toml_data = TOML.parsefile(NOTIFY_FILE)
    notifications = get(toml_data, "notifications", [])
    
    println("   ✓ Loaded $(length(notifications)) notifications")
    
    return notifications
end

# Check if notification already exists in database
function notification_exists(con, notification_id, parma_id, notification_type)
    """Check if notification already exists in database"""
    result = DBInterface.execute(con, """
        SELECT COUNT(*) as count 
        FROM notifications 
        WHERE notification_id = ? 
        OR (parma_id = ? AND notification_type = ?)
    """, [notification_id, parma_id, notification_type])
    
    row = first(result)
    return row.count > 0
end

# Get existing notification for update
function get_existing_notification(con, parma_id, notification_type)
    """Get existing notification for recurring types"""
    result = DBInterface.execute(con, """
        SELECT * FROM notifications 
        WHERE parma_id = ? AND notification_type = ?
        ORDER BY created_at DESC
        LIMIT 1
    """, [parma_id, notification_type])
    
    rows = collect(result)
    return isempty(rows) ? nothing : rows[1]
end

# Calculate next send date based on frequency
function calculate_next_send_date(notification_type, last_sent_date=nothing)
    """Calculate next send date based on frequency rules"""
    rules = get(FREQUENCY_RULES, notification_type, nothing)
    
    if rules === nothing
        return nothing
    end
    
    freq_days = rules["frequency"]
    freq_type = rules["type"]
    
    # Immediate notifications - no next send date (skip in scheduler)
    if freq_type == "immediate"
        return nothing
    end
    
    # One-time notifications - no next send date after first send
    if freq_type == "one-time"
        return last_sent_date === nothing ? Date(now()) : nothing
    end
    
    # Recurring notifications
    if freq_type == "recurring"
        if last_sent_date === nothing
            return Date(now())
        else
            return last_sent_date + Day(freq_days)
        end
    end
    
    return nothing
end

# Insert new notification into database
function insert_notification(con, notif, today)
    """Insert new notification into database"""
    
    metadata = get(notif, "metadata", Dict())
    notification_type = get(metadata, "type", "unknown")
    
    # Skip immediate notifications (they are sent right away by separate process)
    rules = get(FREQUENCY_RULES, notification_type, nothing)
    if rules !== nothing && rules["type"] == "immediate"
        println("   ⏭️  Skipping immediate notification: $(notif["id"])")
        return false
    end
    
    parma_id = get(metadata, "parma_id", "UNKNOWN")
    
    # Check if this is a recurring or one-time notification that already exists
    existing = get_existing_notification(con, parma_id, notification_type)
    
    if existing !== nothing
        # For one-time notifications, don't insert again
        if rules !== nothing && rules["type"] == "one-time"
            println("   ⏭️  Skipping one-time notification (already exists): PARMA $parma_id - $notification_type")
            return false
        end
        
        # For recurring notifications, check if it's time to send again
        if existing.next_send_date !== nothing && today < existing.next_send_date
            println("   ⏭️  Skipping recurring notification (not due yet): PARMA $parma_id - $notification_type (next: $(existing.next_send_date))")
            return false
        end
    end
    
    # Get frequency rules
    frequency_days = rules !== nothing ? rules["frequency"] : 0
    frequency_type = rules !== nothing ? rules["type"] : "one-time"
    priority = rules !== nothing ? rules["priority"] : get(notif, "priority", 3)
    
    # Calculate next send date
    next_send_date = calculate_next_send_date(notification_type, nothing)
    
    # Generate unique ID
    unique_id = "$(parma_id)_$(notification_type)_$(Dates.format(today, "yyyymmdd"))"
    
    try
        DBInterface.execute(con, """
            INSERT INTO notifications (
                id, notification_id, parma_id, notification_type,
                first_created_date, next_send_date, status, priority,
                recipient_email, subject, frequency_days, frequency_type,
                metadata
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, [
            unique_id,
            notif["id"],
            parma_id,
            notification_type,
            today,
            next_send_date,
            "pending",
            priority,
            notif["recipient"],
            notif["subject"],
            frequency_days,
            frequency_type,
            string(metadata)
        ])
        
        return true
    catch e
        println("   ⚠️  Error inserting notification: $e")
        return false
    end
end

# Process notifications from TOML
function process_notifications(con, notifications, today)
    """Process notifications and insert new ones into database"""
    println("\n⚙️  Processing notifications for date: $today")
    
    inserted_count = 0
    skipped_count = 0
    
    for notif in notifications
        metadata = get(notif, "metadata", Dict())
        notification_type = get(metadata, "type", "unknown")
        parma_id = get(metadata, "parma_id", "UNKNOWN")
        
        println("\n   📌 Processing: PARMA $parma_id - $notification_type")
        
        if insert_notification(con, notif, today)
            inserted_count += 1
            println("      ✓ Inserted into schedule")
        else
            skipped_count += 1
            println("      ⏭️  Skipped")
        end
    end
    
    return inserted_count, skipped_count
end

# Clean up notify.toml after processing
function cleanup_notify_toml(notifications_to_keep)
    """Remove processed notifications from notify.toml, keep immediate ones"""
    if isempty(notifications_to_keep)
        # Remove the file if no notifications to keep
        if isfile(NOTIFY_FILE)
            rm(NOTIFY_FILE)
            println("\n   ✓ Cleaned up notify.toml (removed)")
        end
    else
        # Write back only the notifications to keep
        toml_data = Dict("notifications" => notifications_to_keep)
        open(NOTIFY_FILE, "w") do f
            TOML.print(f, toml_data)
        end
        println("\n   ✓ Updated notify.toml (kept $(length(notifications_to_keep)) immediate notifications)")
    end
end

# Get notifications ready to send
function get_pending_notifications(con, today)
    """Get all pending notifications that should be sent today or are overdue"""
    result = DBInterface.execute(con, """
        SELECT * FROM notifications 
        WHERE status = 'pending' 
        AND (next_send_date IS NULL OR next_send_date <= ?)
        ORDER BY priority ASC, first_created_date ASC
    """, [today])
    
    return collect(result)
end

# Display summary
function display_summary(con, today)
    """Display summary of notifications in database"""
    println("\n" * "="^70)
    println("NOTIFICATION SCHEDULE SUMMARY")
    println("="^70)
    
    # Total notifications
    result = DBInterface.execute(con, "SELECT COUNT(*) as count FROM notifications")
    total_count = first(result).count
    println("📊 Total notifications in database: $total_count")
    
    # Pending notifications
    result = DBInterface.execute(con, """
        SELECT COUNT(*) as count FROM notifications 
        WHERE status = 'pending'
    """)
    pending_count = first(result).count
    println("⏳ Pending notifications: $pending_count")
    
    # Ready to send today
    ready_notifs = get_pending_notifications(con, today)
    println("📤 Ready to send today: $(length(ready_notifs))")
    
    if !isempty(ready_notifs)
        println("\n📋 Notifications ready to send:")
        for notif in ready_notifs
            println("   • [P$(notif.priority)] PARMA $(notif.parma_id) - $(notif.notification_type)")
        end
    end
    
    # By type breakdown
    println("\n📊 Notifications by type:")
    result = DBInterface.execute(con, """
        SELECT notification_type, COUNT(*) as count, status
        FROM notifications
        GROUP BY notification_type, status
        ORDER BY count DESC
    """)
    
    for row in result
        println("   • $(row.notification_type) [$(row.status)]: $(row.count)")
    end
    
    println("="^70)
end

# Main function
function main()
    println("="^70)
    println("NOTIFICATION SCHEDULER - FIRST MONDAY OF MONTH")
    println("="^70)
    println("🗓️  Run Date: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")
    
    today = Date(now())
    
    # Initialize database
    con = init_database()
    
    try
        # Load notifications from TOML
        notifications = load_notify_toml()
        
        if !isempty(notifications)
            # Process notifications
            inserted, skipped = process_notifications(con, notifications, today)
            
            println("\n" * "="^70)
            println("PROCESSING COMPLETE")
            println("="^70)
            println("✅ Inserted: $inserted notifications")
            println("⏭️  Skipped: $skipped notifications")
            
            # Keep only immediate notifications in notify.toml
            immediate_notifs = filter(notifications) do notif
                metadata = get(notif, "metadata", Dict())
                notification_type = get(metadata, "type", "unknown")
                rules = get(FREQUENCY_RULES, notification_type, nothing)
                return rules !== nothing && rules["type"] == "immediate"
            end
            
            cleanup_notify_toml(immediate_notifs)
        end
        
        # Display summary
        display_summary(con, today)
        
    finally
        # Close database connection
        DBInterface.close!(con)
        println("\n✓ Database connection closed")
    end
    
    println("="^70)
end

# Run
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end