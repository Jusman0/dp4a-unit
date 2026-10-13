// tb_tinyml_neuron: runs layer 1 of the TinyML MNIST network through
// dot_engine. Every neuron is a 196-input int8 dot product, streamed in
// as 49 dp4a beats. The int32 results must equal the accumulators NumPy
// computes for the network (the Arduino sketch only prints logits, so its
// accumulators can't be compared directly).
`timescale 1ns/1ps

module tb_tinyml_neuron;
    localparam N_IMG = 5, N_HID = 32, BEATS = 49;

    reg [31:0] w        [0:N_HID*BEATS-1];   // weights, neuron-major
    reg [31:0] x        [0:N_IMG*BEATS-1];   // test images
    reg [31:0] expected [0:N_IMG*N_HID-1];   // int32 accumulators

    reg clk = 1'b0;
    always #5 clk = ~clk;
    reg rst = 1'b1;

    reg         valid, first;
    reg  [31:0] a, b;
    wire [31:0] acc;

    dot_engine dut (
        .clk(clk), .rst(rst), .valid(valid), .first(first),
        .a(a), .b(b), .acc(acc)
    );

    integer img, j, k, n_ok, errs = 0, beats = 0;

    initial begin
        $readmemh("tests/w1q.hex", w);
        $readmemh("tests/x_test.hex", x);
        $readmemh("tests/acc1_expected.hex", expected);

        {valid, first, a, b} = 0;
        repeat (2) @(negedge clk);
        rst = 1'b0;

        for (img = 0; img < N_IMG; img = img + 1) begin
            n_ok = 0;
            for (j = 0; j < N_HID; j = j + 1) begin
                for (k = 0; k < BEATS; k = k + 1) begin
                    @(negedge clk);
                    valid = 1'b1;
                    first = (k == 0);
                    a = x[img*BEATS + k];
                    b = w[j*BEATS + k];
                    beats = beats + 1;
                end
                @(negedge clk);
                valid = 1'b0;
                if (acc === expected[img*N_HID + j]) n_ok = n_ok + 1;
                else begin
                    errs = errs + 1;
                    $display("  img %0d neuron %0d: got %0d, want %0d", img, j,
                             $signed(acc), $signed(expected[img*N_HID + j]));
                end
                if (img == 0 && j == 0)
                    $display("image 0, neuron 0: acc = %0d (expected %0d)",
                             $signed(acc), $signed(expected[0]));
            end
            $display("image %0d: %0d/%0d neurons match", img, n_ok, N_HID);
        end

        $display("%0d dp4a beats for %0d neurons (%0d per neuron)",
                 beats, N_IMG * N_HID, BEATS);
        if (errs == 0) $display("PASS"); else $display("FAIL");
        $finish;
    end
endmodule
