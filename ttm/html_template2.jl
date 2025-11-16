"""
html_template2.jl
HTML template for Volvo Supplier Dashboard
"""

function generate_supplier_html(supplier_data::Dict)
    """
    Generate HTML for a single supplier using the data from parsed JSON
    """
    
    # Extract data with defaults
    supplier_id = get(supplier_data, "id", "N/A")
    supplier_name = get(supplier_data, "name", "Unknown Supplier")
    logo = get(supplier_data, "logo", "??")
    parma_id = get(supplier_data, "parmaId", "N/A")
    address = get(supplier_data, "address", "N/A")
    project_link = get(supplier_data, "projectLink", "#")
    timeplan_link = get(supplier_data, "timeplanLink", "#")
    apqp = get(supplier_data, "apqp", "N/A")
    ppap = get(supplier_data, "ppap", "N/A")
    
    # Get metrics
    metrics = get(supplier_data, "metrics", Dict())
    sw_index = get(metrics, "swIndex", "N/A")
    sw_status = get(metrics, "swStatus", "N/A")
    ee_index = get(metrics, "eeIndex", "N/A")
    ee_status = get(metrics, "eeStatus", "N/A")
    csr = get(metrics, "csr", "N/A")
    csr_status = get(metrics, "csrStatus", "N/A")
    sma = get(metrics, "sma", "N/A")
    sma_status = get(metrics, "smaStatus", "N/A")
    saq = get(metrics, "saq", "N/A")
    saq_status = get(metrics, "saqStatus", "N/A")
    
    # Get audits
    audits = get(supplier_data, "audits", [])
    audits_html = ""
    for audit in audits
        title = get(audit, "title", "N/A")
        status = get(audit, "status", "N/A")
        status_class = get(audit, "statusClass", "status-na")
        date = get(audit, "date", "N/A")
        
        needs_email = status_class in ["status-expired", "status-not-approved"]
        email_notification = needs_email ? "<div class=\"audit-notification\">📨Email</div>" : ""
        
        audits_html *= """
        <div class="audit-card">
            <div class="audit-title">$title</div>
            <div class="audit-status $status_class">$status</div>
            <div class="audit-date">$date</div>
            $email_notification
        </div>
        """
    end
    
    # Get QPM data
    qpm_data = get(supplier_data, "qpm", Dict())
    qpm_months = get(qpm_data, "months", [])
    qpm_values = get(qpm_data, "values", [])
    qpm_months_js = "[" * join(["'$m'" for m in qpm_months], ", ") * "]"
    qpm_values_js = "[" * join(qpm_values, ", ") * "]"
    
    # Get PPM data
    ppm_data = get(supplier_data, "ppm", Dict())
    ppm_months = get(ppm_data, "months", [])
    ppm_values = get(ppm_data, "values", [])
    ppm_months_js = "[" * join(["'$m'" for m in ppm_months], ", ") * "]"
    ppm_values_js = "[" * join(ppm_values, ", ") * "]"
    
    # Generate status class function
    function get_status_class(status)
        if status == "Approved"
            return "status-approved"
        elseif status == "Not Approved"
            return "status-not-approved"
        elseif status == "N/A"
            return "status-na"
        elseif status == "Pending"
            return "status-pending"
        elseif status == "Review"
            return "status-review"
        else
            return "status-approved"
        end
    end
    
    function show_email(status)
        return status == "Not Approved" ? "<div class=\"metric-notification\">📨Email</div>" : ""
    end
    
    sw_status_class = get_status_class(sw_status)
    ee_status_class = get_status_class(ee_status)
    csr_status_class = get_status_class(csr_status)
    sma_status_class = get_status_class(sma_status)
    saq_status_class = get_status_class(saq_status)
    
    sw_email = show_email(sw_status)
    ee_email = show_email(ee_status)
    csr_email = show_email(csr_status)
    sma_email = show_email(sma_status)
    saq_email = show_email(saq_status)
    
    # Calculate current timestamp
    current_time = Dates.format(Dates.now(), "yyyy-mm-dd HH:MM")
    html = """
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>$supplier_name - Quality Metrics</title>
    <script src="https://cdn.plot.ly/plotly-2.26.0.min.js"></script>
    <style>
        @page {
            size: A3 landscape;
            margin: 5mm;
        }
        
        @media print {
            body {
                width: 420mm;
                height: 297mm;
            }
        }
        
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: #f5f5f5;
            padding: 0;
        }
        
        .header {
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            color: white;
            padding: 15px 30px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.2);
        }
        
        .header-content {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .header h1 {
            font-size: 24px;
            font-weight: 600;
        }
        
        .last-update {
            font-size: 12px;
            opacity: 0.9;
        }
        
        .container {
            padding: 20px 30px;
            max-width: 1600px;
            margin: 0 auto;
        }
        
        .section-header {
            background: linear-gradient(135deg, #2c5f8d 0%, #1e3c72 100%);
            color: white;
            padding: 12px 20px;
            border-radius: 6px 6px 0 0;
            font-weight: 600;
            font-size: 14px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-top: 20px;
        }
        
        .section-content {
            background: white;
            padding: 20px;
            border-radius: 0 0 6px 6px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        
        .supplier-info {
            display: grid;
            grid-template-columns: 120px 1fr;
            gap: 20px;
            align-items: start;
        }
        
        .supplier-logo {
            width: 100px;
            height: 100px;
            background: linear-gradient(135deg, #ff6b6b 0%, #ff8e53 100%);
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-size: 36px;
            font-weight: bold;
            box-shadow: 0 4px 12px rgba(255,107,107,0.3);
        }
        
        .supplier-details {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 15px;
        }
        
        .detail-item {
            display: flex;
            flex-direction: column;
            gap: 4px;
        }
        
        .detail-label {
            font-size: 11px;
            color: #666;
            font-weight: 600;
            text-transform: uppercase;
        }
        
        .detail-value {
            font-size: 14px;
            color: #333;
            font-weight: 500;
        }
        
        .detail-link {
            color: #2196F3;
            text-decoration: none;
            font-weight: 500;
        }
        
        .detail-link:hover {
            text-decoration: underline;
        }
        
        .audits-grid {
            display: grid;
            grid-template-columns: repeat(6, 1fr);
            gap: 15px;
            margin-bottom: 20px;
        }
        
        .audit-card {
            background: white;
            border-radius: 8px;
            padding: 15px;
            text-align: center;
            box-shadow: 0 2px 6px rgba(0,0,0,0.08);
            border: 2px solid #e0e0e0;
            transition: all 0.3s;
        }
        
        .audit-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        }
        
        .audit-title {
            font-size: 13px;
            font-weight: 600;
            color: #333;
            margin-bottom: 8px;
        }
        
        .audit-status {
            display: inline-block;
            padding: 6px 12px;
            border-radius: 4px;
            font-size: 11px;
            font-weight: 600;
            margin-bottom: 6px;
        }
        
        .status-approved {
            background: #4CAF50;
            color: white;
        }
        
        .status-expired {
            background: #f44336;
            color: white;
        }
        
        .status-not-approved {
            background: #f44336;
            color: white;
        }
        
        .status-excellent {
            background: #00BCD4;
            color: white;
        }
        
        .status-na {
            background: #9E9E9E;
            color: white;
        }
        
        .status-pending {
            background: #FF9800;
            color: white;
        }
        
        .audit-date {
            font-size: 11px;
            color: #666;
        }
        
        .audit-notification {
            margin-top: 8px;
            font-size: 10px;
            color: #f44336;
            font-weight: 600;
        }
        
        .metrics-row {
            display: grid;
            grid-template-columns: repeat(5, 1fr);
            gap: 15px;
            margin-bottom: 20px;
        }
        
        .metric-card {
            background: white;
            border-radius: 8px;
            padding: 15px;
            text-align: center;
            box-shadow: 0 2px 6px rgba(0,0,0,0.08);
        }
        
        .metric-label {
            font-size: 12px;
            font-weight: 600;
            color: #666;
            margin-bottom: 8px;
            text-transform: uppercase;
        }
        
        .metric-value {
            font-size: 24px;
            font-weight: bold;
            color: #2c5f8d;
        }
        
        .metric-status {
            display: inline-block;
            padding: 4px 10px;
            border-radius: 4px;
            font-size: 10px;
            font-weight: 600;
            margin-top: 6px;
        }
        
        .metric-notification {
            margin-top: 8px;
            font-size: 10px;
            color: #f44336;
            font-weight: 600;
        }
        
        .charts-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
        }
        
        .chart-container {
            background: white;
            border-radius: 8px;
            padding: 20px;
            box-shadow: 0 2px 6px rgba(0,0,0,0.08);
        }
        
        .chart-title {
            font-size: 14px;
            font-weight: 600;
            color: #333;
            margin-bottom: 15px;
        }
        
        .back-link {
            display: inline-block;
            padding: 10px 20px;
            background: linear-gradient(135deg, #2c5f8d 0%, #1e3c72 100%);
            color: white;
            text-decoration: none;
            border-radius: 4px;
            font-size: 13px;
            font-weight: 600;
            transition: all 0.3s;
            margin-bottom: 20px;
        }
        
        .back-link:hover {
            transform: translateY(-1px);
            box-shadow: 0 4px 12px rgba(44,95,141,0.3);
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="header-content">
            <h1>$supplier_name - Quality Metrics</h1>
            <div class="last-update">Last Update: $current_time</div>
        </div>
    </div>
    
    <div class="container">
        <a href="../index.html" class="back-link">← Back to Dashboard</a>
        
        <!-- Supplier Info -->
        <div class="section-header">Supplier Partner Info</div>
        <div class="section-content">
            <div class="supplier-info">
                <div class="supplier-logo">$logo</div>
                <div class="supplier-details">
                    <div class="detail-item">
                        <div class="detail-label">PARMA</div>
                        <div class="detail-value">$parma_id</div>
                    </div>
                    <div class="detail-item">
                        <div class="detail-label">Name</div>
                        <div class="detail-value">$supplier_name</div>
                    </div>
                    <div class="detail-item">
                        <div class="detail-label">Address</div>
                        <div class="detail-value">$address</div>
                    </div>
                    <div class="detail-item">
                        <div class="detail-label">Project</div>
                        <div class="detail-value"><a href="$project_link" class="detail-link">Link</a></div>
                    </div>
                    <div class="detail-item">
                        <div class="detail-label">Timeplan</div>
                        <div class="detail-value"><a href="$timeplan_link" class="detail-link">Link</a></div>
                    </div>
                    <div class="detail-item">
                        <div class="detail-label">APQP</div>
                        <div class="detail-value">$apqp</div>
                    </div>
                    <div class="detail-item">
                        <div class="detail-label">PPAP</div>
                        <div class="detail-value">$ppap</div>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- Charts -->
        <div class="section-header">Quality Metrics Charts</div>
        <div class="section-content">
            <div class="charts-grid">
                <div class="chart-container">
                    <div class="chart-title">QPM (Year to Date)</div>
                    <div id="qpmChart"></div>
                </div>
                <div class="chart-container">
                    <div class="chart-title">PPM (Year to Date)</div>
                    <div id="ppmChart"></div>
                </div>
            </div>
        </div>
        
        <!-- Audits -->
        <div class="section-header">Audits</div>
        <div class="section-content">
            <div class="audits-grid">
                $audits_html
            </div>
        </div>
        
        <!-- Quality Metrics -->
        <div class="section-header">Quality Metrics Indices</div>
        <div class="section-content">
            <div class="metrics-row">
                <div class="metric-card">
                    <div class="metric-label">SW Index</div>
                    <div class="metric-value">$sw_index</div>
                    <div class="metric-status $sw_status_class">$sw_status</div>
                    $sw_email
                </div>
                <div class="metric-card">
                    <div class="metric-label">EE Index</div>
                    <div class="metric-value">$ee_index</div>
                    <div class="metric-status $ee_status_class">$ee_status</div>
                    $ee_email
                </div>
                <div class="metric-card">
                    <div class="metric-label">CSR</div>
                    <div class="metric-value">$csr</div>
                    <div class="metric-status $csr_status_class">$csr_status</div>
                    $csr_email
                </div>
                <div class="metric-card">
                    <div class="metric-label">SMA</div>
                    <div class="metric-value">$sma</div>
                    <div class="metric-status $sma_status_class">$sma_status</div>
                    $sma_email
                </div>
                <div class="metric-card">
                    <div class="metric-label">SAQ</div>
                    <div class="metric-value">$saq</div>
                    <div class="metric-status $saq_status_class">$saq_status</div>
                    $saq_email
                </div>
            </div>
        </div>
    </div>
    
    <script>
        // QPM Chart
        var qpmTrace = {
            x: $qpm_months_js,
            y: $qpm_values_js,
            type: 'bar',
            name: 'QPM',
            marker: {
                color: '#2196F3'
            }
        };
        
        var qpmThreshold = {
            x: $qpm_months_js,
            y: Array($qpm_months_js.length).fill(50),
            type: 'scatter',
            mode: 'lines',
            name: 'Threshold (50)',
            line: {
                color: '#FFC107',
                width: 2,
                dash: 'dot'
            }
        };
        
        var qpmLayout = {
            xaxis: { title: 'Month' },
            yaxis: { title: 'QPM', rangemode: 'tozero' },
            margin: { l: 50, r: 20, t: 20, b: 60 },
            height: 300,
            showlegend: true,
            legend: { x: 0, y: 1.1, orientation: 'h' }
        };
        
        Plotly.newPlot('qpmChart', [qpmTrace, qpmThreshold], qpmLayout, {responsive: true, displayModeBar: false});
        
        // PPM Chart
        var ppmTrace = {
            x: $ppm_months_js,
            y: $ppm_values_js,
            type: 'bar',
            name: 'PPM',
            marker: {
                color: '#2196F3'
            }
        };
        
        var ppmThreshold = {
            x: $ppm_months_js,
            y: Array($ppm_months_js.length).fill(50),
            type: 'scatter',
            mode: 'lines',
            name: 'Threshold (50)',
            line: {
                color: '#FFC107',
                width: 2,
                dash: 'dot'
            }
        };
        
        var ppmLayout = {
            xaxis: { title: 'Month' },
            yaxis: { title: 'PPM', rangemode: 'tozero' },
            margin: { l: 50, r: 20, t: 20, b: 60 },
            height: 300,
            showlegend: true,
            legend: { x: 0, y: 1.1, orientation: 'h' }
        };
        
        Plotly.newPlot('ppmChart', [ppmTrace, ppmThreshold], ppmLayout, {responsive: true, displayModeBar: false});
    </script>
</body>
</html>
"""
    
    return html

end
