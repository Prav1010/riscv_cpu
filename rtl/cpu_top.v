`timescale 1ns/1ps

// Top-level single-cycle RV32I CPU.
// Classic single-cycle datapath: Fetch -> Decode -> Execute -> Memory ->
// Writeback, all completing within one clock cycle (no pipeline
// registers between stages - the whole instruction flows through
// combinational logic in one cycle, with only the PC and register file
// being clocked state).
module cpu_top #(
    parameter IMEM_WORDS = 256,
    parameter DMEM_WORDS = 256,
    parameter INIT_FILE  = ""
)(
    input  wire clk,
    input  wire rst_n,

    // Debug/observability outputs - expose internal architectural state
    // so synthesis has observable outputs to preserve (without these,
    // the entire design has no effect on any output and gets optimized
    // away to nothing, regardless of internal correctness)
    output wire [31:0] debug_pc,
    output wire [31:0] debug_reg_x1
);

    // ------------------------------------------------------------
    // Fetch
    // ------------------------------------------------------------
    wire [31:0] pc, pc_plus4;
    wire [31:0] instr;

    // ------------------------------------------------------------
    // Decode
    // ------------------------------------------------------------
    wire [6:0] opcode;
    wire [4:0] rd, rs1, rs2;
    wire [2:0] funct3;
    wire [6:0] funct7;
    wire [31:0] imm;

    wire [3:0] alu_op;
    wire [2:0] imm_sel;
    wire        alu_src_b;
    wire        reg_write;
    wire [1:0] wb_sel;
    wire        mem_write;
    wire        mem_read;
    wire        branch;
    wire        jump;
    wire        jump_reg;
    wire [2:0] branch_type;
    wire        is_lui;
    wire        is_auipc;

    instr_memory #(
        .MEM_WORDS(IMEM_WORDS), .INIT_FILE(INIT_FILE)
    ) u_imem (
        .addr(pc), .instr(instr)
    );

    instr_decode u_decode (
        .instr(instr), .imm_sel(imm_sel),
        .opcode(opcode), .rd(rd), .funct3(funct3), .rs1(rs1), .rs2(rs2), .funct7(funct7),
        .imm(imm)
    );

    control_unit u_control (
        .opcode(opcode), .funct3(funct3), .funct7(funct7),
        .alu_op(alu_op), .imm_sel(imm_sel), .alu_src_b(alu_src_b),
        .reg_write(reg_write), .wb_sel(wb_sel),
        .mem_write(mem_write), .mem_read(mem_read),
        .branch(branch), .jump(jump), .jump_reg(jump_reg), .branch_type(branch_type),
        .is_lui(is_lui), .is_auipc(is_auipc)
    );

    // ------------------------------------------------------------
    // Register file
    // ------------------------------------------------------------
    wire [31:0] rs1_data, rs2_data;
    wire [31:0] rd_wdata;

    regfile u_regfile (
        .clk(clk), .rst_n(rst_n),
        .rs1_addr(rs1), .rs2_addr(rs2), .rs1_data(rs1_data), .rs2_data(rs2_data),
        .rd_we(reg_write), .rd_addr(rd), .rd_data(rd_wdata)
    );

    // ------------------------------------------------------------
    // Fetch: PC update (depends on decode outputs + register values,
    // so instantiated after decode/regfile even though logically
    // "fetch" happens first each cycle - combinational loop resolves
    // within the same clock edge, standard for single-cycle designs)
    // ------------------------------------------------------------
    instr_fetch u_fetch (
        .clk(clk), .rst_n(rst_n),
        .branch(branch), .branch_type(branch_type),
        .jump(jump), .jump_reg(jump_reg),
        .imm(imm), .rs1_data(rs1_data), .rs2_data(rs2_data),
        .pc(pc), .pc_plus4(pc_plus4)
    );

    // ------------------------------------------------------------
    // Execute (ALU)
    // ------------------------------------------------------------
    wire [31:0] alu_b = alu_src_b ? imm : rs2_data;
    wire [31:0] alu_result;
    wire         alu_zero;

    alu u_alu (
        .alu_op(alu_op), .a(rs1_data), .b(alu_b),
        .result(alu_result), .zero(alu_zero)
    );

    // ------------------------------------------------------------
    // Memory
    // ------------------------------------------------------------
    wire [31:0] mem_rdata;

    data_memory #(
        .MEM_WORDS(DMEM_WORDS)
    ) u_dmem (
        .clk(clk), .addr(alu_result), .wdata(rs2_data),
        .mem_write(mem_write), .mem_read(mem_read), .rdata(mem_rdata)
    );

    // ------------------------------------------------------------
    // Writeback mux
    // ------------------------------------------------------------
    wire [31:0] auipc_result = pc + imm;

    assign rd_wdata = is_lui   ? imm :
                       is_auipc ? auipc_result :
                       (wb_sel == 2'd1) ? mem_rdata :
                       (wb_sel == 2'd2) ? pc_plus4 :
                       alu_result;
    assign debug_pc = pc;
    assign debug_reg_x1 = u_regfile.regs[1];

endmodule