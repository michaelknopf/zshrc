"""SVG charts for the report's Cost view, drawn from the inventory JSON."""
from dataclasses import dataclass
from datetime import date, timedelta

WIDTH = 860
DAYS_PER_MONTH = 30.44


def k(x: float) -> str:
    return f"${x / 1000:.1f}k" if x >= 1000 else f"${x:,.0f}"


def whole_k(x: float) -> str:
    return f"${x / 1000:.0f}k" if x >= 1000 else f"${x:,.0f}"


def seg(x: float, y: float, w: float, h: float, kind: str) -> str:
    if w <= 0:
        return ""
    fill = {"paid": "var(--paid)", "prepaid": "var(--prepaid)", "credits": "url(#hatch)"}[kind]
    stroke = ' stroke="var(--credit-line)" stroke-width="1"' if kind == "credits" else ""
    return f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" fill="{fill}"{stroke}/>'


def svg(height: float, label: str, body: list[str]) -> str:
    return f'<svg viewBox="0 0 {WIDTH} {height:.0f}" class="chart" role="img" aria-label="{label}">{"".join(body)}</svg>'


@dataclass(frozen=True)
class Split:
    paid: float
    prepaid: float
    credits: float

    @property
    def total(self) -> float:
        return self.paid + self.prepaid + self.credits

    def parts(self) -> list[tuple[float, str]]:
        return [(self.paid, "paid"), (self.prepaid, "prepaid"), (self.credits, "credits")]


@dataclass(frozen=True)
class Balance:
    """A credit grant or prepaid plan, in USD."""

    name: str
    granted: float
    used: float
    monthly_burn: float
    ends: date
    ends_label: str
    kind: str

    def outcome(self, as_of: date, month_name: str) -> str:
        left = self.granted - self.used
        months_left = (self.ends - as_of).days / DAYS_PER_MONTH
        if self.monthly_burn <= 0:
            return f"{whole_k(left)} expires unused"
        if self.monthly_burn * months_left < left:
            return f"~{whole_k(left - self.monthly_burn * months_left)} expires unused at {month_name}'s pace"
        runs_out = as_of + timedelta(days=left / self.monthly_burn * DAYS_PER_MONTH)
        return f"Runs out ~{runs_out:%b} {runs_out.day} at {month_name}'s pace"

    def projected_used(self, as_of: date) -> float:
        months_left = (self.ends - as_of).days / DAYS_PER_MONTH
        return min(self.granted, self.used + self.monthly_burn * max(months_left, 0))


class CostCharts:
    def __init__(self, months: list[tuple[str, Split]], by_vendor: list[tuple[str, Split]], period_label: str):
        self.months = months
        self.by_vendor = by_vendor
        self.period_label = period_label

    def composition(self) -> str:
        split = self.months[-1][1]
        h, x = 34, 0.0
        parts, labels = [], []
        for (v, kind), name in zip(split.parts(), ["Paid", "Prepaid, used", "Credits"]):
            w = WIDTH * v / split.total
            parts.append(seg(x, 0, w, h, kind))
            if v:
                labels.append(f'<text x="{x + 4:.1f}" y="{h + 18}" class="lbl"><tspan class="strong">{k(v)}</tspan> {name}</text>')
            x += w
        return svg(h + 26, f"{self.period_label} cost split", parts + labels)

    def trend(self) -> str:
        h, pad_l, pad_b, top = 260, 8, 22, 34
        step = (WIDTH - pad_l) / len(self.months)
        bw = step * 0.62
        mx = max(s.total for _, s in self.months) * 1.07
        out = []
        for i, (label, split) in enumerate(self.months):
            x = pad_l + i * step + (step - bw) / 2
            y = h - pad_b
            for v, kind in split.parts():
                bar = (h - pad_b - top) * v / mx
                y -= bar
                out.append(seg(x, y, bw, bar, kind))
            out.append(f'<text x="{x + bw / 2:.1f}" y="{h - 6}" class="axis" text-anchor="middle">{label}</text>')
            if i in (0, len(self.months) - 1):
                out.append(f'<text x="{x + bw / 2:.1f}" y="{y - 6:.1f}" class="lbl strong" text-anchor="middle">{k(split.total)}</text>')
        return svg(h, "Monthly cost, last 12 months", out)

    def vendors(self) -> str:
        row, name_w = 34, 150
        mx = max(s.total for _, s in self.by_vendor)
        bar_max = WIDTH - name_w - 90
        out = []
        for i, (name, split) in enumerate(self.by_vendor):
            y, x = i * row + 6, float(name_w)
            for v, kind in split.parts():
                w = bar_max * v / mx
                out.append(seg(x, y, w, row - 14, kind))
                x += w
            out.append(f'<text x="0" y="{y + 15}" class="lbl">{name}</text>')
            out.append(f'<text x="{x + 8:.1f}" y="{y + 15}" class="lbl strong">{k(split.total)}</text>')
        return svg(len(self.by_vendor) * row + 4, f"{self.period_label} cost by vendor", out)


def balances(rows: list[Balance], as_of: date, month_name: str) -> str:
    row, name_w, right_w, h = 62, 170, 190, 22
    bar = WIDTH - name_w - right_w
    out = []
    for i, b in enumerate(rows):
        y = i * row + 4
        used_w = bar * b.used / b.granted
        proj_w = bar * (b.projected_used(as_of) - b.used) / b.granted
        out += [
            f'<rect x="{name_w}" y="{y}" width="{bar}" height="{h}" fill="var(--wash)" stroke="var(--rule)"/>',
            f'<rect x="{name_w + used_w:.1f}" y="{y}" width="{proj_w:.1f}" height="{h}" fill="none" stroke="var(--ink-3)" stroke-dasharray="4 3"/>',
            seg(name_w, y, used_w, h, b.kind),
            f'<text x="0" y="{y + 16}" class="lbl strong">{b.name}</text>',
            f'<text x="{name_w + bar + 12}" y="{y + 10}" class="lbl"><tspan class="strong">{k(b.granted - b.used)} left</tspan> of {k(b.granted)}</text>',
            f'<text x="{name_w + bar + 12}" y="{y + 26}" class="axis">{b.ends_label}</text>',
            f'<text x="{name_w}" y="{y + h + 17}" class="axis">{b.outcome(as_of, month_name)}</text>',
        ]
    return svg(len(rows) * row, "Credit and prepaid balances", out)
