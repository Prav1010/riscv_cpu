"""
Golden model for the RV32I single-cycle CPU.

An independent, pure-Python instruction-level simulator for the RV32I
base integer instruction set (the subset implemented by this project -
see docs/isa_spec.md for exact scope). Written directly from the RISC-V
ISA specification, not derived from the RTL, so it serves as a genuine
independent reference.

Given a list of 32-bit instruction words (as produced by
tb/asm_to_hex.py from an assembly test program), runs them against an
internal register file and data memory model, and reports final
architectural state (registers, memory) for comparison against the
RTL simulation's final state.
"""

MASK32 = 0xFFFFFFFF


def _sext(value: int, bits: int) -> int:
    """Sign-extend `value` (bits-wide) to a full Python int."""
    sign_bit = 1 << (bits - 1)
    return (value & (sign_bit - 1)) - (value & sign_bit)


def _to_u32(value: int) -> int:
    return value & MASK32


def _to_s32(value: int) -> int:
    value &= MASK32
    if value >= 0x80000000:
        value -= 0x100000000
    return value


class GoldenCPU:
    def __init__(self, imem_words=256, dmem_words=256):
        self.pc = 0
        self.regs = [0] * 32  # regs[0] always forced to 0 on read
        self.imem = [0] * imem_words
        self.dmem = [0] * dmem_words
        self.halted = False

    def load_program(self, instructions):
        for i, instr in enumerate(instructions):
            self.imem[i] = instr & MASK32

    def _reg(self, idx):
        return 0 if idx == 0 else self.regs[idx]

    def _set_reg(self, idx, value):
        if idx != 0:
            self.regs[idx] = _to_u32(value)

    def step(self):
        """Execute one instruction. Returns False if PC runs off the
        end of instruction memory (used as a simple halt condition for
        test programs, since this project doesn't implement ECALL)."""
        word_addr = self.pc // 4
        if word_addr >= len(self.imem):
            self.halted = True
            return False

        instr = self.imem[word_addr]
        opcode = instr & 0x7F
        rd = (instr >> 7) & 0x1F
        funct3 = (instr >> 12) & 0x7
        rs1 = (instr >> 15) & 0x1F
        rs2 = (instr >> 20) & 0x1F
        funct7 = (instr >> 25) & 0x7F

        next_pc = self.pc + 4

        if opcode == 0b0110011:  # R-type
            a = _to_s32(self._reg(rs1))
            b = _to_s32(self._reg(rs2))
            if funct3 == 0b000:
                result = a - b if funct7 & 0x20 else a + b
            elif funct3 == 0b111:
                result = self._reg(rs1) & self._reg(rs2)
            elif funct3 == 0b110:
                result = self._reg(rs1) | self._reg(rs2)
            elif funct3 == 0b100:
                result = self._reg(rs1) ^ self._reg(rs2)
            elif funct3 == 0b001:
                result = _to_u32(self._reg(rs1)) << (b & 0x1F)
            elif funct3 == 0b101:
                if funct7 & 0x20:
                    result = a >> (b & 0x1F)  # arithmetic (Python >> on negative is arithmetic)
                else:
                    result = _to_u32(self._reg(rs1)) >> (b & 0x1F)
            elif funct3 == 0b010:
                result = 1 if a < b else 0
            elif funct3 == 0b011:
                result = 1 if self._reg(rs1) < self._reg(rs2) else 0
            else:
                result = 0
            self._set_reg(rd, result)

        elif opcode == 0b0010011:  # I-type ALU
            imm = _sext((instr >> 20) & 0xFFF, 12)
            a = _to_s32(self._reg(rs1))
            if funct3 == 0b000:
                result = a + imm
            elif funct3 == 0b111:
                result = self._reg(rs1) & _to_u32(imm)
            elif funct3 == 0b110:
                result = self._reg(rs1) | _to_u32(imm)
            elif funct3 == 0b100:
                result = self._reg(rs1) ^ _to_u32(imm)
            elif funct3 == 0b010:
                result = 1 if a < imm else 0
            elif funct3 == 0b011:
                result = 1 if _to_u32(self._reg(rs1)) < _to_u32(imm) else 0
            elif funct3 == 0b001:
                shamt = imm & 0x1F
                result = _to_u32(self._reg(rs1)) << shamt
            elif funct3 == 0b101:
                shamt = imm & 0x1F
                if funct7 & 0x20:
                    result = a >> shamt
                else:
                    result = _to_u32(self._reg(rs1)) >> shamt
            else:
                result = 0
            self._set_reg(rd, result)

        elif opcode == 0b0000011:  # LW
            imm = _sext((instr >> 20) & 0xFFF, 12)
            addr = _to_u32(self._reg(rs1) + imm)
            self._set_reg(rd, self.dmem[addr // 4])

        elif opcode == 0b0100011:  # SW
            imm_high = (instr >> 25) & 0x7F
            imm_low = (instr >> 7) & 0x1F
            imm = _sext((imm_high << 5) | imm_low, 12)
            addr = _to_u32(self._reg(rs1) + imm)
            self.dmem[addr // 4] = _to_u32(self._reg(rs2))

        elif opcode == 0b1100011:  # Branch
            imm_bits = (((instr >> 31) & 1) << 12) | (((instr >> 7) & 1) << 11) | \
                       (((instr >> 25) & 0x3F) << 5) | (((instr >> 8) & 0xF) << 1)
            imm = _sext(imm_bits, 13)
            a_s, b_s = _to_s32(self._reg(rs1)), _to_s32(self._reg(rs2))
            a_u, b_u = _to_u32(self._reg(rs1)), _to_u32(self._reg(rs2))
            taken = False
            if funct3 == 0b000: taken = (a_s == b_s)
            elif funct3 == 0b001: taken = (a_s != b_s)
            elif funct3 == 0b100: taken = (a_s < b_s)
            elif funct3 == 0b101: taken = (a_s >= b_s)
            elif funct3 == 0b110: taken = (a_u < b_u)
            elif funct3 == 0b111: taken = (a_u >= b_u)
            if taken:
                next_pc = _to_u32(self.pc + imm)

        elif opcode == 0b1101111:  # JAL
            imm_bits = (((instr >> 31) & 1) << 20) | (((instr >> 12) & 0xFF) << 12) | \
                       (((instr >> 20) & 1) << 11) | (((instr >> 21) & 0x3FF) << 1)
            imm = _sext(imm_bits, 21)
            self._set_reg(rd, self.pc + 4)
            next_pc = _to_u32(self.pc + imm)

        elif opcode == 0b1100111:  # JALR
            imm = _sext((instr >> 20) & 0xFFF, 12)
            target = _to_u32(self._reg(rs1) + imm) & 0xFFFFFFFE
            self._set_reg(rd, self.pc + 4)
            next_pc = target

        elif opcode == 0b0110111:  # LUI
            imm = instr & 0xFFFFF000
            self._set_reg(rd, imm)

        elif opcode == 0b0010111:  # AUIPC
            imm = instr & 0xFFFFF000
            self._set_reg(rd, _to_u32(self.pc + imm))

        else:
            # Unrecognized opcode - treat as halt (no ECALL/EBREAK in scope)
            self.halted = True
            return False

        self.pc = next_pc
        return True

    def run(self, max_steps=10000):
        steps = 0
        while not self.halted and steps < max_steps:
            if not self.step():
                break
            steps += 1
        return steps


if __name__ == "__main__":
    # Self-test: ADDI x1, x0, 5 ; ADDI x2, x0, 3 ; ADD x3, x1, x2
    program = [
        0x00500093,  # addi x1, x0, 5
        0x00300113,  # addi x2, x0, 3
        0x002081b3,  # add x3, x1, x2
    ]
    cpu = GoldenCPU()
    cpu.load_program(program)
    cpu.run(max_steps=3)
    print(f"x1={cpu.regs[1]}, x2={cpu.regs[2]}, x3={cpu.regs[3]} (expect 5, 3, 8)")