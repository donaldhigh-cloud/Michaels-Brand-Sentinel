# detect-vendor-risk

Cloud Function (Gen2) that scans the `vendor_compliance_log` BigQuery table for anomalies and returns a structured risk report. Worker layer for the Brand Integrity Sentinel agent.

## What it does

Given a region (or `"all"`), a specific vendor_id, or no parameters at all:

1. Pulls relevant rows from BigQuery
2. For each vendor, splits their history into a baseline window (older weeks) and a recent window (newest 25%)
3. Computes three flags: `defect_spike` (3σ test), `on_time_erosion` (10pp drop test), `compliance_breach` (any FALSE in the recent window)
4. Returns a JSON report with `risk_level` (HIGH/MEDIUM/NONE), the flags that fired, an explanation with the actual numbers, and a recommendation framed for human review

## Deploy

From this directory:

```bash
gcloud functions deploy detect-vendor-risk \
  --gen2 \
  --runtime=python312 \
  --region=us-central1 \
  --source=. \
  --entry-point=detect_vendor_risk \
  --trigger-http \
  --allow-unauthenticated \
  --memory=512MB
```

## Test

**Single vendor (HIGH case — Suzhou):**

```bash
curl -s -X POST https://us-central1-ieco-495312.cloudfunctions.net/detect-vendor-risk \
  -H "Content-Type: application/json" \
  -d '{"vendor_id": "SUZHOU-TX"}' | python3 -m json.tool
```

Expected: `risk_level: HIGH`, both `defect_spike` and `compliance_breach` flags, ~29σ deviation on defect rate.

**Single vendor (MEDIUM case — Mumbai):**

```bash
curl -s -X POST https://us-central1-ieco-495312.cloudfunctions.net/detect-vendor-risk \
  -H "Content-Type: application/json" \
  -d '{"vendor_id": "MUMBAI-CR"}' | python3 -m json.tool
```

Expected: `risk_level: MEDIUM`, only `on_time_erosion`, ~16pp drop on on-time delivery.

**Region scan (the demo's underlying call):**

```bash
curl -s -X POST https://us-central1-ieco-495312.cloudfunctions.net/detect-vendor-risk \
  -H "Content-Type: application/json" \
  -d '{"region": "South Asia"}' | python3 -m json.tool
```

Expected: 3 vendors, Mumbai flagged MEDIUM, the other two NONE. Summary at the top: `medium_risk_count: 1`.

**Scan everything:**

```bash
curl -s -X POST https://us-central1-ieco-495312.cloudfunctions.net/detect-vendor-risk \
  -H "Content-Type: application/json" \
  -d '{}' | python3 -m json.tool
```

Expected: 7 vendors, summary showing `high_risk_count: 1` and `medium_risk_count: 1`. Vendors sorted with Suzhou (HIGH) first, Mumbai (MEDIUM) next.

## Production hardening checklist

- [ ] Replace `--allow-unauthenticated` with a service account.
- [ ] Add structured logging (`google-cloud-logging`).
- [ ] Add audit logging — record every flag with vendor_id, timestamp, and the calling user.
- [ ] Calibrate thresholds against 90 days of real historical data with the buyer team.
- [ ] Replace seed data with a real production feed from supplier portal / ERP / quality systems.
- [ ] Replace the `vendor_code_compliant` boolean with a typed code (`audit_failed`, `child_labor_violation`, etc.) so the agent can characterize breaches.
- [ ] Add seasonality awareness (e.g., suppress flags during known shutdowns).
