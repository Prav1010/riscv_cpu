`timescale 1ns/1ps

// Shift unit: SLL (shift left logical), SRL (shift right logical),
// SRA (shift right arithmetic). Shift amount is the low 5 bits of B
// (RV32I defines shift amount as shamt[4:0] for a 32-bit register).
module alu_shift (
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire [31:0] result_sll,
    output wire [31:0] result_srl,
    output wire [31:0] result_sra
);

    wire [4:0] shamt = b[4:0];

    assign result_sll = a << shamt;
    assign result_srl = a >> shamt;
    assign result_sra = $signed(a) >>> shamt;

endmodule