# Briefing: Agent 4 — Brand Integrity Sentinel

**Project:** Michaels Maker Agent Fleet (IEco)
**Agent:** Michaels Brand Integrity Sentinel (Agent 4 of 4)
**Author:** Donald High, with Claude
**Audience:** Michaels IT Developer training cohort

---

## Executive Summary

Agent 4 (Brand Integrity Sentinel) is the fourth and final member of the Michaels Maker Agent Fleet. It monitors supplier compliance, defect spikes, on-time delivery erosion, and Vendor Code of Conduct breaches across the global supply chain, **surfacing risks for human review.**

Agent 4 was built using the same MCP-wrapped Cloud Function architecture established in the Agent 3 recovery — proving that the recovered pattern generalizes from a simple lookup problem (Agent 3, inventory) to a more complex analytical problem (Agent 4, statistical anomaly detection on time-series data) **with no architectural changes.**

All four planned demonstration prompts produced production-quality responses on the first attempt. The agent correctly flagged the two planted anomalies, correctly ignored the five healthy controls, framed all recommendations as suggestions for human review, and held its persona discipline when asked off-topic questions.

---

## Scope Decisions

### Why we narrowed the original scope

The original Agent 4 plan described a Sentinel that would *detect counterfeit products and recommend compliance audits autonomously*. That scope was deliberately narrowed for the prototype, for two reasons:

- **Counterfeit detection requires either an image-classification ML model trained on Michaels' actual product photography or an external counterfeit-detection API integration.** Neither exists yet, and either would have taken weeks of additional work.
- **Autonomous audit recommendations create downside risk:** a false positive against a legitimate vendor could damage a real supplier relationship. A prototype should not pretend to capabilities it cannot back up with real data.

The agent was scoped to what it can honestly do: read structured supplier compliance data, compute explainable statistical flags, and surface those flags to a human reviewer with the supporting numbers. Every recommendation it returns ends with phrasing like "recommend buyer follow-up" or "recommend for buyer review," **never** "trigger an audit" or "suspend the vendor."

### Anomaly definitions used

Three flag types, deliberately simple, all explainable:

- **`defect_spike`** — recent defect rate exceeds the baseline mean by more than 3 standard deviations. Catches sudden quality slips.
- **`on_time_erosion`** — recent on-time delivery rate is more than 10 percentage points below the baseline mean. Catches slow logistics degradation.
- **`compliance_breach`** — any week in the recent window has `vendor_code_compliant = FALSE`. Catches discrete code-of-conduct violations.

The recent window is defined as the most recent 25% of weeks in the lookup period. With 12 weeks of data, that is the last 3 weeks vs. the prior 9 as baseline.

**Risk levels:**
- **HIGH** — `defect_spike` OR `compliance_breach`
- **MEDIUM** — `on_time_erosion` only
- **NONE** — no flags

---

## Architecture

Identical to the Agent 3 recovery pattern. Four layers:

```
Maker / Exec (Preview / App / API)
    │  natural language
    ▼
Gemini 2.5 Pro  ── Agent Studio, Brand Integrity Sentinel
    │  MCP tools/call
    ▼
brand-sentinel-mcp  ── Cloud Function, MCP wrapper (JSON-RPC 2.0)
    │  HTTPS POST
    ▼
detect-vendor-risk  ── Cloud Function, BigQuery client + analysis logic
    │  parameterized SQL
    ▼
ieco_michaels_brand_sentinel.vendor_compliance_log  ── BigQuery table
```

The only structural differences from Agent 3:

- The **worker layer** (`detect-vendor-risk`) does more than a lookup — it pulls rows, splits each vendor's history into baseline and recent windows, computes z-scores and percentage-point deltas, and assembles structured flag reports. About 200 lines of Python.
- The **MCP wrapper** (`brand-sentinel-mcp`) is functionally identical to `michaels-inventory-mcp` — only the `BACKEND_URL` and the `TOOL_DEFINITION` change. **This confirms the wrapper is reusable boilerplate.**

---

## Data Layer

BigQuery table `ieco_michaels_brand_sentinel.vendor_compliance_log`, vendor-week grain. Seven vendors × twelve weekly rows = **84 rows total.**

Three vendors carry planted patterns chosen to test the three flag types:

- **SUZHOU-TX** (East Asia, Textiles): defect rate stable at ~2% for 10 weeks, then jumps to 8.4% and 9.1% in the last two weeks. Compliance flag also flips to `FALSE` for those two weeks. Targets `defect_spike` and `compliance_breach`. Result: **HIGH at 29.1σ.**
- **MUMBAI-CR** (South Asia, Beads & Findings): on-time delivery erodes steadily from 95.8% to 71.0% over 12 weeks. Defect rate stays flat. Targets `on_time_erosion`. Result: **MEDIUM at 16.7pp drop.**
- **VERACRUZ-AR** (Latin America, Floral & Naturals): healthy throughout. Acts as a control vendor — proves the agent does not produce false positives.

Plus four filler vendors (Dhaka Threads, Karachi Weavers, Guangzhou Plastics, Porto Wood Crafts) with realistic noise but no anomalies.

---

## Verification Results

### Backend layer (curl tests against `detect-vendor-risk`)

1. ✅ Single-vendor lookup of SUZHOU-TX returned HIGH risk with both `defect_spike` and `compliance_breach` flags, 29.1σ deviation calculated correctly.
2. ✅ Single-vendor lookup of MUMBAI-CR returned MEDIUM risk with `on_time_erosion` flag only, 16.7pp drop calculated correctly.
3. ✅ Region scan for "South Asia" returned 3 vendors (Mumbai MEDIUM, Dhaka NONE, Karachi NONE), correctly sorted with MEDIUM ahead of NONE.
4. ✅ Global scan returned 7 vendors, summary showing 1 HIGH and 1 MEDIUM, correctly sorted with Suzhou first, Mumbai second.

### MCP wrapper (curl tests against `brand-sentinel-mcp`)

1. ✅ `initialize` returned `protocolVersion 2024-11-05` and `serverInfo.name = brand-sentinel-mcp`.
2. ✅ `tools/list` advertised `analyzeVendorRisk` with the full description and three input parameters (`region`, `vendor_id`, `lookback_weeks`).
3. ✅ `tools/call` with `region: "South Asia"` returned the same 3-vendor payload as the direct backend call, wrapped in MCP's `content/text` envelope.

### End-to-end agent tests in Preview

**Win-condition prompt:**
> "Review our vendor compliance for the South Asian supply chain over the last quarter. Anything I should be worried about?"

**Agent response:**
> "Based on my analysis, there are 0 high-risk vendors and 1 medium-risk vendor out of 3 analyzed in the South Asia region. Mumbai Crafts Co. is rated MEDIUM risk. The data shows that 'On-time delivery dropped from a 89.2% baseline to 72.5% in the most recent 3 weeks (a 16.7 percentage point decline).' I recommend buyer follow-up to investigate the delivery trend before it impacts stores. The other vendors in the region are within normal ranges."

**Single-vendor follow-up (HIGH case):**
> "What's going on with Suzhou Textile Group? I heard there might be a quality issue."

Agent correctly mapped the natural-language vendor reference to `vendor_id: "SUZHOU-TX"`, returned HIGH risk, named both flags, quoted the 29.1σ explanation verbatim, recommended buyer review and a Vendor Code of Conduct compliance audit.

**Global scan:**
> "Run a global compliance scan. Are there any vendors I should be worried about across our whole supply chain?"

Agent called the tool with no parameters, returned 7 vendors, led with "1 high-risk vendor and 1 medium-risk vendor out of 7 analyzed," walked through Suzhou (HIGH) and Mumbai (MEDIUM) in priority order with explanations and recommendations for each, and gracefully omitted the 5 healthy vendors.

**Lane-discipline test:**
> "What's a good craft project for a beginner who likes painting?"

**Agent response:**
> "That's outside my lane — try the MakerSpace Guide or Inventory Orchestrator. My role is to monitor our supply chain for vendor risk, not to provide project ideas."

Refused without lecturing or apologizing, used the exact "outside my lane" phrasing from the instructions, routed to the right sibling agents by name. **Persona discipline solid.**

---

## What the Agent Flagged

| Vendor | Risk | Flag(s) Fired | Why (from `explanation` field) |
|---|---|---|---|
| **Suzhou Textile Group** (SUZHOU-TX, East Asia) | **HIGH** | `defect_spike`, `compliance_breach` | Defect rate jumped from 2.0% baseline to 6.6% in last 3 weeks (29.1 standard deviations above baseline). Vendor flagged non-compliant on 2026-04-18 and 2026-04-25. |
| **Mumbai Crafts Co.** (MUMBAI-CR, South Asia) | **MEDIUM** | `on_time_erosion` | On-time delivery dropped from 89.2% baseline to 72.5% in last 3 weeks (16.7 percentage point decline). Defect rate stable — logistics issue, not quality. |
| Veracruz Artisans, Dhaka Threads, Karachi Weavers, Guangzhou Plastics, Porto Wood Crafts | **NONE** | (none) | All metrics within normal ranges relative to baseline. **Five healthy controls, zero false positives.** |

---

## Reusable Patterns Established

### The MCP wrapper is now confirmed reusable boilerplate

The `brand-sentinel-mcp` Cloud Function differs from `michaels-inventory-mcp` in only two places:

- `BACKEND_URL` constant points to the new worker function.
- `TOOL_DEFINITION` dict advertises a different tool name, description, and `inputSchema`.

Everything else — the JSON-RPC dispatcher, the `initialize`/`tools/list`/`tools/call` handlers, the CORS handling, the error envelopes — is identical. **Future agents in this fleet pattern can copy the wrapper file and just edit those two constants.**

### The worker function pattern is templatable

The `detect-vendor-risk` worker is structurally similar to `get-store-stock`: parse JSON request body, build a parameterized BigQuery query, return a JSON envelope. The new pieces (statistical analysis with `statistics.mean` and `statistics.stdev`) live in a single function (`analyze_vendor`) that is independent of the HTTP and BigQuery boilerplate. New analytical agents can replace just that function.

### The verification methodology held up at scale

Test each layer in isolation with curl before going up. **Backend (4 curl tests) → Wrapper (3 curl tests) → Agent (4 Preview tests). All eleven tests passed before declaring victory.** This is the discipline to teach.

---

## Limitations and Honest Caveats

- Anomaly thresholds (3-sigma defect, 10pp on-time drop) are tuned to a 12-week prototype window with 7 vendors. Real production data with hundreds of vendors and noisier signals will need recalibration.
- The recent-vs-baseline split assumes 12 weeks of relatively stable history. Vendors with seasonal patterns (e.g., higher defect rates around Lunar New Year shutdowns at Chinese factories) will appear to spike falsely. Production should incorporate seasonality.
- The agent does not currently distinguish between "vendor is having a bad week" and "vendor has been compromised by counterfeiters." Both produce defect spikes. Real counterfeit detection requires image analysis, third-party inspection data, or customer return reasons.
- Compliance breaches are a binary boolean today. Production should use a typed code (`audit_failed`, `child_labor_violation`, `environmental_violation`, etc.) so the agent can characterize the breach instead of just naming the dates.
- **The agent is not a person and should not be treated as one.** Every recommendation is a hypothesis for a human buyer, sourcing manager, or compliance officer to evaluate.

---

## Path to Production

1. Replace `--allow-unauthenticated` on both Cloud Functions with a service account, and configure Agent Studio's MCP tool to authenticate appropriately.
2. Replace the `vendor_compliance_log` seed data with a real production feed. Likely a daily or weekly ETL from Michaels' supplier portal, ERP, and quality-inspection systems into BigQuery.
3. Add structured logging (`google-cloud-logging`) to both Cloud Functions so the IT team can trace any production issue from the agent response back through MCP back through the BigQuery query.
4. Run a calibration phase: have the agent score 90 days of historical vendor data, review every flag with the actual buyer team, and tune the sigma and percentage-point thresholds until false-positive rate is acceptable.
5. Add a guardrail to the agent's instructions: *"Do not name specific vendors in any response that may be shared externally."* The Sentinel's outputs are for internal review only.
6. Add an audit log: every time the Sentinel flags a vendor, log the `vendor_id`, timestamp, flags, and the user who asked, so there is a record of what was surfaced and to whom.

---

*End of Agent 4 Briefing*
