`timescale 1ns/1ps
// dot_engine: a streaming int8 dot product built on one dp4a.
//
// Feed four int8 pairs per clock with `valid`. Raise `first` on the first
// beat of a new dot product so it starts from 0 instead of the old total.
// `acc` holds the running int32 sum.
//
// A 196-input neuron from the TinyML network takes 49 beats.

module dot_engine (
    input  wire        clk,
    input  wire        rst,
    input  wire        valid,
    input  wire        first,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output reg  [31:0] acc
);
    wire [31:0] next;

    dp4a u_dp4a (
        .a(a), .b(b),
        .c(first ? 32'd0 : acc),
        .a_signed(1'b1), .b_signed(1'b1),
        .d(next)
    );

    always @(posedge clk) begin
        if (rst)        acc <= 32'd0;
        else if (valid) acc <= next;
    end
endmodule
