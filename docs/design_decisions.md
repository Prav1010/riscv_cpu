# Design Decisions and Rationale

## 1. Why Single-Cycle?

See `docs/microarchitecture.md` Section 4 for the full discussion. Short version: single-cycle isolates ISA-correctness verification from pipeline-hazard correctness, making it the right starting point for a project whose primary goal is demonstrating a working, verified datapath against an independent golden model.

## 2. Why Reuse the ALU From the `configurable_alu` Project?

The ALU (`alu.v`, `alu_adder.v`, `alu_logic.v`, `alu_shift.v`) is directly adapted from this portfolio's standalone `configurable_alu` project - same ripple-carry adder architecture, same modular split into adder/logic/shift sub-blocks. Two additions were needed for RV32I specifically: SLT and SLTU (set-less-than), which RV32I's R-type/I-type ALU instructions require but the standalone ALU project's opcode set did not include. This reuse is a deliberate demonstration of building composable, reusable RTL blocks rather than writing a one-off ALU per project - directly relevant to how real chip design teams build and reuse verified IP blocks.

## 3. Why a Minimal Custom Assembler Instead of an Existing RISC-V Toolchain?

Using a real toolchain (e.g., the official `riscv-gnu-toolchain`) would produce more realistic, standards-compliant binaries, but would also introduce a large external dependency and ELF-format parsing complexity that isn't the point of this project. A minimal custom assembler (`tb/asm_to_hex.py`), supporting exactly the instruction subset this CPU implements (see `docs/isa_spec.md`), keeps the toolchain self-contained and lets test programs be written and understood without needing an installed cross-compiler - consistent with this whole portfolio's approach of building things from first principles for learning/demonstration purposes rather than relying on production toolchains.

## 4. Why an Independent Python Golden Model (Not Just Hand-Derived Expected Values)?

Consistent with the verification approach used across this entire portfolio (`configurable_alu`, `cache_subsystem`): `tb/riscv_golden_model.py` is a from-scratch, instruction-level RV32I interpreter written directly from the ISA specification, not derived from or by inspecting the RTL. This means a bug shared between the RTL and a hand-derived "expected value" spreadsheet would never be caught - but a genuinely independent second implementation catches exactly that class of bug, which is precisely what happened during this project's development (see Section 6).

## 5. Why Harvard-Style Separate Instruction/Data Memory?

Real RV32I systems typically present a unified (von Neumann) address space where code and data share one memory. This project uses separate instruction and data memories (`instr_memory.v`, `data_memory.v`) for simplicity - it avoids needing a shared-bus arbitration scheme between fetch and load/store in a single-cycle design, where both could conceivably need memory access in the same cycle. This is a common simplification in educational single-cycle cores and is called out explicitly here rather than left as an implicit assumption.

## 6. A Real Bug Found During Development: PC Update Indentation

While verifying the `branches.asm` test program, both the RTL simulation and the Python golden model produced incorrect/looping behavior. Tracing it down revealed a genuine bug in the golden model itself: a stray indentation error had placed the `self.pc = next_pc` line inside an unreachable branch of an `if/elif/else` chain, meaning the golden model's PC was never actually advancing for any instruction - it silently stayed at address 0 forever. This is a good example of exactly the kind of bug an independent golden model is meant to catch: the mismatch between RTL and golden-model behavior was the signal that something was wrong, even though (in this specific instance) the bug turned out to be in the reference model rather than the RTL. Separately, this debugging session also surfaced a real logic bug in the original test program itself (`branches.asm`'s JALR test jumped backward into earlier code, creating a genuine infinite loop by design) - both issues were found and fixed as part of getting the test programs to pass cleanly against the corrected golden model. JALR was removed from `branches.asm` at that point and is now tested in `coverage_extra.asm`.

## 7. Test Program Coverage

Four test programs exercise distinct instruction categories. The first three cover 17 of the 31 implemented instructions; `coverage_extra.asm` was added to run the other 14:

| Program | Coverage |
|---------|----------|
| `basic_arith.asm` | R-type and I-type ALU ops, shifts, comparisons, negative immediates, LUI, AUIPC |
| `branches.asm` | B-type branches (BEQ and BLT, both taken), JAL (unconditional jump with return-address capture) |
| `load_store.asm` | SW/LW with multiple offsets, verifying stored values round-trip correctly through memory |
| `coverage_extra.asm` | ANDI, ORI, XORI, SLTI, SLTIU, SRAI, SLL, SRL, SRA, BNE, BGE, BLTU, BGEU, JALR; every branch taken and not taken; JALR with an odd target to check bit-0 clearing |

All four programs' final register state (x1-x31) is checked against the independently-computed golden model state, not just spot-checked for a subset of registers.


## 8. Synthesis and Implementation Results

`cpu_top` was synthesised and then placed and routed for an Artix-7 (xc7a35tcpg236-1) target in out-of-context mode, with instruction memory pre-loaded with `basic_arith.hex`. The first set of numbers is from a synthesis-only run in Vivado 2018.1 (no clock constraint); the second set is from the constrained flow in `synth/cpu_impl.tcl`, run in Vivado 2023.1.

| Metric | 2018.1 synthesis (unconstrained) | 2023.1 placed and routed, 10 ns |
|--------|-------|-------|
| Slice LUTs | 972 / 20,800 (4.67%) | 906 / 20,800 (4.36%) |
| Slice registers | 1,027 / 41,600 (2.47%) | 358 / 41,600 (0.86%) |
| Worst setup slack | not meaningful (no clock constraint) | +0.150 ns (timing met) |
| Critical path | 8.147 ns, estimated before placement | 9.843 ns (2.054 ns logic, 7.789 ns routing) |
| Total on-chip power | 21.235 W, low confidence, not meaningful | 0.097 W, vector-less, medium confidence |

At an 8 ns target the same flow reports a worst setup slack of -0.539 ns (115 of 686 endpoints failing), so the core meets 100 MHz and does not meet 125 MHz. The maximum frequency lies between the two and was not searched further.

**Why the register count drops:** the program in instruction memory (`basic_arith`) writes only x1-x14, and many of those bits hold fixed values. Flip-flops that never change from their reset value are constants, and `opt_design` removes them. A processor running arbitrary programs would keep all 31 x 32 register bits.

**What these figures do not cover:** a fixed program in memory; out-of-context mode (no I/O, clock tree only estimated); a vector-less power estimate; no board test.

**Note on synthesis methodology**: the first synthesis attempt produced **zero cells** - Vivado correctly determined that with no `INIT_FILE` specified and no observable outputs beyond `clk`/`rst_n`, nothing in the design had any effect that could be observed externally, so the entire CPU was optimized away as dead logic. This was fixed by (1) pointing instruction memory at a real assembled test program via the `INIT_FILE` generic, and (2) adding two debug/observability output ports (`debug_pc`, `debug_reg_x1`) so synthesis has something concrete to preserve. RTL that is perfectly correct in simulation can still synthesize to nothing if the top-level design has no observable outputs.

**Critical path analysis**: the worst path runs from the PC register, through fetch/decode, the register read and the ALU, to a register-file write - the full fetch-through-writeback chain that a single-cycle design must complete in one clock period (see `docs/microarchitecture.md` Section 4). About four fifths of the delay is routing.
