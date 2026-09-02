`timescale 1ns/1ps

// Instruction decoder: extracts fixed instruction fields and generates
// the sign-extended immediate value for whichever format the current
// instruction uses. RV32I places rd/rs1/rs2/opcode/funct3/funct7 in
// consistent bit positions across formats specifically so a single
// decoder can extract them without knowing the format in advance -
// only immediate construction differs by format.
module instr_decode (
    input  wire [31:0] instr,
    input  wire [2:0]  imm_sel,   // which immediate format to build (from control_unit.v)

    output wire [6:0]  opcode,
    output wire [4:0]  rd,
    output wire [2:0]  funct3,
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [6:0]  funct7,
    output reg  [31:0] imm
);

    assign opcode  = instr[6:0];
    assign rd      = instr[11:7];
    assign funct3  = instr[14:12];
    assign rs1     = instr[19:15];
    assign rs2     = instr[24:20];
    assign funct7  = instr[31:25];

    localparam IMM_I = 3'h0;
    localparam IMM_S = 3'h1;
    localparam IMM_B = 3'h2;
    localparam IMM_U = 3'h3;
    localparam IMM_J = 3'h4;

    always @(*) begin
        case (imm_sel)
            IMM_I: imm = {{20{instr[31]}}, instr[31:20]};
            IMM_S: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            IMM_B: imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            IMM_U: imm = {instr[31:12], 12'b0};
            IMM_J: imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
            default: imm = 32'b0;
        endcase
    end

endmodule