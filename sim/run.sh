#!/bin/bash
# Full test flow for the RV32I single-cycle CPU:
# 1. Assemble each .asm test program to .hex (Python assembler)
# 2. Run each program through the Python golden model, save expected register state
# 3. Compile and run the RTL against each program, compare final register state

set -e

PROGRAMS=("basic_arith" "branches" "load_store")

echo "=== Step 1: Assembling test programs ==="
cd ../tb
for prog in "${PROGRAMS[@]}"; do
    python asm_to_hex.py "test_programs/${prog}.asm"
done
cd ../sim

echo "=== Step 2: Computing golden model expected register state ==="
cd ../tb
python - <<'PYEOF'
import sys
sys.path.insert(0, ".")
from riscv_golden_model import GoldenCPU

programs = ["basic_arith", "branches", "load_store"]

for prog_name in programs:
    with open(f"test_programs/{prog_name}.hex") as f:
        instructions = [int(line.strip(), 16) for line in f if line.strip()]

    cpu = GoldenCPU()
    cpu.load_program(instructions)
    steps = cpu.run(max_steps=1000)

    with open(f"test_programs/{prog_name}_expected_regs.txt", "w") as out:
        for i in range(32):
            out.write(f"{i} {cpu.regs[i]}\n")

    print(f"{prog_name}: ran {steps} instructions, final PC={cpu.pc}")
PYEOF
cd ../sim

mkdir -p results
echo "=== Step 3: Compiling and running RTL for each program ==="

for prog in "${PROGRAMS[@]}"; do
    echo "--- Program: $prog ---"

    cat > ../tb/cpu_test_select.svh <<EOF
parameter PROGRAM_HEX          = "../../tb/test_programs/${prog}.hex";
parameter NUM_CYCLES           = 50;
parameter EXPECTED_REGS_FILE   = "../../tb/test_programs/${prog}_expected_regs.txt";
EOF

    cd results
    xvlog --sv ../../rtl/cpu_pkg.sv
    xvlog --sv ../../rtl/alu_adder.v
    xvlog --sv ../../rtl/alu_logic.v
    xvlog --sv ../../rtl/alu_shift.v
    xvlog --sv ../../rtl/alu.v
    xvlog --sv ../../rtl/regfile.v
    xvlog --sv ../../rtl/instr_decode.v
    xvlog --sv ../../rtl/control_unit.v
    xvlog --sv ../../rtl/instr_fetch.v
    xvlog --sv ../../rtl/instr_memory.v
    xvlog --sv ../../rtl/data_memory.v
    xvlog --sv ../../rtl/cpu_top.v
    xvlog --sv -i ../../tb ../../tb/cpu_tb.sv
    xelab cpu_tb -s cpu_tb_sim > "${prog}_elab_log.txt" 2>&1
    xsim cpu_tb_sim -runall > "${prog}_sim_log.txt" 2>&1
    cd ..

    grep "PASS\|FAIL\|RESULT" "results/${prog}_sim_log.txt"
done

echo "=== Test flow complete ==="
echo "Per-program logs in sim/results/"