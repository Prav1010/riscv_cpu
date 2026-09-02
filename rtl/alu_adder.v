`timescale 1ns/1ps

// 32-bit ripple-carry adder/subtractor, reused from the configurable_alu
// project's design (see that repo's docs/timing_analysis.md for the
// rationale on choosing ripple-carry). Subtraction via two's-complement:
// A - B = A + (~B) + 1.
module alu_adder (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire        sub,        // 0 = add, 1 = subtract (A - B)
    output wire [31:0] result,
    output wire         carry_out,
    output wire         overflow
);

    wire [31:0] b_operand;
    wire        carry_in;

    assign b_operand = sub ? ~b : b;
    assign carry_in  = sub;

    assign {carry_out, result} = a + b_operand + carry_in;

    wire a_sign = a[31];
    wire b_sign = b_operand[31];
    wire r_sign = result[31];

    assign overflow = (a_sign == b_sign) && (r_sign != a_sign);

endmodule