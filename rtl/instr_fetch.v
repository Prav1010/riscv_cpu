`timescale 1ns/1ps

// Instruction fetch stage: the PC register and next-PC selection logic.
// Handles three cases: sequential (PC+4), branch taken (PC + B-immediate,
// only if the branch condition evaluates true), and jump (JAL: PC +
// J-immediate; JALR: rs1 + I-immediate, with the result's LSB cleared
// per the RV32I spec's requirement that JALR targets be halfword-aligned).
module instr_fetch (
    input  wire        clk,
    input  wire        rst_n,

    input  wire         branch,
    input  wire [2:0]  branch_type,
    input  wire         jump,
    input  wire         jump_reg,
    input  wire [31:0] imm,
    input  wire [31:0] rs1_data,
    input  wire [31:0] rs2_data,   // for branch comparisons

    output reg  [31:0] pc,
    output wire [31:0] pc_plus4
);

    localparam BR_NONE = 3'h0;
    localparam BR_EQ   = 3'h1;
    localparam BR_NE   = 3'h2;
    localparam BR_LT   = 3'h3;
    localparam BR_GE   = 3'h4;
    localparam BR_LTU  = 3'h5;
    localparam BR_GEU  = 3'h6;

    assign pc_plus4 = pc + 32'd4;

    // Branch condition evaluation (independent of the ALU - RV32I
    // branches compare rs1/rs2 directly, they don't reuse the ALU's
    // subtract result for anything other than internal control_unit
    // bookkeeping)
    reg branch_taken;
    always @(*) begin
        case (branch_type)
            BR_EQ:  branch_taken = (rs1_data == rs2_data);
            BR_NE:  branch_taken = (rs1_data != rs2_data);
            BR_LT:  branch_taken = ($signed(rs1_data) < $signed(rs2_data));
            BR_GE:  branch_taken = ($signed(rs1_data) >= $signed(rs2_data));
            BR_LTU: branch_taken = (rs1_data < rs2_data);
            BR_GEU: branch_taken = (rs1_data >= rs2_data);
            default: branch_taken = 1'b0;
        endcase
    end

    wire [31:0] branch_target = pc + imm;
    wire [31:0] jal_target    = pc + imm;
    wire [31:0] jalr_target   = (rs1_data + imm) & 32'hFFFFFFFE; // clear LSB per spec

    wire [31:0] next_pc = jump ? (jump_reg ? jalr_target : jal_target) :
                           (branch && branch_taken) ? branch_target :
                           pc_plus4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'b0;
        end else begin
            pc <= next_pc;
        end
    end

endmodule