`timescale 1ns/1ps

// Control unit: decodes opcode/funct3/funct7 into every control signal
// the datapath needs. Purely combinational.
module control_unit (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,

    output reg [3:0]  alu_op,
    output reg [2:0]  imm_sel,
    output reg         alu_src_b,     // 0 = rs2_data, 1 = immediate
    output reg         reg_write,
    output reg [1:0]  wb_sel,         // 0 = alu_result, 1 = mem_rdata, 2 = pc+4, 3 = imm (for LUI/AUIPC handled separately)
    output reg         mem_write,
    output reg         mem_read,
    output reg         branch,
    output reg         jump,
    output reg         jump_reg,      // 1 for JALR (target = rs1 + imm, not pc + imm)
    output reg [2:0]  branch_type,
    output reg         is_lui,
    output reg         is_auipc
);

    localparam OPCODE_RTYPE  = 7'b0110011;
    localparam OPCODE_ITYPE  = 7'b0010011;
    localparam OPCODE_LOAD   = 7'b0000011;
    localparam OPCODE_JALR   = 7'b1100111;
    localparam OPCODE_STORE  = 7'b0100011;
    localparam OPCODE_BRANCH = 7'b1100011;
    localparam OPCODE_LUI    = 7'b0110111;
    localparam OPCODE_AUIPC  = 7'b0010111;
    localparam OPCODE_JAL    = 7'b1101111;

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

    localparam IMM_I = 3'h0;
    localparam IMM_S = 3'h1;
    localparam IMM_B = 3'h2;
    localparam IMM_U = 3'h3;
    localparam IMM_J = 3'h4;

    localparam BR_NONE = 3'h0;
    localparam BR_EQ   = 3'h1;
    localparam BR_NE   = 3'h2;
    localparam BR_LT   = 3'h3;
    localparam BR_GE   = 3'h4;
    localparam BR_LTU  = 3'h5;
    localparam BR_GEU  = 3'h6;

    always @(*) begin
        // Defaults (NOP-safe)
        alu_op      = ALU_ADD;
        imm_sel     = IMM_I;
        alu_src_b   = 1'b0;
        reg_write   = 1'b0;
        wb_sel      = 2'd0;
        mem_write   = 1'b0;
        mem_read    = 1'b0;
        branch      = 1'b0;
        jump        = 1'b0;
        jump_reg    = 1'b0;
        branch_type = BR_NONE;
        is_lui      = 1'b0;
        is_auipc    = 1'b0;

        case (opcode)

            OPCODE_RTYPE: begin
                reg_write = 1'b1;
                alu_src_b = 1'b0;
                wb_sel    = 2'd0; // alu_result
                case (funct3)
                    3'b000: alu_op = funct7[5] ? ALU_SUB : ALU_ADD; // funct7 bit 5 distinguishes ADD/SUB
                    3'b111: alu_op = ALU_AND;
                    3'b110: alu_op = ALU_OR;
                    3'b100: alu_op = ALU_XOR;
                    3'b001: alu_op = ALU_SLL;
                    3'b101: alu_op = funct7[5] ? ALU_SRA : ALU_SRL;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    default: alu_op = ALU_ADD;
                endcase
            end

            OPCODE_ITYPE: begin
                reg_write = 1'b1;
                imm_sel   = IMM_I;
                alu_src_b = 1'b1;
                wb_sel    = 2'd0;
                case (funct3)
                    3'b000: alu_op = ALU_ADD;  // ADDI
                    3'b111: alu_op = ALU_AND;  // ANDI
                    3'b110: alu_op = ALU_OR;   // ORI
                    3'b100: alu_op = ALU_XOR;  // XORI
                    3'b010: alu_op = ALU_SLT;  // SLTI
                    3'b011: alu_op = ALU_SLTU; // SLTIU
                    3'b001: alu_op = ALU_SLL;  // SLLI
                    3'b101: alu_op = funct7[5] ? ALU_SRA : ALU_SRL; // SRAI / SRLI
                    default: alu_op = ALU_ADD;
                endcase
            end

            OPCODE_LOAD: begin // LW
                reg_write = 1'b1;
                imm_sel   = IMM_I;
                alu_src_b = 1'b1;
                alu_op    = ALU_ADD; // address = rs1 + imm
                mem_read  = 1'b1;
                wb_sel    = 2'd1; // mem_rdata
            end

            OPCODE_STORE: begin // SW
                imm_sel   = IMM_S;
                alu_src_b = 1'b1;
                alu_op    = ALU_ADD; // address = rs1 + imm
                mem_write = 1'b1;
            end

            OPCODE_BRANCH: begin
                imm_sel     = IMM_B;
                alu_src_b   = 1'b0;
                alu_op      = ALU_SUB; // used for equality; comparisons use dedicated logic in instr_fetch.v
                branch      = 1'b1;
                case (funct3)
                    3'b000: branch_type = BR_EQ;
                    3'b001: branch_type = BR_NE;
                    3'b100: branch_type = BR_LT;
                    3'b101: branch_type = BR_GE;
                    3'b110: branch_type = BR_LTU;
                    3'b111: branch_type = BR_GEU;
                    default: branch_type = BR_NONE;
                endcase
            end

            OPCODE_JAL: begin
                reg_write = 1'b1;
                imm_sel   = IMM_J;
                jump      = 1'b1;
                wb_sel    = 2'd2; // pc + 4
            end

            OPCODE_JALR: begin
                reg_write = 1'b1;
                imm_sel   = IMM_I;
                alu_src_b = 1'b1;
                alu_op    = ALU_ADD; // target = rs1 + imm
                jump      = 1'b1;
                jump_reg  = 1'b1;
                wb_sel    = 2'd2; // pc + 4
            end

            OPCODE_LUI: begin
                reg_write = 1'b1;
                imm_sel   = IMM_U;
                is_lui    = 1'b1;
                wb_sel    = 2'd3; // imm directly
            end

            OPCODE_AUIPC: begin
                reg_write = 1'b1;
                imm_sel   = IMM_U;
                is_auipc  = 1'b1;
                wb_sel    = 2'd3; // pc + imm, computed in cpu_top.v
            end

            default: begin
                // Unrecognized opcode: NOP-like defaults already set above
            end

        endcase
    end

endmodule