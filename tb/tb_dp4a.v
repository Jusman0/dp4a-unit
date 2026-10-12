// tb_dp4a: drives every vector from tests/dp4a_vectors.hex through both the
// combinational dp4a and the 2-stage dp4a_pipe, and checks each result
// against the Python golden model, bit for bit.
`timescale 1ns/1ps

module tb_dp4a;
    localparam N = 10000;

    // one vector = {mode nibble, a, b, c, expected d}
    reg [131:0] vec [0:N-1];

    reg clk = 1'b0;
    always #5 clk = ~clk;
    reg rst = 1'b1;

    reg  [31:0] a, b, c;
    reg         a_signed, b_signed, in_valid;
    wire [31:0] d_comb, d_pipe;
    wire        out_valid;

    dp4a dut_comb (
        .a(a), .b(b), .c(c), .a_signed(a_signed), .b_signed(b_signed),
        .d(d_comb)
    );

    dp4a_pipe dut_pipe (
        .clk(clk), .rst(rst), .in_valid(in_valid),
        .a(a), .b(b), .c(c), .a_signed(a_signed), .b_signed(b_signed),
        .out_valid(out_valid), .d(d_pipe)
    );

    integer i;
    integer err_comb = 0, err_pipe = 0, n_out = 0;

    // Pipelined results come out in order, two clocks after they went in.
    always @(posedge clk) begin
        if (out_valid) begin
            if (d_pipe !== vec[n_out][31:0]) begin
                if (err_pipe < 5)
                    $display("PIPE MISMATCH #%0d: got %h, want %h", n_out,
                             d_pipe, vec[n_out][31:0]);
                err_pipe = err_pipe + 1;
            end
            n_out = n_out + 1;
        end
    end

    initial begin
        $readmemh("tests/dp4a_vectors.hex", vec);
        $dumpfile("sim/dp4a.vcd");
        $dumpvars(0, tb_dp4a);

        {a, b, c, a_signed, b_signed, in_valid} = 0;
        repeat (2) @(negedge clk);
        rst = 1'b0;

        for (i = 0; i < N; i = i + 1) begin
            @(negedge clk);
            {a_signed, b_signed} = vec[i][129:128];
            a = vec[i][127:96];
            b = vec[i][95:64];
            c = vec[i][63:32];
            in_valid = 1'b1;
            #1;
            if (d_comb !== vec[i][31:0]) begin
                if (err_comb < 5)
                    $display("COMB MISMATCH #%0d: got %h, want %h", i,
                             d_comb, vec[i][31:0]);
                err_comb = err_comb + 1;
            end
            if (i == 40) $dumpoff;     // keep the waveform file small
        end
        @(negedge clk) in_valid = 1'b0;
        repeat (4) @(negedge clk);

        $display("dp4a       (combinational): %0d/%0d match", N - err_comb, N);
        $display("dp4a_pipe  (2-stage)      : %0d/%0d match, %0d results out",
                 n_out - err_pipe, N, n_out);
        if (err_comb == 0 && err_pipe == 0 && n_out == N)
            $display("PASS");
        else
            $display("FAIL");
        $finish;
    end
endmodule
