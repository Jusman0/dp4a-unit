`timescale 1ns/1ps
// dp4a: four-way int8 dot product with 32-bit accumulate.
//
//   d = c + a[0]*b[0] + a[1]*b[1] + a[2]*b[2] + a[3]*b[3]
//
// a and b each pack four bytes, byte 0 in bits [7:0]. a_signed / b_signed
// pick int8 or uint8 for each operand, like PTX dp4a.{s32,u32}.{s32,u32}.
// The add into c wraps modulo 2^32, the same as a 32-bit integer register.
//
// Purely combinational. dp4a_pipe.v is the pipelined version.

module dp4a (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [31:0] c,
    input  wire        a_signed,
    input  wire        b_signed,
    output wire [31:0] d
);
    wire [71:0] prod;   // four 18-bit signed products, lane i in [18*i +: 18]

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

    // 4 x 18-bit -> 20-bit signed. Worst case 4 * 65025 = 260100 < 2^19.
    wire signed [19:0] sum = $signed(prod[17:0])  + $signed(prod[35:18])
                           + $signed(prod[53:36]) + $signed(prod[71:54]);

    // Sign-extend the sum to 32 bits, then a plain 32-bit add (wraps).
    assign d = c + {{12{sum[19]}}, sum};
endmodule
