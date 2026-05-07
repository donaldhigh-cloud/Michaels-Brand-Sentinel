"""
detect-vendor-risk Cloud Function

HTTP endpoint that scans the vendor_compliance_log BigQuery table for
anomalies and returns a structured risk report. Used as the backend for
the Michaels Brand Integrity Sentinel agent.

The function does not make autonomous decisions. It computes
explainable signals and recommends them for human review.

Lookup modes:
  1. region + lookback_weeks   -> scan all vendors in a region
  2. vendor_id + lookback_weeks -> scan a single vendor
  3. lookback_weeks alone       -> scan every vendor

Risk thresholds (deliberately simple, prototype-grade):
  - DEFECT SPIKE: recent defect rate > baseline mean + 3*stdev
  - ON-TIME EROSION: recent on-time rate < baseline mean - 10pp
  - COMPLIANCE BREACH: any FALSE in vendor_code_compliant (recent window)

Risk level:
  - HIGH:   defect_spike OR compliance_breach
  - MEDIUM: on_time_erosion only
  - NONE:   no flags
"""
import functions_framework
from google.cloud import bigquery
from flask import jsonify
from statistics import mean, stdev

PROJECT_ID = "ieco-495312"
DATASET = "ieco_michaels_brand_sentinel"
TABLE = "vendor_compliance_log"

# Tunables. Conservative for a prototype.
DEFECT_SIGMA_THRESHOLD = 3.0      # how many stdevs above baseline counts as a spike
ON_TIME_DROP_THRESHOLD = 10.0     # percentage points below baseline counts as erosion
RECENT_WINDOW_FRACTION = 0.25     # last 25% of weeks form the "recent" window


def analyze_vendor(rows):
    """
    Given an ordered list of weekly rows for a single vendor (oldest first),
    return a dict with risk_level, flags, and a human-readable explanation.
    """
    if len(rows) < 4:
        return {
            "risk_level": "NONE",
            "flags": [],
            "explanation": "Not enough history to evaluate (need at least 4 weeks).",
            "metrics": {}
        }

    # Split into baseline (older) and recent (newer) windows
    n = len(rows)
    recent_n = max(2, int(round(n * RECENT_WINDOW_FRACTION)))
    baseline = rows[:-recent_n]
    recent = rows[-recent_n:]

    baseline_defect = [r["defect_rate_pct"] for r in baseline]
    baseline_ontime = [r["on_time_delivery_pct"] for r in baseline]
    recent_defect = [r["defect_rate_pct"] for r in recent]
    recent_ontime = [r["on_time_delivery_pct"] for r in recent]

    baseline_defect_mean = mean(baseline_defect)
    baseline_defect_std = stdev(baseline_defect) if len(baseline_defect) > 1 else 0.0
    baseline_ontime_mean = mean(baseline_ontime)
    recent_defect_mean = mean(recent_defect)
    recent_ontime_mean = mean(recent_ontime)

    flags = []
    explanation_parts = []

    # Flag 1: defect spike
    if baseline_defect_std > 0:
        sigma = (recent_defect_mean - baseline_defect_mean) / baseline_defect_std
    else:
        sigma = 0.0
    if sigma >= DEFECT_SIGMA_THRESHOLD:
        flags.append("defect_spike")
        explanation_parts.append(
            f"Defect rate jumped from a {baseline_defect_mean:.1f}% baseline "
            f"to {recent_defect_mean:.1f}% in the most recent {recent_n} weeks "
            f"({sigma:.1f} standard deviations above baseline)."
        )

    # Flag 2: on-time erosion
    on_time_drop = baseline_ontime_mean - recent_ontime_mean
    if on_time_drop >= ON_TIME_DROP_THRESHOLD:
        flags.append("on_time_erosion")
        explanation_parts.append(
            f"On-time delivery dropped from a {baseline_ontime_mean:.1f}% baseline "
            f"to {recent_ontime_mean:.1f}% in the most recent {recent_n} weeks "
            f"(a {on_time_drop:.1f} percentage point decline)."
        )

    # Flag 3: compliance breach
    breach_weeks = [
        r["week_ending"] for r in recent if not r["vendor_code_compliant"]
    ]
    if breach_weeks:
        flags.append("compliance_breach")
        weeks_str = ", ".join(str(d) for d in breach_weeks)
        explanation_parts.append(
            f"Vendor was flagged as non-compliant with the Michaels Vendor Code "
            f"of Conduct in: {weeks_str}."
        )

    # Risk level
    if "defect_spike" in flags or "compliance_breach" in flags:
        risk_level = "HIGH"
    elif "on_time_erosion" in flags:
        risk_level = "MEDIUM"
    else:
        risk_level = "NONE"

    # Recommendation framed as a suggestion to a human reviewer
    if risk_level == "HIGH":
        recommendation = (
            "Recommend for buyer review and a Vendor Code of Conduct compliance audit."
        )
    elif risk_level == "MEDIUM":
        recommendation = (
            "Recommend buyer follow-up to investigate the delivery trend before it impacts stores."
        )
    else:
        recommendation = "No action needed; metrics within normal ranges."

    if not explanation_parts:
        explanation_parts.append("All recent metrics are within normal ranges relative to baseline.")

    return {
        "risk_level": risk_level,
        "flags": flags,
        "explanation": " ".join(explanation_parts),
        "recommendation": recommendation,
        "metrics": {
            "baseline_weeks": len(baseline),
            "recent_weeks": len(recent),
            "baseline_defect_mean": round(baseline_defect_mean, 2),
            "recent_defect_mean": round(recent_defect_mean, 2),
            "baseline_ontime_mean": round(baseline_ontime_mean, 2),
            "recent_ontime_mean": round(recent_ontime_mean, 2),
        }
    }


@functions_framework.http
def detect_vendor_risk(request):
    """HTTP Cloud Function that returns a vendor risk report."""
    if request.method == "OPTIONS":
        return ("", 204, {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "POST, GET",
            "Access-Control-Allow-Headers": "Content-Type",
            "Access-Control-Max-Age": "3600",
        })

    cors_headers = {"Access-Control-Allow-Origin": "*"}

    body = request.get_json(silent=True) or {}
    args = request.args

    region = body.get("region") or args.get("region")
    vendor_id = body.get("vendor_id") or args.get("vendor_id")
    try:
        lookback_weeks = int(body.get("lookback_weeks") or args.get("lookback_weeks") or 12)
    except (TypeError, ValueError):
        lookback_weeks = 12

    # Cap lookback to prevent abuse
    lookback_weeks = max(4, min(lookback_weeks, 52))

    client = bigquery.Client(project=PROJECT_ID)

    # Build the query. For the prototype we use all rows in the table; production
    # should filter by week_ending against an ingest timestamp.
    where_clauses = []
    params = []

    if region and region.lower() != "all":
        where_clauses.append("LOWER(region) = LOWER(@region)")
        params.append(bigquery.ScalarQueryParameter("region", "STRING", region))
    if vendor_id:
        where_clauses.append("vendor_id = @vendor_id")
        params.append(bigquery.ScalarQueryParameter("vendor_id", "STRING", vendor_id))

    where_sql = ("WHERE " + " AND ".join(where_clauses)) if where_clauses else ""

    query = f"""
        SELECT vendor_id, vendor_name, region, product_category,
               week_ending, shipments_count,
               defect_rate_pct, on_time_delivery_pct, return_rate_pct,
               vendor_code_compliant
        FROM `{PROJECT_ID}.{DATASET}.{TABLE}`
        {where_sql}
        ORDER BY vendor_id, week_ending
    """

    job_config = bigquery.QueryJobConfig(query_parameters=params)
    rows = [dict(r.items()) for r in client.query(query, job_config=job_config).result()]

    if not rows:
        return (jsonify({
            "found": False,
            "message": "No vendor data matched the filters.",
            "vendors": []
        }), 200, cors_headers)

    # Group by vendor
    by_vendor = {}
    for r in rows:
        # week_ending comes back as a date object; serialize for JSON
        r["week_ending"] = r["week_ending"].isoformat()
        by_vendor.setdefault(r["vendor_id"], []).append(r)

    vendor_reports = []
    for vid, vrows in by_vendor.items():
        analysis = analyze_vendor(vrows)
        head = vrows[0]
        vendor_reports.append({
            "vendor_id": vid,
            "vendor_name": head["vendor_name"],
            "region": head["region"],
            "product_category": head["product_category"],
            "weeks_analyzed": len(vrows),
            **analysis
        })

    # Sort: HIGH first, then MEDIUM, then NONE
    risk_order = {"HIGH": 0, "MEDIUM": 1, "NONE": 2}
    vendor_reports.sort(key=lambda v: (risk_order.get(v["risk_level"], 3), v["vendor_id"]))

    summary = {
        "high_risk_count": sum(1 for v in vendor_reports if v["risk_level"] == "HIGH"),
        "medium_risk_count": sum(1 for v in vendor_reports if v["risk_level"] == "MEDIUM"),
        "vendors_analyzed": len(vendor_reports),
    }

    return (jsonify({
        "found": True,
        "summary": summary,
        "vendors": vendor_reports
    }), 200, cors_headers)
