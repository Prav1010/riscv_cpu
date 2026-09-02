`timescale 1ns/1ps

// Bitwise logic unit: AND, OR, XOR - computed in parallel, alu.v selects
// the correct one based on the decoded ALU operation.
module alu_logic (
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire [31:0] result_and,
    output wire [31:0] result_or,
    output wire [31:0] result_xor
);

    assign result_and = a & b;
    assign result_or  = a | b;
    assign result_xor = a ^ b;

endmodule