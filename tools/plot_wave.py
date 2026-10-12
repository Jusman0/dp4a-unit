"""
Draw the first few clocks of the dp4a testbench waveform as a PNG.

Reads sim/dp4a.vcd (written by `make test`) and plots the testbench-level
signals, so the 2-clock latency of dp4a_pipe is visible without opening a
waveform viewer.

Run from the repo root after `make test`:  python3 tools/plot_wave.py
"""

from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

VCD = Path("sim/dp4a.vcd")
OUT = Path("docs/waveform.png")
SIGNALS = ["clk", "in_valid", "a", "b", "c", "out_valid", "d_pipe"]
T0, T1 = 25_000, 105_000          # ps: just after reset, ~8 clocks


def parse_vcd(path, wanted):
    ids, changes, scope, t = {}, {}, [], 0
    with open(path) as f:
        for line in f:
            tok = line.split()
            if not tok:
                continue
            if tok[0] == "$scope":
                scope.append(tok[2])
            elif tok[0] == "$upscope":
                scope.pop()
            elif tok[0] == "$var" and len(scope) == 1 and tok[4] in wanted:
                ids[tok[3]] = tok[4]
                changes[tok[4]] = []
            elif tok[0].startswith("#"):
                t = int(tok[0][1:])
            elif tok[0][0] in "01xz" and tok[0][1:] in ids:
                changes[ids[tok[0][1:]]].append((t, tok[0][0]))
            elif tok[0][0] == "b" and len(tok) == 2 and tok[1] in ids:
                changes[ids[tok[1]]].append((t, tok[0][1:]))
    return changes


def value_at(ch, t):
    v = ch[0][1]
    for tt, vv in ch:
        if tt > t:
            break
        v = vv
    return v


def segments(ch):
    """[(start, end, value)] clipped to the plot window."""
    pts = [(T0, value_at(ch, T0))] + [(t, v) for t, v in ch if T0 < t < T1]
    out = []
    for i, (t, v) in enumerate(pts):
        end = pts[i + 1][0] if i + 1 < len(pts) else T1
        if out and out[-1][2] == v:
            out[-1] = (out[-1][0], end, v)
        else:
            out.append((t, end, v))
    return out


def to_hex(bits):
    if any(c in "xz" for c in bits):
        return "x"
    return f"{int(bits, 2):08x}"


def main():
    ch = parse_vcd(VCD, SIGNALS)
    fig, ax = plt.subplots(figsize=(11, 4.2))
    ns = lambda t: t / 1000
    for row, name in enumerate(SIGNALS):
        y = len(SIGNALS) - 1 - row
        segs = segments(ch[name])
        if name in ("clk", "in_valid", "out_valid"):
            xs, ys = [], []
            for s, e, v in segs:
                level = y + (0.7 if v == "1" else 0.1)
                xs += [ns(s), ns(e)]
                ys += [level, level]
            ax.plot(xs, ys, color="#1f5fa8", lw=1.6, drawstyle="default")
        else:
            for s, e, v in segs:
                x0, x1, d = ns(s), ns(e), 0.6
                ax.plot([x0, x0 + d, x1 - d, x1, x1 - d, x0 + d, x0],
                        [y + .4, y + .7, y + .7, y + .4, y + .1, y + .1, y + .4],
                        color="#1f5fa8", lw=1.2)
                if x1 - x0 > 6:
                    ax.text((x0 + x1) / 2, y + .4, to_hex(v), ha="center",
                            va="center", fontsize=7.5, family="monospace")
        ax.text(ns(T0) - 1.5, y + .4, name, ha="right", va="center",
                fontsize=9, family="monospace")

    # mark the first input and the matching output two rising edges later
    first_in = next(t for t, v in ch["in_valid"] if v == "1" and t >= T0)
    first_out = next(t for t, v in ch["out_valid"] if v == "1" and t >= T0)
    for t in (first_in, first_out):
        ax.axvline(ns(t), color="#c0392b", ls=":", lw=1)
    ax.annotate("", xy=(ns(first_out), len(SIGNALS) - 0.15),
                xytext=(ns(first_in), len(SIGNALS) - 0.15),
                arrowprops=dict(arrowstyle="<->", color="#c0392b"))
    ax.text((ns(first_in) + ns(first_out)) / 2, len(SIGNALS) - 0.05,
            "result appears 2 rising edges later, then one per clock",
            ha="center", va="bottom", fontsize=8.5, color="#c0392b")

    ax.set_xlim(ns(T0), ns(T1))
    ax.set_ylim(-0.2, len(SIGNALS) + 0.35)
    ax.set_yticks([])
    ax.set_xlabel("time (ns), 10 ns clock")
    for side in ("left", "right", "top"):
        ax.spines[side].set_visible(False)
    fig.tight_layout()
    OUT.parent.mkdir(exist_ok=True)
    fig.savefig(OUT, dpi=150)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
