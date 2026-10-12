# dp4a-unit

A Verilog implementation of **DP4A**: four int8 multiplies summed into a 32-bit accumulator in a single operation. NVIDIA added DP4A to Pascal GPUs (compute capability 6.1) to speed up int8 inference. This version is verified bit-exact against a Python golden model and used to compute layer 1 of my [TinyML MNIST network](https://github.com/Jusman0/tinyml-mnist-uno).

```
d = c + a[0]*b[0] + a[1]*b[1] + a[2]*b[2] + a[3]*b[3]      a, b: four int8 packed in 32 bits
```

| Check | Result |
|---|---|
| 10,000 random and edge-case vectors, all four signed/unsigned modes | **10,000 / 10,000 bit-exact**, combinational and pipelined |
| TinyML layer 1: 5 test images × 32 neurons × 196 inputs | **160 / 160** int32 accumulators match NumPy and the Arduino |
| Max clock on an iCE40 HX8K FPGA, single stage | 51.6 MHz (median of 3 placement seeds) |
| Max clock, two-stage pipeline | **88.5 MHz**, 1.7× faster for one extra clock of latency |
| iCE40 resources, two-stage | 1,043 LUT4s, 138 flip-flops, 93 carry cells |

## Why DP4A

Almost all the work in a quantized neural network is int8 dot products. One neuron in the TinyML network has 196 inputs, which is 196 multiply-accumulates (MACs). The Arduino does them one at a time, while DP4A does four per operation, so the neuron takes 49 steps. GPU tensor cores take the same idea much further, with whole matrix tiles per instruction.

## Design

```
 a[ 7: 0] b[ 7: 0] ─► int8_mul ─┐
 a[15: 8] b[15: 8] ─► int8_mul ─┤        stage 1               stage 2
 a[23:16] b[23:16] ─► int8_mul ─┼─► [ product regs ] ─► adder tree ─► + c ─► [ reg ] ─► d
 a[31:24] b[31:24] ─► int8_mul ─┘
```

- **`int8_mul`: one multiplier for every sign mode.** Each byte is widened to 9-bit signed first. An int8 copies its sign bit, and a uint8 gets a 0 on top. After that, a single signed 9×9 multiplier handles int8×int8, int8×uint8 and uint8×uint8, so `a_signed` / `b_signed` work like PTX `dp4a.{s32,u32}.{s32,u32}`.
- **Bit widths.** Products are 18 bits (worst case 255 × 255 = 65,025), and the four-way sum is 20 bits (worst case 260,100). The sum is sign-extended to 32 bits and added to `c` modulo 2^32, the same way a 32-bit register wraps.
- **`dp4a_pipe`: two stages.** In one cycle, a signal has to pass through a multiplier, an adder tree and a 32-bit adder. Putting registers after the multipliers splits that path roughly in half. Place-and-route on an iCE40 shows the payoff: the clock rises from 51.6 to 88.5 MHz, at the cost of one extra cycle of latency. Throughput stays at one DP4A per clock.
- **`dot_engine`: streaming dot product.** One DP4A feeding back into an accumulator. A `first` flag starts a new dot product from 0 on its first beat, so there's no wasted clear cycle between neurons.

## Verification

[`model/golden.py`](model/golden.py) computes every expected result with plain Python integers, independent of the Verilog. It writes the vectors to `tests/`, and the testbenches compare the RTL against them bit for bit.

- **Directed edge cases:** -128 × -128, 127 × 127, 255 × 255, mixed signs, and accumulators at 0, 2^31 - 1, 2^31 and 2^32 - 1 to exercise wraparound, all in each of the four sign modes.
- **Random vectors** fill the rest of the 10,000.
- **Real data:** the TinyML layer-1 weights and test images, checked against NumPy's int32 matrix multiply.

To check the checks, I planted two bugs. Treating operand `a` as always unsigned dropped the vector test to 5,456 / 10,000. Narrowing the adder tree to 16 bits dropped it to 7,077 / 10,000. The TinyML test alone missed both, because image pixels are never negative and real sums stay small. That's why it takes directed and random vectors, not just real data.

## Run it

Needs [Icarus Verilog](https://steveicarus.github.io/iverilog/) (`brew install icarus-verilog`). GTKWave shows the waveforms. Yosys and nextpnr-ice40 (both in the [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build)) are only needed for synthesis.

```bash
make test               # both testbenches, prints PASS / FAIL
make wave               # dp4a testbench + waveform in GTKWave
make synth              # gate counts: generic and iCE40
bash synth/timing.sh    # place and route, max clock frequency
python3 model/golden.py # regenerate tests/*.hex
```

## Layout

```
rtl/int8_mul.v          one lane: int8/uint8 x int8/uint8 -> 18-bit signed
rtl/dp4a.v              combinational dp4a
rtl/dp4a_pipe.v         two-stage pipelined dp4a
rtl/dot_engine.v        streaming dot product built on dp4a
tb/tb_dp4a.v            10,000-vector bit-exact check, both versions
tb/tb_tinyml_neuron.v   TinyML layer 1 through dot_engine
model/golden.py         Python golden model and vector generator
model/tinyml_layer1.npz layer-1 weights and test images from tinyml-mnist-uno
synth/                  Yosys scripts, timing wrappers, place-and-route script
```

## Series

Each project builds the same neural-network operation one level closer to a GPU:

1. [analog-neuron](https://github.com/Jusman0/analog-neuron): a weighted sum computed by resistors
2. [tinyml-mnist-uno](https://github.com/Jusman0/tinyml-mnist-uno): the network in int8 on an 8-bit CPU, one MAC at a time
3. **dp4a-unit**: the int8 dot product as dedicated hardware, four MACs per clock
4. tiny-tensor-core (next): 32 MACs in parallel running the whole network
