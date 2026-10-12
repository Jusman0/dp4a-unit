# make test    run both testbenches (needs Icarus Verilog)
# make vectors regenerate tests/*.hex from the Python golden model
# make wave    run the dp4a testbench and open the waveform in GTKWave
# make synth   synthesis report with Yosys (generic gates and iCE40 FPGA)

IVERILOG = iverilog -g2005 -Wall
RTL = rtl/int8_mul.v rtl/dp4a.v rtl/dp4a_pipe.v rtl/dot_engine.v

.PHONY: test vectors wave synth clean

test: sim/tb_dp4a sim/tb_tinyml_neuron
	vvp -n sim/tb_dp4a
	vvp -n sim/tb_tinyml_neuron

sim/%: tb/%.v $(RTL) | sim
	$(IVERILOG) -o $@ $(RTL) $<

sim:
	mkdir -p sim

vectors:
	python3 model/golden.py

wave: sim/tb_dp4a
	vvp -n sim/tb_dp4a
	gtkwave sim/dp4a.vcd

synth:
	yosys -q -s synth/generic.ys
	yosys -q -s synth/ice40.ys

clean:
	rm -rf sim
