"""
MCP Server for Michaels Brand Integrity Sentinel.

Wraps the detect-vendor-risk Cloud Function in MCP protocol (JSON-RPC 2.0)
so it can be consumed by Gemini Enterprise Agent Platform's Tools picker.

Implements three MCP methods:
  - initialize   (handshake)
  - tools/list   (advertises analyzeVendorRisk tool definition)
  - tools/call   (executes the tool with arguments, forwards to backend)

Deployed at:
  https://us-central1-ieco-495312.cloudfunctions.net/brand-sentinel-mcp
"""
import json
import functions_framework
import requests
from flask import jsonify

# URL of the underlying Cloud Function that does the actual analysis
BACKEND_URL = "https://us-central1-ieco-495312.cloudfunctions.net/detect-vendor-risk"

TOOL_DEFINITION = {
    "name": "analyzeVendorRisk",
    "description": (
        "Analyze Michaels supplier vendor compliance and quality data, returning "
        "a structured risk report. Use this whenever the user asks about supply "
        "chain anomalies, vendor compliance issues, defect spikes, delivery "
        "problems, counterfeit risk, or which vendors should be audited. "
        "Three lookup modes: "
        "(1) region (e.g. 'South Asia', 'East Asia', 'Europe', 'Latin America') to scan all vendors in a region, "
        "(2) vendor_id (e.g. 'SUZHOU-TX', 'MUMBAI-CR') to scan a single vendor, "
        "(3) no parameters to scan every vendor across the supply chain. "
        "Always returns a summary, then a per-vendor breakdown sorted with HIGH risk first. "
        "Each vendor includes an explanation with the actual numbers and a recommended action for human review."
    ),
    "inputSchema": {
        "type": "object",
        "properties": {
            "region": {
                "type": "string",
                "description": "Geographic region to scan, e.g. 'South Asia', 'East Asia', 'Latin America', 'Europe'. Use 'all' or omit to scan every region."
            },
            "vendor_id": {
                "type": "string",
                "description": "Specific vendor identifier, e.g. SUZHOU-TX or MUMBAI-CR. Use this when the user names a specific supplier."
            },
            "lookback_weeks": {
                "type": "integer",
                "description": "How many weeks of history to analyze. Defaults to 12. Capped between 4 and 52."
            }
        }
    }
}


def jsonrpc_response(request_id, result=None, error=None):
    body = {"jsonrpc": "2.0", "id": request_id}
    if error is not None:
        body["error"] = error
    else:
        body["result"] = result
    return body


@functions_framework.http
def mcp_server(request):
    if request.method == "OPTIONS":
        return ("", 204, {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type, Authorization",
            "Access-Control-Max-Age": "3600",
        })

    cors_headers = {"Access-Control-Allow-Origin": "*"}

    if request.method == "GET":
        return (jsonify({
            "status": "ok",
            "server": "brand-sentinel-mcp",
            "tools": [TOOL_DEFINITION["name"]]
        }), 200, cors_headers)

    payload = request.get_json(silent=True) or {}
    method = payload.get("method")
    params = payload.get("params", {})
    request_id = payload.get("id")

    if method == "initialize":
        result = {
            "protocolVersion": "2024-11-05",
            "capabilities": {"tools": {}},
            "serverInfo": {
                "name": "brand-sentinel-mcp",
                "version": "1.0.0"
            }
        }
        return (jsonify(jsonrpc_response(request_id, result=result)), 200, cors_headers)

    if method == "tools/list":
        result = {"tools": [TOOL_DEFINITION]}
        return (jsonify(jsonrpc_response(request_id, result=result)), 200, cors_headers)

    if method == "tools/call":
        tool_name = params.get("name")
        arguments = params.get("arguments", {}) or {}

        if tool_name != "analyzeVendorRisk":
            error = {"code": -32601, "message": f"Unknown tool: {tool_name}"}
            return (jsonify(jsonrpc_response(request_id, error=error)), 200, cors_headers)

        try:
            backend_response = requests.post(BACKEND_URL, json=arguments, timeout=30)
            backend_data = backend_response.json()
        except Exception as e:
            error = {"code": -32603, "message": f"Backend call failed: {str(e)}"}
            return (jsonify(jsonrpc_response(request_id, error=error)), 200, cors_headers)

        result = {
            "content": [
                {
                    "type": "text",
                    "text": json.dumps(backend_data)
                }
            ]
        }
        return (jsonify(jsonrpc_response(request_id, result=result)), 200, cors_headers)

    if request_id is None:
        return ("", 200, cors_headers)

    error = {"code": -32601, "message": f"Method not found: {method}"}
    return (jsonify(jsonrpc_response(request_id, error=error)), 200, cors_headers)
