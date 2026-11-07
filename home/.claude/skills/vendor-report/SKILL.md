---
name: vendor-report
disable-model-invocation: true
description: Build this period's third-party vendor inventory from Ramp spend, usage behind credits and a code sweep, and publish it to Museum
argument-hint: "[--month | --quarter] [period, e.g. 2026-11 or 2026-Q4] [previous report URLs or slugs]"
allowed-tools: Bash(uv run:*), Bash(keyfile list:*), Bash(keyfile run:*), Bash(aws secretsmanager list-secrets:*), Bash(bq ls:*), Bash(curl:*), Bash(mkdir:*), Bash(date:*), Read, Write, AskUserQuestion, ToolSearch, Skill
---

# /vendor-report — Third-party vendor inventory

One report per period: every third-party vendor we pay or depend on, what it is for, which repos use it, and what it cost. Each run builds a new Museum artifact. The previous report is the starting point, so classifications carry forward and only what changed needs judgment.

Four sources, with different jobs:

- **Ramp decides what we paid.** Card, reimbursement and Bill Pay spend, per merchant. A vendor's charged cost comes only from Ramp.
- **Usage APIs decide what credits and prepaid plans hide.** AWS, GCP, OpenRouter and Tavily cost more than Ramp shows, or burn a prepaid balance.
- **The code decides what we depend on.** Packages, Terraform providers and API-key settings in `~/code/github/savi`. A vendor with no Ramp charge still belongs in the report if the code uses it.
- **The previous report decides what each vendor is.** Its purpose, owner, billing note and grouping. Carry them forward unless this period's data contradicts them.

## Arguments

`$ARGUMENTS`

- `--month` (default) or `--quarter`: the report's cadence.
- A period: `2026-11` or `2026-Q4`. Empty: the last complete month or quarter.
- Previous reports: Museum URLs or slugs, newest first. Empty: find the newest with `list_artifacts`, searching for "Vendor inventory". None found: this is the first report; build every classification from scratch.

**A quarterly run sweeps the code; a monthly run reuses the previous report's repo mapping.** Also sweep on a monthly run with no previous report.

## Phase 1 — Load the previous report

Find the Museum tools with `ToolSearch` (`museum get artifact`, `museum publish`). The prefix depends on how the user connected the server, so refer to tools by what they do.

Read the newest previous report with `get_artifact`. Every report embeds its inventory as JSON in `<script type="application/json" id="vendor-inventory">` (schema in Phase 6). Read the vendor rows from it. A report without that block predates this command: read its tables instead.

Older reports given as arguments are context for trends only. Do not carry a classification from an older report over the newest one.

## Phase 2 — Ramp spend

Find the Ramp MCP's reporting tools with `ToolSearch` (`ramp reporting`). Call `ramp_reporting_get_skill` first and follow it. Use the `spend` dataset; check its field names with `ramp_reporting_describe_dataset` rather than assuming them.

Run these with `query_scope: complete`, in parallel:

1. **This period, per vendor.** `payee` with `amount`, over the period.
2. **Trailing 12 months, per vendor.** `payee` and `spend_date` at month grain, with a `second_stage` keeping `payee` and computing the `SUM`, `COUNT` (active months) and `AVG` of the monthly amount. Active months separates subscriptions from one-off charges.
3. **How each vendor is paid.** `payee`, `category` and `spend_type` with `amount`, over the trailing 12 months.

Keep each payee's Ramp id (`search_tag_info.id`): it is the key that matches vendors across reports, since display names change.

Ramp shows only the spend the signed-in user's role can see. If `ramp_token_info` reports `auth_level: user`, say so on the report's Summary view.

## Phase 3 — Usage behind credits and prepaid plans

Ramp undercounts these vendors: AWS and GCP run on credits, OpenRouter routes through our own AWS and GCP keys (BYOK), and Tavily was bought in bulk. Report what each would cost, or how fast the prepaid balance is burning.

The OpenRouter and Tavily figures are running totals, not per-period amounts. Store each reading in the inventory JSON (Phase 6) and take the period's usage as the difference from the previous report's reading. A first report records the baseline and says the period figure starts next time.

- **AWS.** Load the `savi:aws-cost-analysis` skill and run its fetch, with `--months 3` on a quarterly run. Follow its rules for reading the bundle: its figures are usage before credits, and `record_type_totals` gives the credits applied. Report usage and credits for the period and the top services by usage.
- **GCP.** We have no billing export to BigQuery, so the CLI cannot see cost. Ask the user for the period's total from Billing → Reports in the console, with credits ("Promotions and others") unticked. If they skip it, show GCP as not measured. If a billing export dataset appears in any project (`bq ls --project_id=<project>`), query it instead and drop this step.
- **OpenRouter.** With a management key, `GET https://openrouter.ai/api/v1/keys` lists every key with its usage. Without one, read the local key alone and say the figure covers that key only:

  ```bash
  keyfile run openrouter -- sh -c 'curl -s https://openrouter.ai/api/v1/key -H "Authorization: Bearer $SAVI_LLM__OPENROUTER_API_KEY"'
  ```

  Record `usage` (billed by OpenRouter) and `byok_usage` (billed to our AWS and GCP keys, so already inside their usage; report it as LLM cost routed through OpenRouter, not as extra spend).
- **Tavily.**

  ```bash
  keyfile run tavily -- sh -c 'curl -s https://api.tavily.com/usage -H "Authorization: Bearer $SAVI_TAVILY__API_KEY"'
  ```

  Record `account.plan_usage` and `account.plan_limit`. Report the period's credits used, the share of the plan left, and the date it runs out at the trailing burn rate (the average period usage across the previous reports, or this period alone if there is only one).

Never print a key: always pass it through `keyfile run`.

## Phase 4 — Code sweep (quarterly)

```bash
uv run "${CLAUDE_SKILL_DIR}/vendor_sweep.py" ~/code/github/savi
```

It prints packages, Terraform providers and API-key settings classes, each mapped to the repos that use them. Map those names to vendors yourself: `twilio` and `@twilio/voice-sdk` are both Twilio; `TavilyConfig` is Tavily. Ignore general-purpose libraries (pydantic, react, pytest); this report is about vendors, not open-source libraries.

Two more sources name integrations the code may reach only through config:

```bash
keyfile list
```

```bash
aws secretsmanager list-secrets --profile prod-sso-read --region us-east-1 --query 'SecretList[].Name' --output text
```

Take names only. Never read a secret's value. If the SSO session has lapsed, follow the infrastructure guide's `savi-login` steps; a device profile cannot list secrets in every account, so skip this source and say so rather than blocking on it.

## Phase 5 — Classify

Start from the previous report's rows and update them:

- **Matched vendor:** keep its purpose, owner and group. Replace cost, active months and (on a quarterly run) repos.
- **New Ramp payee:** classify it. Use the merchant name, Ramp category and the code sweep. If its purpose is genuinely unclear, mark it `unclassified` rather than guessing.
- **Missing this period:** keep the row, with zero spend for the period. Mark it `dropped` only when it has had no charge for the whole trailing 12 months and no code references it.
- **Code-only vendor:** paid outside Ramp, on a free tier, or covered by credits. AWS is on startup credits, so its Ramp charges are not its real cost. Do not guess a cost for these.

Groups: `paid-in-code` (charged on Ramp and used in code), `code-only`, `non-engineering` (office, travel, devices, app stores), `unclassified`.

Then compare with the previous report: new vendors, dropped vendors, and any vendor whose period spend moved by more than 25% and $50. These are the report's headline.

## Phase 6 — Build the artifact

Read Museum's `get_authoring_guide` before writing. Use the house kit with one view per topic:

- **Summary:** total Ramp spend for the period and trailing 12 months, usage behind credits, the changes from Phase 5, and the data's coverage limits.
- **Paid vendors:** the `paid-in-code` table: vendor, purpose, repos, period spend, trailing-12-month spend, active months, billing.
- **Code-only:** vendors the code depends on with no Ramp charge, and why (credits, free tier, billed elsewhere) where known.
- **Usage:** the Phase 3 figures. AWS and GCP usage before credits next to the credits applied; OpenRouter's billed and BYOK cost; Tavily credits used this period, plan remaining, and projected run-out date. Across several reports, a trend chart per vendor.
- **Other spend:** `non-engineering` and `unclassified`.
- **History:** links to the previous reports, each with `target="_blank"`.

Give every table row a `data-anchor` built from the vendor's Ramp id, or a slug of its name for a code-only vendor (`vendor-<id>`). The same vendor gets the same anchor in every report, which keeps comments meaningful across reports.

Embed the inventory for the next run:

```html
<script type="application/json" id="vendor-inventory">
{"period": "2026-11", "cadence": "month", "swept_code": true,
 "vendors": [{"name": "Twilio", "ramp_id": "1fe0…", "group": "paid-in-code",
   "purpose": "Voice and SMS", "owner": null, "repos": ["harbor", "voice-agent"],
   "billing": "card, monthly", "period_spend": 151.20, "ttm_spend": 1816.32,
   "active_months": 10}],
 "usage": {
   "aws": {"usage_usd": 4210.55, "credits_usd": -4210.55, "months": ["2026-11"]},
   "gcp": {"usage_usd": null, "source": "not measured"},
   "openrouter": {"as_of": "2026-12-01", "keys": "local key only",
                  "usage_total_usd": 0, "byok_usage_total_usd": 76.60},
   "tavily": {"as_of": "2026-12-01", "plan": "Scale",
              "plan_usage_total": 2279445, "plan_limit": 3600000}}}
</script>
```

`ramp_id` is null for a code-only vendor; `owner` is null until someone fills it in. Amounts are USD. The `*_total` fields are the raw running totals Phase 3 diffs against; keep their names stable.

## Phase 7 — Publish

Print the Summary view's headline (totals, new and dropped vendors, big movers, unclassified count) as reply text, then ask with `AskUserQuestion` whether to publish.

Publish a **new artifact** for each period, not a new version of the last one: each report is a fixed record of its period. Title it `Vendor inventory — <period>`, with `short_title` `Vendors <period>`. Set props with `list_props` for the options: `type: Reference`, `tier: Memo`, and the closest `initiative`. Fix any convention warnings `publish` returns in a second version.

Leave earlier reports Current. Give the user the new report's URL.
