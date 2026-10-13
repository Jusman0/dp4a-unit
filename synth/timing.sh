#!/usr/bin/env bash
# Place and route both versions on an iCE40 HX8K and report max clock frequency.
# Needs yosys and nextpnr-ice40. Run from the repo root:  bash synth/timing.sh
#
# Other builds of the tools can be named, e.g. the YoWASP (pip) ones:
#   YOSYS=yowasp-yosys NEXTPNR=yowasp-nextpnr-ice40 bash synth/timing.sh
#
# Works on macOS and Linux: the number is pulled out of the log with sed,
# because the grep that ships with macOS has no -P option.
set -e
YOSYS=${YOSYS:-yosys}
NEXTPNR=${NEXTPNR:-nextpnr-ice40}
mkdir -p sim

# print the tool versions: results can differ between versions
$YOSYS -V
$NEXTPNR --version

for top in dp4a_1stage dp4a_2stage; do
  $YOSYS -q -p "read_verilog rtl/int8_mul.v rtl/dp4a.v rtl/dp4a_pipe.v synth/timing_wrappers.v; \
               synth_ice40 -top $top -json sim/$top.json"
  for seed in 1 2 3; do
    # nextpnr exits with an error when a seed misses the 50 MHz target. Keep
    # going so every seed is reported, and print that exit code, not hide it.
    rm -f sim/${top}_s$seed.log        # never report an old run's number
    status=0
    $NEXTPNR --hx8k --package ct256 --json sim/$top.json --seed $seed \
      --freq 50 --quiet --log sim/${top}_s$seed.log || status=$?
    # The last "Max frequency" line in the log is the post-route result, e.g.
    #   Info: Max frequency for clock '...': 88.50 MHz (PASS at 50.00 MHz)
    result=$(sed -n "s/.*Max frequency for clock '[^']*': //p" sim/${top}_s$seed.log | tail -1)
    if [ -z "$result" ]; then
      echo "$top seed $seed: no max frequency in sim/${top}_s$seed.log (nextpnr exit $status)"
      exit 1
    fi
    echo "$top seed $seed: $result  (nextpnr exit $status)"
  done
done
