# volv
volvo ab testing for Quality


# Supplier Quality Notification System - Complete Terminology

| Term | Definition |
|------|------------|
| **GENERAL TERMS** | |
| SQE | Software Quality Engineer - Person responsible for managing supplier quality |
| PARMA | Volvo's supplier identification system/code |
| QPM | Quality Performance Metric - Numeric score measuring supplier quality performance (0-100 scale) |
| CPI | Customer Product Issue - Quality problem reported by customer |
| IR | Inspection Report - Document issued after supplier inspection |
| LPS | Low Performing Supplier - Supplier requiring performance improvement actions |
| Index Audit | Formal assessment of supplier capability (SW Index, EE Index, SMA Index) |
| ISO Certification | International Standards Organization quality management certification |
| SQE Host | Primary SQE responsible for specific supplier relationship |
| ASH | Autonomous, Safety & HMI systems Team - Volvo team responsible for these technology areas |
| **USER ENVIRONMENT TERMS** | |
| User Environment | Personalized settings and preferences for each SQE user |
| PARMA Selection | Feature allowing SQE to filter which suppliers trigger notifications |
| Notification Subscription | User's opt-in/opt-out status for specific alert types |
| **NOTIFICATION PRIORITY LEVELS** | |
| Priority 1 (Red Flag) | Critical - Immediate action required |
| Priority 2 (Yellow Flag) | Warning - Action needed soon |
| Priority 3 (Blue Flag) | Information - For awareness |
| Email Flag | Visual indicator of notification urgency in email client |
| **QPM NOTIFICATION TERMS** | |
| First Trial | SW prototype - Initial software version/prototype stage |
| QPM Threshold | Predefined QPM value that triggers notification (30, 50) |
| QPM Escalation | Progression from one notification level to another based on QPM value |
| Notification Suppression | No alerts sent for QPM 0-29 range |
| Periodic Check | Scheduled notification at 4-week intervals |
| 10% QPM Increase | Threshold for immediate notification during First Trial (SW prototype) phase |
| **CPI NOTIFICATION TERMS** | |
| CPI Raised | Event when a new Customer Product Issue is initiated |
| Phase 2 | Next programming phase - CPI notifications to be implemented in future release |
| **INSPECTION REPORT TERMS** | |
| IR Issuance | Event when new inspection report is published |
| IR Notification | Alert sent when new IR is created |
| **SCORE CARD TERMS** | |
| Score Card | Comprehensive supplier performance dashboard |
| Monthly Basis | Notification frequency - sent once per month |
| Overall Supplier Scorecard Result | Combined metrics showing supplier's total performance |
| Dashboard | Visual summary of supplier metrics and status |
| Audit Status | Current state of supplier audits (approved, pending, expired) |
| **INDEX AUDIT & CERTIFICATION TERMS** | |
| Expiration Warning | Alert sent before audit/certification becomes invalid |
| 6-Month Warning | First notification - 6 months before expiry |
| 3-Month Warning | Second notification - 3 months before expiry |
| Expired Status | Audit/certification has passed validity date |
| Ongoing Notification | Continuous monthly alerts for expired items (until resolved) |
| Approved with Conditions | Audit result with requirements that must be addressed |
| Not Approved | Audit failure status |
| 6-Month Review | Periodic check for conditional/failed audits |
| Buyer | Volvo purchasing representative for supplier |
| **STATISTICS AND HISTORICAL DATA TERMS** | |
| Live Data | Real-time supplier performance information |
| Historical Data | Past performance records used for trend analysis |
| Forecast | Predictive analysis of future supplier performance |
| Supplier Performance Forecast | Predicted quality metrics based on past trends |
| Performance Statistics | Aggregated metrics showing supplier trends over time |
| Trend Analysis | Examination of performance patterns over time |
| **RECIPIENT TERMS** | |
| SQE | Primary recipient - Software Quality Engineer |
| Manager | Secondary recipient - SQE's supervisor (for Priority 1 QPM alerts) |
| SQE Supplier Host | Primary contact person for specific supplier |
| Buyer | Purchasing department representative (for audit expiration) |
| **NOTIFICATION DELIVERY TERMS** | |
| Immediately | Send notification without delay upon event trigger |
| Every 4 weeks | Periodic notification cycle (28 days) |
| Monthly | Once per month notification frequency |
| Every 6 months | Semi-annual notification frequency |
| Email/Notification | Alert delivered via email system |
| **SYSTEM ACTIONS** | |
| Send Notification | System action to deliver alert to user(s) |
| Deploy LPS Actions | Initiate Low Performing Supplier improvement activities |
| Take Necessary Actions | General instruction to SQE to investigate and respond |
| Continue Ongoing | User option to maintain expired audit notifications |
