`timescale 1ns/1ps

// ALU for the RV32I CPU - adapted from the configurable_alu project,
// fixed at 32-bit width and extended with SLT/SLTU (set-less-than),
// which RV32I requires but the original standalone ALU project did not.
module alu (
    input  wire [3:0]  alu_op,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output reg  [31:0] result,
    output wire         zero
);

    localparam ALU_ADD  = 4'h0;
    localparam ALU_SUB  = 4'h1;
    localparam ALU_AND  = 4'h2;
    localparam ALU_OR   = 4'h3;
    localparam ALU_XOR  = 4'h4;
    localparam ALU_SLL  = 4'h5;
    localparam ALU_SRL  = 4'h6;
    localparam ALU_SRA  = 4'h7;
    localparam ALU_SLT  = 4'h8;
    localparam ALU_SLTU = 4'h9;

    wire [31:0] add_result, sub_result;
    wire        add_cout, sub_cout, add_ovf, sub_ovf;

    alu_adder u_adder (
        .a(a), .b(b), .sub(1'b0),
        .result(add_result), .carry_out(add_cout), .overflow(add_ovf)
    );

    alu_adder u_subtractor (
        .a(a), .b(b), .sub(1'b1),
        .result(sub_result), .carry_out(sub_cout), .overflow(sub_ovf)
    );

    wire [31:0] and_result, or_result, xor_result;

    alu_logic u_logic (
        .a(a), .b(b),
        .result_and(and_result), .result_or(or_result), .result_xor(xor_result)
    );

    wire [31:0] sll_result, srl_result, sra_result;

    alu_shift u_shift (
        .a(a), .b(b),
        .result_sll(sll_result), .result_srl(srl_result), .result_sra(sra_result)
    );

    wire slt_result  = ($signed(a) < $signed(b));
    wire sltu_result = (a < b);

    always @(*) begin
        case (alu_op)
            ALU_ADD:  result = add_result;
            ALU_SUB:  result = sub_result;
            ALU_AND:  result = and_result;
            ALU_OR:   result = or_result;
            ALU_XOR:  result = xor_result;
            ALU_SLL:  result = sll_result;
            ALU_SRL:  result = srl_result;
            ALU_SRA:  result = sra_result;
            ALU_SLT:  result = {31'b0, slt_result};
            ALU_SLTU: result = {31'b0, sltu_result};
            default:  result = 32'b0;
        endcase
    end

    assign zero = (result == 32'b0);

endmodule