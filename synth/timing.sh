#!/usr/bin/env bash
# Place and route both versions on an iCE40 HX8K and report max clock frequency.
# Needs yosys and nextpnr-ice40. Run from the repo root:  bash synth/timing.sh
set -e
mkdir -p sim
for top in dp4a_1stage dp4a_2stage; do
  yosys -q -p "read_verilog rtl/int8_mul.v rtl/dp4a.v rtl/dp4a_pipe.v synth/timing_wrappers.v; \
               synth_ice40 -top $top -json sim/$top.json"
  for seed in 1 2 3; do
    nextpnr-ice40 --hx8k --package ct256 --json sim/$top.json --seed $seed \
      --freq 50 --quiet --log sim/${top}_s$seed.log 2>/dev/null || true
    fmax=$(grep -oP "Max frequency for clock '.*?': \K[0-9.]+" sim/${top}_s$seed.log | tail -1)
    echo "$top seed $seed: $fmax MHz"
  done
done
