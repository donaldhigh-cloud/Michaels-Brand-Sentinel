# brand-sentinel-mcp

Cloud Function (Gen2) that exposes the `detect-vendor-risk` worker as an MCP server. Protocol adapter for Gemini Enterprise Agent Platform.

## Deploy

From this directory:

```bash
gcloud functions deploy brand-sentinel-mcp \
  --gen2 \
  --runtime=python312 \
  --region=us-central1 \
  --source=. \
  --entry-point=mcp_server \
  --trigger-http \
  --allow-unauthenticated \
  --memory=512MB
```

## Test

**1. `initialize` (handshake):**

```bash
curl -s -X POST https://us-central1-ieco-495312.cloudfunctions.net/brand-sentinel-mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | python3 -m json.tool
```

Expected: `result.protocolVersion = "2024-11-05"`, `serverInfo.name = "brand-sentinel-mcp"`.

**2. `tools/list` (advertise the tool):**

```bash
curl -s -X POST https://us-central1-ieco-495312.cloudfunctions.net/brand-sentinel-mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' | python3 -m json.tool
```

Expected: one tool with `name: "analyzeVendorRisk"`, full description, three input parameters.

**3. `tools/call` (execute the tool):**

```bash
curl -s -X POST https://us-central1-ieco-495312.cloudfunctions.net/brand-sentinel-mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"analyzeVendorRisk","arguments":{"region":"South Asia"}}}' | python3 -m json.tool
```

Expected: a JSON-RPC envelope with `result.content[0].text` containing the 3-vendor South Asia report (Mumbai MEDIUM, Dhaka NONE, Karachi NONE).

## Wire into Agent Studio

In your agent's Tools section:

1. Click **+** to add a tool.
2. Select **MCP Server**.
3. **MCP display name:** `brand-sentinel-mcp`
4. **Endpoint URL:** `https://us-central1-ieco-495312.cloudfunctions.net/brand-sentinel-mcp`
5. **Authentication:** None (for the prototype).
6. Save.

Your agent's Instructions should reference the tool by the name it advertises — `analyzeVendorRisk` — and explain when to call it. See `playbooks/agent-instructions.md`.

## Design note

This wrapper is structurally identical to `michaels-inventory-mcp` from the Inventory Orchestrator repo. Only `BACKEND_URL` and `TOOL_DEFINITION` differ. **The MCP wrapper is reusable boilerplate** — future agents can copy this file and edit those two constants.
