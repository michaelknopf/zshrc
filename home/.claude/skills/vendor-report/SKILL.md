---
name: vendor-report
disable-model-invocation: true
description: Build this period's vendor cost report (cash, prepaid plans, credits, credit balances) and vendor inventory, and publish it to Museum
argument-hint: "[--month | --quarter] [period, e.g. 2026-11 or 2026-Q4] [previous report URLs or slugs]"
allowed-tools: Bash(uv run:*), Bash(keyfile list:*), Bash(keyfile run:*), Bash(aws secretsmanager list-secrets:*), Bash(aws ce get-cost-and-usage:*), Bash(bq query:*), Bash(curl:*), Bash(mkdir:*), Bash(date:*), Read, Write, AskUserQuestion, ToolSearch, Skill
---

# /vendor-report — Third-party vendor inventory

One report per period. Its front page answers what vendors cost per month, how much of that is cash, prepaid plans and credits, and how long the credits last. Behind it sit the inventory tabs: every vendor we pay or depend on, what it is for and which repos use it. Each run builds a new Museum artifact. The previous report is the starting point, so classifications carry forward and only what changed needs judgment.

Four sources, with different jobs:

- **Ramp decides what we paid.** Card, reimbursement and Bill Pay spend, per merchant. A vendor's charged cost comes only from Ramp.
- **Usage APIs and billing consoles decide what credits and prepaid plans hide.** AWS and GCP run on credits, OpenRouter bills beyond Ramp's top-ups, and Tavily burns a prepaid plan.
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

Read the newest previous report with `get_artifact`. Every report embeds its inventory as JSON in `<script type="application/json" id="vendor-inventory">` (shape in `report/example-inventory.json`). Read the vendor rows from it. A report without that block predates this command: read its tables instead.

Older reports given as arguments are context for trends only. Do not carry a classification from an older report over the newest one.

## Phase 2 — Ramp spend

Find the Ramp MCP's reporting tools with `ToolSearch` (`ramp reporting`). Call `ramp_reporting_get_skill` first and follow it. Use the `spend` dataset; check its field names with `ramp_reporting_describe_dataset` rather than assuming them.

Run these with `query_scope: complete`, in parallel:

1. **This period, per vendor.** `payee` with `amount`, over the period.
2. **Trailing 12 months, per vendor.** `payee` and `spend_date` at month grain, with a `second_stage` keeping `payee` and computing the `SUM`, `COUNT` (active months) and `AVG` of the monthly amount. Active months separates subscriptions from one-off charges.
3. **How each vendor is paid.** `payee`, `category` and `spend_type` with `amount`, over the trailing 12 months.

Keep each payee's Ramp id (`search_tag_info.id`): it is the key that matches vendors across reports, since display names change.

Ramp shows only the spend the signed-in user's role can see. If `ramp_token_info` reports `auth_level: user`, say so in `coverage`.

## Phase 3 — Cost behind credits and prepaid plans

Every cost figure on the front page is **per month**, split three ways:

- **Paid:** cash, from Ramp, leaving out the purchase of a prepaid plan, which is counted under prepaid as it is used.
- **Prepaid:** the share of a prepaid plan used that month. A plan bought once (Tavily) is spread over the months it is used, by usage, not over the calendar. The month it was bought shows only that month's share.
- **Credits:** usage AWS and GCP startup credits covered.

Report one total per vendor. Breakdowns by service, project or model belong in a cost investigation, not this report.

Collect each of these for the **last 12 months**, by month, so the trend chart can be drawn. A previous report's `cost.months` already holds the earlier months: take those, and fetch only the months it lacks.

- **AWS.** Load the `savi:aws-cost-analysis` skill and run its fetch with `--months 12`. Its figures are usage before credits; `record_type_totals` gives the credits applied. Usage counts as credits while a credit balance remains.
- **GCP.** The billing account exports standard usage cost to BigQuery (`savi-security.billing_export`, created in gcp-tf), from November 2026:

  ```bash
  bq query --project_id=savi-security --use_legacy_sql=false --format=prettyjson '
    SELECT invoice.month AS month, ROUND(SUM(cost), 2) AS usage_usd,
           ROUND(SUM(IFNULL((SELECT SUM(c.amount) FROM UNNEST(credits) c), 0)), 2) AS credits_usd
    FROM `savi-security.billing_export.gcp_billing_export_v1_01B643_761629_CA8FDF`
    WHERE invoice.month >= "202511" GROUP BY 1 ORDER BY 1'
  ```

  `cost` is usage before credits, the console's "Usage cost". For months before the export, take them from the previous report, or read the console (Billing → Reports, grouped by month, savings unticked) with Claude in Chrome.
- **OpenRouter.** Sum `usage` across every key in every OpenRouter workspace (`GET https://openrouter.ai/api/v1/keys?workspace_id=…`; the workspace ids are in the previous report's `usage.openrouter.workspaces`). That needs a management key: read it from the macOS keychain (`security find-generic-password -a openrouter -s openrouter-management-key -w`) inside a script that never prints it. If it is missing or expired, ask the user to create one in the OpenRouter dashboard. Leave out `byok_usage`: it is billed to our AWS and GCP accounts, so their usage already counts it.
- **Tavily.** Harbor logs every search. Count the plan credits used per month (an advanced search costs 2, a basic one 1) with the Savi Lake `run_sql` tool:

  ```sql
  SELECT date_trunc('month', created_at)::date AS month,
         SUM(CASE WHEN search_depth = 'advanced' THEN 2 ELSE 1 END) AS credits
  FROM harbor.web_search_tavily_bronze GROUP BY 1 ORDER BY 1
  ```

  A month's prepaid cost is its credits times the plan's price per credit. The plan's price, credits and term are in the previous report's `prepaid`. Check the sum against Tavily's own counter, which should agree within a fraction of a percent:

  ```bash
  keyfile run tavily -- sh -c 'curl -s https://api.tavily.com/usage -H "Authorization: Bearer $SAVI_TAVILY__API_KEY"'
  ```

  Record `account.plan_usage` and `account.plan_limit`. If a new plan has been bought, ask the user for its price and credits.

Never print a key: pass it through `keyfile run` or a script.

### Credit balances

Neither the billing export nor Cost Explorer shows what a credit grant started at, has left, or when it ends. Read both consoles with Claude in Chrome:

- **GCP:** the billing account's Billing → Credits page. Scroll the Issued Credits table right for start and end dates. The Spend-based Milestones tab shows grants still to come.
- **AWS:** the mgmt account's credits page, opened through the user's IAM Identity Center session rather than an IAM sign-in. Build the URL from the `mgmt-sso-read` profile's `sso_start_url`, `sso_account_id` and `sso_role_name`: `<start url>/#/console?account_id=<id>&role_name=<role>&destination=https%3A%2F%2Fus-east-1.console.aws.amazon.com%2Fbilling%2Fhome%23%2Fcredits`. Use the estimated figures: the others lag to the last invoice.

For each grant record what was granted, what is left, when it ends, and the period's credits applied as its monthly burn. Grants promised but not yet issued, such as a tranche that unlocks after part of a grant is used, go in `pending_credits` and the balances chart's caption. Carry them forward from the previous report and drop them once issued or lapsed.

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

Compare with the previous report for your own judgment: new vendors, dropped vendors, and big movers. They do not get their own list on the page; mention one in a chart caption only if it explains the month.

## Phase 6 — Build the artifact

The page is generated from the inventory JSON. Write the JSON, then render it:

```bash
uv run --no-project python "${CLAUDE_SKILL_DIR}/report/build_report.py" inventory.json index.html
```

`report/example-inventory.json` shows the shape with made-up figures; the previous report's embedded JSON is the real starting point. The page has these views:

- **Cost (front page):** the period's monthly total, split into paid, prepaid and credits, then three charts and nothing else: cost by vendor, cost per month over 12 months, and credit and prepaid balances. Credits are always drawn hatched.
- **Paid, Code only, Other spend:** the inventory tables from Phase 5.
- **History:** links to the previous reports.

What you write into the JSON beyond the data:

- **`cost.by_vendor`:** the period's top vendors by total, then one "Everything else" row. About eight rows.
- **`cost.captions`:** one sentence under each chart saying what it shows, in plain words, with no figure the chart already labels unless it is the point.
- **`coverage`:** the data's limits, shown collapsed under the charts. Keep the standing ones from the previous report and add any this period introduces (a role that can't see all Ramp spend, a month read from a console, a missing source).
- **`credits[].chart`:** false for a grant too small to matter on the page, such as support credits. It stays in the JSON.

The generator computes what goes unused or when a balance runs out, assuming this period's burn continues.

Table rows get a `data-anchor` from the vendor's Ramp id, or a slug of its name for a code-only vendor (`vendor-<id>`), so comments stay meaningful across reports. The `*_total` fields are raw running totals; keep their names stable.

Render the page with headless Chrome and look at it before publishing:

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars --virtual-time-budget=4000 --window-size=940,1500 --screenshot="$PWD/report.png" "file://$PWD/index.html"
```

## Phase 7 — Publish

Show the user the screenshot and the headline (the monthly total and its split, and any credit balance that will expire unused or run out), then ask with `AskUserQuestion` whether to publish.

Read Museum's `get_authoring_guide` before the first publish. Publish a **new artifact** for each period, not a new version of the last one: each report is a fixed record of its period. Title it `Vendor inventory — <period>`, with `short_title` `Vendors <period>`. Set props with `list_props` for the options: `type: Reference`, `tier: Memo`, and the closest `initiative`. Fix any convention warnings `publish` returns in a second version.

Leave earlier reports Current. Give the user the new report's URL.
