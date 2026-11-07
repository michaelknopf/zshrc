"""Render a vendor report page from its inventory JSON.

Usage: uv run build_report.py inventory.json index.html
"""
import html
import json
import re
import string
import sys
from datetime import date
from pathlib import Path

from charts import Balance, CostCharts, Split, balances

TEMPLATE = string.Template(Path(__file__).with_name("template.html").read_text())


def e(s: str) -> str:
    return html.escape(s, quote=True)


def slug(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def usd(x: float) -> str:
    return "—" if not x else f"${x:,.0f}"


def split(d: dict) -> Split:
    return Split(d.get("paid", 0), d.get("prepaid", 0), d.get("credits", 0))


class Report:
    def __init__(self, inv: dict):
        self.inv = inv
        self.as_of = date.fromisoformat(inv["as_of"])
        self.period_label = inv["period_label"]
        self.month_name = self.period_label.split()[0]

    def vendors(self, group: str) -> list[dict]:
        return [v for v in self.inv["vendors"] if v["group"] == group]

    def balance_rows(self) -> list[Balance]:
        rows = [
            Balance(c["name"], c["granted_usd"], c["granted_usd"] - c["remaining_usd"], c["monthly_burn_usd"],
                    date.fromisoformat(c["ends"]), f"ends {date.fromisoformat(c['ends']):%b %-d, %Y}", "credits")
            for c in self.inv["credits"] if c.get("chart", True)
        ]
        for p in self.inv.get("prepaid", []):
            per_unit = p["price_usd"] / p["limit"]
            rows.append(Balance(p["name"], p["price_usd"], p["used_total"] * per_unit, p["monthly_units"] * per_unit,
                                date.fromisoformat(p["ends"]), p["term_label"], "prepaid"))
        return rows

    def paid_rows(self) -> str:
        out = []
        for v in sorted(self.vendors("paid-in-code"), key=lambda v: -v["ttm_spend"]):
            a = f"vendor-{v['ramp_id']}"
            details = [("Purpose", v["purpose"]), ("Repos", ", ".join(v["repos"])), ("Billing", v.get("billing") or "")]
            out.append(
                f"<tr class='row' data-anchor='{a}'><td><button type='button' class='exp' aria-expanded='false'>{e(v['name'])}</button></td>"
                f"<td class='n'>{usd(v['period_spend'])}</td><td class='n'>{usd(v['ttm_spend'])}</td><td class='n'>{v['active_months']}</td></tr>"
                f"<tr class='more' data-anchor='{a}-detail' hidden><td colspan='4'>{kv(details)}</td></tr>"
            )
        return "".join(out)

    def code_rows(self) -> str:
        out = []
        for v in self.vendors("code-only"):
            a = f"vendor-{slug(v['name'])}"
            out.append(
                f"<tr class='row' data-anchor='{a}'><td><button type='button' class='exp' aria-expanded='false'>{e(v['name'])}</button></td>"
                f"<td>{e(v['purpose'])}</td><td class='dim'>{e(v.get('billing') or '—')}</td></tr>"
                f"<tr class='more' data-anchor='{a}-detail' hidden><td colspan='3'>{kv([('Repos', ', '.join(v['repos']) or 'keyfile only')])}</td></tr>"
            )
        return "".join(out)

    def other_rows(self, group: str) -> str:
        rows = "".join(
            f"<tr data-anchor='vendor-{v['ramp_id'] or slug(v['name'])}'><td>{e(v['name'])}</td><td>{e(v['purpose'])}</td>"
            f"<td class='n'>{usd(v['period_spend'])}</td><td class='n'>{usd(v['ttm_spend'])}</td></tr>"
            for v in self.vendors(group)
        )
        return rows or "<tr><td colspan='4' class='empty'>None</td></tr>"

    def history(self) -> str:
        reports = self.inv.get("previous_reports", [])
        if not reports:
            return "<p class='empty' data-anchor='history-none'>None. This is the first report.</p>"
        items = "".join(f"<li data-anchor='history-{e(r['period'])}'><a href='{e(r['url'])}' target='_blank'>{e(r['period'])}</a></li>" for r in reports)
        return f"<ul data-anchor='history-list'>{items}</ul>"

    def render(self) -> str:
        cost = self.inv["cost"]
        months = [(m["label"], split(m)) for m in cost["months"]]
        charts = CostCharts(months, [(v["name"], split(v)) for v in cost["by_vendor"]], self.period_label)
        captions = cost["captions"]
        inventory = json.dumps(self.inv, indent=1).replace("</", "<\\/")
        return TEMPLATE.substitute(
            period_label=self.period_label, month_name=self.month_name,
            total=f"${months[-1][1].total:,.0f}",
            composition=charts.composition(), by_vendor=charts.vendors(), trend=charts.trend(),
            balances=balances(self.balance_rows(), self.as_of, self.month_name),
            balances_as_of=f"{self.as_of:%b} {self.as_of.day}",
            by_vendor_caption=e(captions["by_vendor"]), trend_caption=e(captions["trend"]),
            balances_caption=e(captions["balances"]),
            coverage="".join(f"<li data-anchor='coverage-{i}'>{e(c)}</li>" for i, c in enumerate(self.inv["coverage"])),
            paid_rows=self.paid_rows(), code_rows=self.code_rows(),
            noneng_rows=self.other_rows("non-engineering"), tooling_rows=self.other_rows("tooling"),
            unclassified_rows=self.other_rows("unclassified"),
            history=self.history(), inventory=inventory,
        )


def kv(pairs: list[tuple[str, str]]) -> str:
    return "<dl class='kv'>" + "".join(f"<div><dt>{e(a)}</dt><dd>{e(b)}</dd></div>" for a, b in pairs if b) + "</dl>"


if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    Path(dst).write_text(Report(json.loads(Path(src).read_text())).render())
    print(dst)
