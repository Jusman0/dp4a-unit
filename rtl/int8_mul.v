`timescale 1ns/1ps
// int8_mul: one lane of dp4a. Multiplies two bytes, each read as int8 or
// uint8 depending on its *_signed flag.
//
// Trick: widen both bytes to 9-bit signed first. int8 copies its sign bit
// (two's complement sign extension), uint8 gets a 0 on top. After that a
// single signed multiplier is correct for all four signed/unsigned mixes.
//
//   9b x 9b -> 18b signed. Range: -32640 (-128 * 255) .. 65025 (255 * 255)

module int8_mul (
    input  wire        [7:0]  a,
    input  wire        [7:0]  b,
    input  wire               a_signed,
    input  wire               b_signed,
    output wire signed [17:0] p
);
    wire signed [8:0] ax = {a_signed & a[7], a};
    wire signed [8:0] bx = {b_signed & b[7], b};
    assign p = ax * bx;
endmodule
