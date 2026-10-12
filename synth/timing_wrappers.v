`timescale 1ns/1ps
// Synthesis-only wrappers so both versions are timed register to register:
// inputs are registered first, outputs come from registers.

// One stage: registered inputs -> combinational dp4a -> registered output
module dp4a_1stage (
    input  wire        clk,
    input  wire [31:0] a, b, c,
    input  wire        a_signed, b_signed,
    output reg  [31:0] d
);
    reg [31:0] a_r, b_r, c_r;
    reg        as_r, bs_r;
    wire [31:0] d_w;
    always @(posedge clk) begin
        {a_r, b_r, c_r, as_r, bs_r} <= {a, b, c, a_signed, b_signed};
        d <= d_w;
    end
    dp4a u (.a(a_r), .b(b_r), .c(c_r), .a_signed(as_r), .b_signed(bs_r), .d(d_w));
endmodule

// Two stages: registered inputs -> dp4a_pipe (multiply | add)
module dp4a_2stage (
    input  wire        clk,
    input  wire [31:0] a, b, c,
    input  wire        a_signed, b_signed,
    output wire [31:0] d
);
    reg [31:0] a_r, b_r, c_r;
    reg        as_r, bs_r;
    always @(posedge clk) {a_r, b_r, c_r, as_r, bs_r} <= {a, b, c, a_signed, b_signed};
    wire unused_valid;
    dp4a_pipe u (.clk(clk), .rst(1'b0), .in_valid(1'b1),
                 .a(a_r), .b(b_r), .c(c_r), .a_signed(as_r), .b_signed(bs_r),
                 .out_valid(unused_valid), .d(d));
endmodule
