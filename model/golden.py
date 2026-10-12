"""
Golden model and test-vector generator for the dp4a RTL.

Writes three things into tests/:

  dp4a_vectors.hex   10,000 random + edge-case dp4a operations with the
                     expected result, across all four signed/unsigned modes
  w1q.hex, x_test.hex, acc1_expected.hex
                     layer 1 of the TinyML MNIST network (32 neurons x 196
                     inputs) and its 5 test images, packed 4 int8 per word,
                     plus the int32 accumulators the network should produce

The expected values come from plain Python integers, so they are independent
of the Verilog. The TinyML expectations are also checked against NumPy.

Run from the repo root:  python3 model/golden.py
"""

import random
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
TESTS = ROOT / "tests"
N_VECTORS = 10_000
MASK32 = 0xFFFF_FFFF


def byte_value(word, lane, signed):
    v = (word >> (8 * lane)) & 0xFF
    return v - 256 if signed and v >= 128 else v


def dp4a(a, b, c, a_signed, b_signed):
    """d = c + sum(a_i * b_i), wrapping to 32 bits like the hardware."""
    s = sum(byte_value(a, i, a_signed) * byte_value(b, i, b_signed)
            for i in range(4))
    return (c + s) & MASK32


def pack4(int8s):
    """Four int8 values -> one 32-bit word, element 0 in the low byte."""
    return sum((int(v) & 0xFF) << (8 * i) for i, v in enumerate(int8s))


def edge_cases():
    hi, lo = 0x7F7F7F7F, 0x80808080
    ones, zero = 0xFFFF_FFFF, 0
    cases = []
    for a_s in (0, 1):
        for b_s in (0, 1):
            for a, b in ((lo, lo), (hi, hi), (lo, hi), (ones, ones),
                         (ones, lo), (zero, ones), (0x01FF7F80, 0x80FF7F01)):
                for c in (0, 1, 0x7FFF_FFFF, 0x8000_0000, MASK32):
                    cases.append((a, b, c, a_s, b_s))
    return cases


def write_vectors(rng):
    vecs = edge_cases()
    while len(vecs) < N_VECTORS:
        vecs.append((rng.getrandbits(32), rng.getrandbits(32),
                     rng.getrandbits(32), rng.getrandbits(1), rng.getrandbits(1)))
    with open(TESTS / "dp4a_vectors.hex", "w") as f:
        # one line per vector: mode nibble (a_signed b_signed), a, b, c, d
        for a, b, c, a_s, b_s in vecs:
            d = dp4a(a, b, c, a_s, b_s)
            f.write(f"{a_s * 2 + b_s:01x}{a:08x}{b:08x}{c:08x}{d:08x}\n")
    return len(vecs)


def write_tinyml():
    m = np.load(ROOT / "model" / "tinyml_layer1.npz")
    w1q, x = m["W1q"], m["x_test"]          # (32, 196), (5, 196) int8
    n_hid, n_in = w1q.shape
    beats = n_in // 4

    with open(TESTS / "w1q.hex", "w") as f:
        for j in range(n_hid):
            for k in range(beats):
                f.write(f"{pack4(w1q[j, 4 * k:4 * k + 4]):08x}\n")
    with open(TESTS / "x_test.hex", "w") as f:
        for img in x:
            for k in range(beats):
                f.write(f"{pack4(img[4 * k:4 * k + 4]):08x}\n")

    # expected accumulators, computed two independent ways
    ref = x.astype(np.int64) @ w1q.T.astype(np.int64)
    with open(TESTS / "acc1_expected.hex", "w") as f:
        for i in range(len(x)):
            for j in range(n_hid):
                acc = 0
                for k in range(beats):
                    acc = dp4a(pack4(x[i, 4 * k:4 * k + 4]),
                               pack4(w1q[j, 4 * k:4 * k + 4]), acc, 1, 1)
                assert acc == int(ref[i, j]) & MASK32
                f.write(f"{acc:08x}\n")
    return len(x), n_hid, beats


def main():
    TESTS.mkdir(exist_ok=True)
    n = write_vectors(random.Random(2026))
    n_img, n_hid, beats = write_tinyml()
    print(f"wrote {n} dp4a vectors")
    print(f"wrote TinyML layer 1: {n_img} images x {n_hid} neurons, "
          f"{beats} dp4a beats per neuron")


if __name__ == "__main__":
    main()
