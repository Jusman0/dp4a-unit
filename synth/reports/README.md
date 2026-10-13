# Synthesis re-run (iCE40)

Re-run on 2026-10-12 on an Apple M2 with Yosys 0.69, the YoWASP (pip) build (`tool_versions.txt`). The command was `make synth` with `yosys` replaced by `yowasp-yosys`.

**Resources.** `ice40_stat_yosys-0.69.txt` is the `stat` output for `dp4a_pipe` on an iCE40:
- 1,013 SB_LUT4
- 138 flip-flops (136 SB_DFF + 2 SB_DFFSR)
- 93 SB_CARRY

The committed `synth/ice40_stat.txt` was made with an older Yosys whose version wasn't recorded. It shows 1,043 SB_LUT4, with the same flip-flop and carry counts. `make synth` rewrites `synth/*_stat.txt` with whatever Yosys you have installed.

**No timing logs.** The 51.6 and 88.5 MHz in the main README came from earlier `synth/timing.sh` runs, and their nextpnr-ice40 logs weren't kept. nextpnr-ice40 wasn't available for this re-run, so both numbers are unlogged estimates. With nextpnr-ice40 installed, `bash synth/timing.sh` regenerates them and writes the logs to `sim/`.
