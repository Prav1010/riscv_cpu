`timescale 1ns/1ps

// Instruction memory: combinational read (single-cycle CPU fetches and
// executes an instruction in one clock, so instruction memory must be
// asynchronously readable). Loaded from a hex file via $readmemh at
// simulation start - see tb/asm_to_hex.py for how test programs are
// assembled into this format.
module instr_memory #(
    parameter MEM_WORDS = 256,          // number of 32-bit words
    parameter INIT_FILE = ""            // hex file to preload, set by testbench
)(
    input  wire [31:0] addr,            // byte address (word-aligned; low 2 bits ignored)
    output wire [31:0] instr
);

    reg [31:0] mem [0:MEM_WORDS-1];

    initial begin
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    assign instr = mem[addr[31:2]]; // word-addressed (byte address / 4)

endmodule