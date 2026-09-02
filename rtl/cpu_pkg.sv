`timescale 1ns/1ps

// Shared definitions for the RV32I single-cycle CPU.
// Encodings match the official RISC-V RV32I base integer instruction
// set specification.
package cpu_pkg;

    // ------------------------------------------------------------
    // Opcodes (instr[6:0])
    // ------------------------------------------------------------
    parameter [6:0] OPCODE_RTYPE  = 7'b0110011; // R-type: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
    parameter [6:0] OPCODE_ITYPE  = 7'b0010011; // I-type ALU: ADDI, ANDI, ORI, XORI, SLTI, SLTIU, SLLI, SRLI, SRAI
    parameter [6:0] OPCODE_LOAD   = 7'b0000011; // I-type load: LW
    parameter [6:0] OPCODE_JALR   = 7'b1100111; // I-type: JALR
    parameter [6:0] OPCODE_STORE  = 7'b0100011; // S-type: SW
    parameter [6:0] OPCODE_BRANCH = 7'b1100011; // B-type: BEQ, BNE, BLT, BGE, BLTU, BGEU
    parameter [6:0] OPCODE_LUI    = 7'b0110111; // U-type: LUI
    parameter [6:0] OPCODE_AUIPC  = 7'b0010111; // U-type: AUIPC
    parameter [6:0] OPCODE_JAL    = 7'b1101111; // J-type: JAL

    // ------------------------------------------------------------
    // ALU operation codes (internal to this CPU - independent of the
    // opcode/funct3/funct7 encoding, decoded by control_unit.v)
    // ------------------------------------------------------------
    parameter [3:0] ALU_ADD  = 4'h0;
    parameter [3:0] ALU_SUB  = 4'h1;
    parameter [3:0] ALU_AND  = 4'h2;
    parameter [3:0] ALU_OR   = 4'h3;
    parameter [3:0] ALU_XOR  = 4'h4;
    parameter [3:0] ALU_SLL  = 4'h5;
    parameter [3:0] ALU_SRL  = 4'h6;
    parameter [3:0] ALU_SRA  = 4'h7;
    parameter [3:0] ALU_SLT  = 4'h8;  // signed less-than
    parameter [3:0] ALU_SLTU = 4'h9;  // unsigned less-than

    // ------------------------------------------------------------
    // Immediate source select (for instr_decode.v)
    // ------------------------------------------------------------
    parameter [2:0] IMM_I = 3'h0;
    parameter [2:0] IMM_S = 3'h1;
    parameter [2:0] IMM_B = 3'h2;
    parameter [2:0] IMM_U = 3'h3;
    parameter [2:0] IMM_J = 3'h4;

    // ------------------------------------------------------------
    // Branch comparison type (for control_unit.v -> instr_fetch.v)
    // ------------------------------------------------------------
    parameter [2:0] BR_NONE = 3'h0;
    parameter [2:0] BR_EQ   = 3'h1;
    parameter [2:0] BR_NE   = 3'h2;
    parameter [2:0] BR_LT   = 3'h3;
    parameter [2:0] BR_GE   = 3'h4;
    parameter [2:0] BR_LTU  = 3'h5;
    parameter [2:0] BR_GEU  = 3'h6;

endpackage