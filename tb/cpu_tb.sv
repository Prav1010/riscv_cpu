`timescale 1ns/1ps

// Testbench for the single-cycle RV32I CPU.
// Loads a pre-assembled hex program into the CPU's instruction memory,
// runs it for a fixed number of cycles (set per-program, generous
// enough to guarantee completion), then reads the final register file
// state via hierarchical reference and compares it against expected
// values computed independently by tb/riscv_golden_model.py.
//
// PROGRAM_HEX and NUM_CYCLES come from tb/cpu_test_select.svh, which
// sim/run.sh generates fresh before each test program run (this
// pattern - generate-then-include rather than runtime plusargs - was
// chosen after -testplusarg proved unreliable with this xsim version
// in the cache_subsystem project; see that repo's history for details).
module cpu_tb;

    `include "cpu_test_select.svh"

    reg clk;
    reg rst_n;

    cpu_top #(
        .IMEM_WORDS(256),
        .DMEM_WORDS(256),
        .INIT_FILE(PROGRAM_HEX)
    ) dut (
        .clk(clk),
        .rst_n(rst_n)
    );

    always #10 clk = ~clk;

    initial begin
        $dumpfile("waveforms.vcd");
        $dumpvars(0, cpu_tb);
    end

    integer expected_file;
    integer scan_count;
    integer reg_idx;
    integer expected_val;
    integer errors;
    integer i;

    initial begin
        clk = 0;
        rst_n = 0;
        #20;
        rst_n = 1;

        repeat (NUM_CYCLES) @(posedge clk);
        #1;

        $display("=== Program: %s ===", PROGRAM_HEX);
        $display("Final PC: %0d", dut.pc);

        errors = 0;
        expected_file = $fopen(EXPECTED_REGS_FILE, "r");
        if (expected_file == 0) begin
            $display("ERROR: could not open %s", EXPECTED_REGS_FILE);
            $finish;
        end

        while (!$feof(expected_file)) begin
            scan_count = $fscanf(expected_file, "%d %d", reg_idx, expected_val);
            if (scan_count == 2) begin
                if (reg_idx == 0) begin
                    // x0 is always 0, nothing to check against regfile storage
                end else begin
                    if (dut.u_regfile.regs[reg_idx] !== expected_val[31:0]) begin
                        $display("FAIL: x%0d = %0d (expected %0d)",
                                   reg_idx, $signed(dut.u_regfile.regs[reg_idx]), expected_val);
                        errors = errors + 1;
                    end else begin
                        $display("PASS: x%0d = %0d", reg_idx, $signed(dut.u_regfile.regs[reg_idx]));
                    end
                end
            end
        end
        $fclose(expected_file);

        $display("----------------------------------------");
        if (errors == 0)
            $display("RESULT: ALL REGISTERS MATCH GOLDEN MODEL");
        else
            $display("RESULT: %0d MISMATCH(ES)", errors);
        $display("----------------------------------------");

        #20;
        $finish;
    end

endmodule