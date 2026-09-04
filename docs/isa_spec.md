# ISA Specification: RV32I Subset Implemented

## 1. Overview

This CPU implements a subset of the RV32I base integer instruction set (RISC-V, 32-bit). This document defines exactly which instructions are supported and which are deliberately out of scope, so the project's coverage is explicit rather than implied.

## 2. Instructions Implemented

### R-type (register-register)
| Mnemonic | funct3 | funct7 | Operation |
|----------|--------|--------|-----------|
| ADD | 000 | 0000000 | rd = rs1 + rs2 |
| SUB | 000 | 0100000 | rd = rs1 - rs2 |
| AND | 111 | 0000000 | rd = rs1 & rs2 |
| OR | 110 | 0000000 | rd = rs1 \| rs2 |
| XOR | 100 | 0000000 | rd = rs1 ^ rs2 |
| SLL | 001 | 0000000 | rd = rs1 << rs2[4:0] |
| SRL | 101 | 0000000 | rd = rs1 >> rs2[4:0] (logical) |
| SRA | 101 | 0100000 | rd = rs1 >>> rs2[4:0] (arithmetic) |
| SLT | 010 | 0000000 | rd = (signed rs1 < signed rs2) ? 1 : 0 |
| SLTU | 011 | 0000000 | rd = (unsigned rs1 < unsigned rs2) ? 1 : 0 |

### I-type (register-immediate, loads, JALR)
| Mnemonic | funct3 | Operation |
|----------|--------|-----------|
| ADDI | 000 | rd = rs1 + imm |
| ANDI | 111 | rd = rs1 & imm |
| ORI | 110 | rd = rs1 \| imm |
| XORI | 100 | rd = rs1 ^ imm |
| SLTI | 010 | rd = (signed rs1 < signed imm) ? 1 : 0 |
| SLTIU | 011 | rd = (unsigned rs1 < unsigned imm) ? 1 : 0 |
| SLLI | 001 | rd = rs1 << shamt |
| SRLI | 101 (funct7=0000000) | rd = rs1 >> shamt (logical) |
| SRAI | 101 (funct7=0100000) | rd = rs1 >>> shamt (arithmetic) |
| LW | 010 | rd = mem[rs1 + imm] (word) |
| JALR | 000 | rd = pc+4; pc = (rs1+imm) & ~1 |

### S-type (stores)
| Mnemonic | funct3 | Operation |
|----------|--------|-----------|
| SW | 010 | mem[rs1 + imm] = rs2 (word) |

### B-type (branches)
| Mnemonic | funct3 | Operation |
|----------|--------|-----------|
| BEQ | 000 | if (rs1 == rs2) pc += imm |
| BNE | 001 | if (rs1 != rs2) pc += imm |
| BLT | 100 | if (signed rs1 < signed rs2) pc += imm |
| BGE | 101 | if (signed rs1 >= signed rs2) pc += imm |
| BLTU | 110 | if (unsigned rs1 < unsigned rs2) pc += imm |
| BGEU | 111 | if (unsigned rs1 >= unsigned rs2) pc += imm |

### U-type
| Mnemonic | Operation |
|----------|-----------|
| LUI | rd = imm << 12 |
| AUIPC | rd = pc + (imm << 12) |

### J-type
| Mnemonic | Operation |
|----------|-----------|
| JAL | rd = pc+4; pc += imm |

## 3. Instructions NOT Implemented (Deliberate Scope Exclusions)

| Category | Examples | Reason for exclusion |
|----------|----------|------------------------|
| Byte/halfword memory ops | LB, LH, LBU, LHU, SB, SH | Word-only memory access (LW/SW) covers the core control/datapath demonstration this project targets; adding sub-word access is a data_memory.v extension, not a fundamental architecture change - flagged as a natural next step in docs/design_decisions.md |
| System instructions | ECALL, EBREAK, FENCE | Require exception/trap handling infrastructure (privilege levels, trap vectors) that is out of scope for a single-cycle educational core; this project uses "PC runs past the end of instruction memory" as its halt condition instead |
| CSR instructions | CSRRW, CSRRS, etc. | Require control/status register file infrastructure not implemented here |
| M extension (multiply/divide) | MUL, DIV, REM | Not part of the RV32I *base* ISA - a separate, optional extension; could be added as an additional ALU-adjacent module in a future iteration |

## 4. Register Convention

32 general-purpose registers, `x0`-`x31`. `x0` is hardwired to zero: reads always return 0, writes are discarded. This is a fixed RISC-V architectural requirement, not a design choice.

## 5. Memory Model

- Instruction memory: word-addressed, loaded from a hex file at simulation start (see `rtl/instr_memory.v`)
- Data memory: word-addressed, separate from instruction memory (Harvard-style, not von Neumann) - this is a simplification appropriate for a single-cycle educational core; real RV32I systems typically present a unified address space
- No memory-mapped I/O, no caches, no virtual memory - out of scope