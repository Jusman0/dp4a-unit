`timescale 1ns/1ps
// dp4a_pipe: the same operation as dp4a, split into two pipeline stages so
// the multipliers and the adder tree don't have to fit in one clock period.
//
//   stage 1: four int8 multiplies, products registered
//   stage 2: add the four products and c, result registered
//
// Throughput: one new dp4a per clock. Latency: 2 clocks (in_valid -> out_valid).

module dp4a_pipe (
    input  wire        clk,
    input  wire        rst,
    input  wire        in_valid,
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [31:0] c,
    input  wire        a_signed,
    input  wire        b_signed,
    output reg         out_valid,
    output reg  [31:0] d
);
    // ---- stage 1: multiply ----
    wire [71:0] prod;
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : lane
            int8_mul u_mul (
                .a(a[8*i +: 8]), .b(b[8*i +: 8]),
                .a_signed(a_signed), .b_signed(b_signed),
                .p(prod[18*i +: 18])
            );
        end
    endgenerate

    reg [71:0] prod_r;
    reg [31:0] c_r;
    reg        v_r;

    always @(posedge clk) begin
        prod_r <= prod;
        c_r    <= c;
        v_r    <= rst ? 1'b0 : in_valid;
    end

    // ---- stage 2: adder tree + accumulate ----
    wire signed [19:0] sum = $signed(prod_r[17:0])  + $signed(prod_r[35:18])
                           + $signed(prod_r[53:36]) + $signed(prod_r[71:54]);

    always @(posedge clk) begin
        d         <= c_r + {{12{sum[19]}}, sum};
        out_valid <= rst ? 1'b0 : v_r;
    end
endmodule
