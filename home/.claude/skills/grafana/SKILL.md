---
name: grafana
description: >-
  Use when querying Grafana — dashboards, Prometheus/Loki queries, alerts,
  incidents, datasources, or any mcp__grafana__* tool call.
---

# Grafana MCP — Subagent Pattern

Grafana MCP responses can be very large (full dashboard JSON, metric series, etc.).
To prevent these responses from flooding the main context window and causing task loss,
always delegate Grafana MCP calls to a subagent.

## Required Pattern

When the task involves any `mcp__grafana__*` tool call, use the **Agent tool** to spawn
a subagent. Pass the subagent a clear description of what to query and what to return.

The subagent should:
1. Execute the Grafana MCP tool call(s) needed to answer the query
2. Evaluate the size of the result:
   - **Small result** (a few fields, fits comfortably in a message): return it directly
     in the agent response
   - **Large result** (full dashboard JSON, many panels, long metric series, etc.):
     write the full raw result to `/tmp/grafana-<descriptive-name>.json`, then return
     only the file path + a brief summary of what the file contains (e.g. "Dashboard
     'API Overview' with 12 panels — saved to /tmp/grafana-api-overview.json")
3. Always describe what was found, even for large results written to a file

## Back in the Main Conversation

After the subagent returns:
- For small results: use the data directly to continue the task
- For large results: work from the file path — read specific sections with the Read
  tool, or spawn another subagent to explore/filter the file if needed
- Do NOT re-run the Grafana MCP tool in the main conversation

## Example Agent Prompt

```
Query Grafana for the dashboard named "Service Health". Use mcp__grafana__get_dashboard_by_uid
or mcp__grafana__search_dashboards to find it. If the result is small, return it directly.
If it's large, write the full JSON to /tmp/grafana-service-health.json and return the path
plus a summary of how many panels it has and what they show.
```
