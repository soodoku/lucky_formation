#!/usr/bin/env python3
"""Write the results table in README.md from tabs/primary_results.csv.

The block between the RESULTS markers is regenerated on every `make paper`, so the README
cannot drift from the estimates.
"""

import re
from pathlib import Path

import pandas as pd

START, END = "<!-- RESULTS:START -->", "<!-- RESULTS:END -->"


def table() -> str:
    r = pd.read_csv("tabs/primary_results.csv")
    lines = [
        "| Pre-specified test | Effect, % [95% CI] | p, calendar shift (Holm) | MDE, % |",
        "|---|---|---|---|",
    ]
    for _, x in r.iterrows():
        lines.append(
            f"| {x['hypothesis']}: {x['label']} | {x['pct']:+.1f} [{x['pct_lo']:+.1f}, "
            f"{x['pct_hi']:+.1f}] | {x['p_shift']:.3f} ({x['p_holm']:.3f}) | "
            f"{x['mde_pct']:.1f} |"
        )
    return "\n".join(lines)


def main() -> None:
    path = Path("README.md")
    text = path.read_text()
    block = f"{START}\n{table()}\n{END}"
    new, n = re.subn(re.escape(START) + r".*?" + re.escape(END), block, text, flags=re.S)
    if n != 1:
        raise SystemExit("README.md must contain exactly one RESULTS block")
    path.write_text(new)


if __name__ == "__main__":
    main()
