`timescale 1ns/1ps

// RV32I register file: 32 registers, 32 bits wide. x0 is hardwired to
// zero (RV32I architectural convention) - writes to x0 are silently
// discarded, and reads of x0 always return 0, regardless of the
// underlying storage. Two combinational read ports (rs1, rs2) and one
// synchronous write port (rd), as is standard for a single-cycle design.
module regfile (
    input  wire        clk,
    input  wire        rst_n,

    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data,

    input  wire         rd_we,
    input  wire [4:0]   rd_addr,
    input  wire [31:0]  rd_data
);

    reg [31:0] regs [1:31]; // x0 is not stored - always reads as 0

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 1; i <= 31; i = i + 1)
                regs[i] <= 32'b0;
        end else if (rd_we && (rd_addr != 5'd0)) begin
            regs[rd_addr] <= rd_data;
        end
    end

    assign rs1_data = (rs1_addr == 5'd0) ? 32'b0 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'b0 : regs[rs2_addr];

endmodule