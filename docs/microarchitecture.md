# Microarchitecture: Single-Cycle Datapath

## 1. Overview

This CPU implements a **single-cycle** microarchitecture: every instruction completes fetch, decode, execute, memory access, and writeback within one clock cycle. There is no pipelining, no pipeline registers, and no hazard logic - the entire datapath is combinational logic between two clocked state elements: the PC register and the register file.

## 2. Datapath Diagram
                +-------------+
          +---->|  instr_mem  |
          |     +------+------+
          |            | instr
          +----------+---+ v
| PC | +-----------+ +--------------+
| (instr_fetch)| | decode |---->| control_unit |
+------+-------+ +-----+------+ +------+-------+
^ | |
| rs1/rs2/imm control signals
| | |
| v v
| +-----------+ (routed to every
| | regfile | stage below)
| +-----+-----+
| |
| rs1_data, rs2_data
| |
| v
| +-----------+
branch/jump <------| ALU |
target +-----+-----+
|
alu_result
|
v
+-----------+
| data_mem |
+-----+-----+
|
mem_rdata
|
v
+------------------+
| writeback mux |----> back to regfile (rd_data)
| (alu/mem/pc+4/ |
| imm for LUI) |
+------------------+


## 3. Module Responsibilities

| Module | Responsibility |
|--------|------------------|
| `instr_fetch.v` | PC register; computes next PC (sequential, branch, or jump target) |
| `instr_memory.v` | Combinational instruction ROM, loaded via `$readmemh` |
| `instr_decode.v` | Extracts instruction fields (opcode/rd/rs1/rs2/funct3/funct7) and builds the sign-extended immediate for whichever format applies |
| `control_unit.v` | Maps opcode/funct3/funct7 to every control signal the rest of the datapath needs (purely combinational decode logic) |
| `regfile.v` | 32x32-bit register file, x0 hardwired to zero, 2 combinational read ports + 1 synchronous write port |
| `alu.v` (+ `alu_adder.v`, `alu_logic.v`, `alu_shift.v`) | Executes the arithmetic/logic/shift/compare operation selected by `control_unit` |
| `data_memory.v` | Word-addressed data RAM for LW/SW |
| `cpu_top.v` | Wires all of the above together into the complete datapath |

## 4. Why Single-Cycle (Not Pipelined)?

A single-cycle design was chosen for this project deliberately:

1. **No hazards to handle**: since every instruction fully completes before the next one begins, there's no need for forwarding, stalling, or branch prediction - the entire class of pipeline hazard bugs simply doesn't exist here, which keeps the design's correctness easier to reason about and verify against the golden model.
2. **Clean 1:1 mapping to the ISA specification**: each instruction's behavior can be checked in isolation against `docs/isa_spec.md` without needing to think about instruction overlap in time.
3. **Natural first step**: this is the standard starting point for CPU design coursework and projects precisely because it isolates "does the datapath correctly implement the ISA" from "does the pipeline correctly handle hazards" - the latter is a natural, valuable next iteration once the former is solid (see Section 5).

The clear cost of this choice is performance: the clock period must be long enough for the *slowest* instruction's complete combinational path (fetch through writeback) to settle, meaning every instruction runs at the pace of the worst case, even simple ones like ADDI. See `docs/design_decisions.md` for the full trade-off discussion, and the synthesis timing report for what this actually costs in practice for this implementation.

## 5. Natural Next Steps (Not Implemented)

- **Pipelining** (e.g., classic 5-stage IF/ID/EX/MEM/WB): would improve throughput significantly but requires hazard detection, forwarding paths, and branch handling (flush/predict) - a substantial follow-on project, not attempted here.
- **Byte/halfword memory access**: extending `data_memory.v` for LB/LH/SB/SH.
- **Multiply/divide (M extension)**: an additional execution unit alongside the existing ALU.
- **CSR and exception handling**: needed for ECALL/EBREAK and any real operating system support.
