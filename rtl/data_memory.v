`timescale 1ns/1ps

// Data memory: word-aligned load/store only (LW/SW), matching this
// project's scope (byte/halfword loads and stores - LB/LH/SB/SH - are
// part of RV32I but omitted here to keep the memory interface simple;
// see docs/design_decisions.md for the scope discussion).
module data_memory #(
    parameter MEM_WORDS = 256
)(
    input  wire        clk,
    input  wire [31:0] addr,      // byte address (word-aligned; low 2 bits ignored)
    input  wire [31:0] wdata,
    input  wire        mem_write,
    input  wire        mem_read,
    output wire [31:0] rdata
);

    reg [31:0] mem [0:MEM_WORDS-1];

    integer i;
    initial begin
        for (i = 0; i < MEM_WORDS; i = i + 1)
            mem[i] = 32'b0;
    end

    always @(posedge clk) begin
        if (mem_write) begin
            mem[addr[31:2]] <= wdata;
        end
    end

    assign rdata = mem_read ? mem[addr[31:2]] : 32'b0;

endmodule