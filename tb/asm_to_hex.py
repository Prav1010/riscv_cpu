"""
Minimal RV32I assembler for this project's test programs.

Supports the instruction subset implemented by this CPU (see
docs/isa_spec.md): R-type, I-type ALU/load/JALR, S-type, B-type,
U-type, and JAL. Does not support pseudo-instructions, labels with
forward-reference beyond a two-pass scan, or assembler directives
beyond simple comments (#) and blank lines.

Usage:
    python asm_to_hex.py test_programs/basic_arith.asm

Produces test_programs/basic_arith.hex (one 32-bit instruction per
line, in hex, suitable for Verilog $readmemh).
"""

import sys
import re

REGS = {f"x{i}": i for i in range(32)}
# Common ABI aliases
REGS.update({
    "zero": 0, "ra": 1, "sp": 2, "gp": 3, "tp": 4,
    "t0": 5, "t1": 6, "t2": 7, "s0": 8, "fp": 8, "s1": 9,
    "a0": 10, "a1": 11, "a2": 12, "a3": 13, "a4": 14, "a5": 15, "a6": 16, "a7": 17,
    "s2": 18, "s3": 19, "s4": 20, "s5": 21, "s6": 22, "s7": 23, "s8": 24, "s9": 25,
    "s10": 26, "s11": 27, "t3": 28, "t4": 29, "t5": 30, "t6": 31,
})

R_TYPE = {
    "add":  (0b0110011, 0b000, 0b0000000),
    "sub":  (0b0110011, 0b000, 0b0100000),
    "and":  (0b0110011, 0b111, 0b0000000),
    "or":   (0b0110011, 0b110, 0b0000000),
    "xor":  (0b0110011, 0b100, 0b0000000),
    "sll":  (0b0110011, 0b001, 0b0000000),
    "srl":  (0b0110011, 0b101, 0b0000000),
    "sra":  (0b0110011, 0b101, 0b0100000),
    "slt":  (0b0110011, 0b010, 0b0000000),
    "sltu": (0b0110011, 0b011, 0b0000000),
}

I_TYPE_ALU = {
    "addi":  (0b0010011, 0b000),
    "andi":  (0b0010011, 0b111),
    "ori":   (0b0010011, 0b110),
    "xori":  (0b0010011, 0b100),
    "slti":  (0b0010011, 0b010),
    "sltiu": (0b0010011, 0b011),
}
I_TYPE_SHIFT = {
    "slli": (0b0010011, 0b001, 0b0000000),
    "srli": (0b0010011, 0b101, 0b0000000),
    "srai": (0b0010011, 0b101, 0b0100000),
}

B_TYPE = {
    "beq":  (0b1100011, 0b000),
    "bne":  (0b1100011, 0b001),
    "blt":  (0b1100011, 0b100),
    "bge":  (0b1100011, 0b101),
    "bltu": (0b1100011, 0b110),
    "bgeu": (0b1100011, 0b111),
}


def parse_reg(tok):
    tok = tok.strip().rstrip(",")
    if tok not in REGS:
        raise ValueError(f"Unknown register: {tok}")
    return REGS[tok]


def parse_imm(tok):
    tok = tok.strip().rstrip(",")
    return int(tok, 0)  # supports 0x, 0b, decimal, negative


def encode_r(mnemonic, rd, rs1, rs2):
    opcode, funct3, funct7 = R_TYPE[mnemonic]
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def encode_i_alu(mnemonic, rd, rs1, imm):
    opcode, funct3 = I_TYPE_ALU[mnemonic]
    imm12 = imm & 0xFFF
    return (imm12 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def encode_i_shift(mnemonic, rd, rs1, shamt):
    opcode, funct3, funct7 = I_TYPE_SHIFT[mnemonic]
    return (funct7 << 25) | (shamt << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def encode_load(rd, imm, rs1):  # lw rd, imm(rs1)
    opcode, funct3 = 0b0000011, 0b010
    imm12 = imm & 0xFFF
    return (imm12 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def encode_store(rs2, imm, rs1):  # sw rs2, imm(rs1)
    opcode, funct3 = 0b0100011, 0b010
    imm_hi = (imm >> 5) & 0x7F
    imm_lo = imm & 0x1F
    return (imm_hi << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm_lo << 7) | opcode


def encode_branch(mnemonic, rs1, rs2, imm):
    opcode, funct3 = B_TYPE[mnemonic]
    imm = imm & 0x1FFF  # 13-bit signed, LSB always 0
    bit12 = (imm >> 12) & 1
    bit11 = (imm >> 11) & 1
    bits10_5 = (imm >> 5) & 0x3F
    bits4_1 = (imm >> 1) & 0xF
    return (bit12 << 31) | (bits10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | \
           (bits4_1 << 8) | (bit11 << 7) | opcode


def encode_jal(rd, imm):
    opcode = 0b1101111
    imm = imm & 0x1FFFFF
    bit20 = (imm >> 20) & 1
    bits10_1 = (imm >> 1) & 0x3FF
    bit11 = (imm >> 11) & 1
    bits19_12 = (imm >> 12) & 0xFF
    return (bit20 << 31) | (bits19_12 << 12) | (bit11 << 20) | (bits10_1 << 21) | (rd << 7) | opcode


def encode_jalr(rd, rs1, imm):
    opcode, funct3 = 0b1100111, 0b000
    imm12 = imm & 0xFFF
    return (imm12 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def encode_u(mnemonic, rd, imm):
    opcode = 0b0110111 if mnemonic == "lui" else 0b0010111
    return (imm & 0xFFFFF000) | (rd << 7) | opcode


def parse_offset_reg(tok):
    """Parses 'imm(reg)' syntax used by lw/sw, e.g. '4(x1)' -> (4, 1)"""
    m = re.match(r"(-?\w+)\((\w+)\)", tok.strip().rstrip(","))
    if not m:
        raise ValueError(f"Expected imm(reg) syntax, got: {tok}")
    imm = int(m.group(1), 0)
    reg = parse_reg(m.group(2))
    return imm, reg


def first_pass_labels(lines):
    """Map label names to their instruction address (word index * 4)."""
    labels = {}
    addr = 0
    for line in lines:
        line = line.split("#")[0].strip()
        if not line:
            continue
        if line.endswith(":"):
            labels[line[:-1]] = addr
        else:
            addr += 4
    return labels


def assemble(asm_path):
    with open(asm_path) as f:
        lines = f.readlines()

    labels = first_pass_labels(lines)

    instructions = []
    addr = 0

    for raw_line in lines:
        line = raw_line.split("#")[0].strip()
        if not line or line.endswith(":"):
            continue

        parts = re.split(r"[\s,]+", line)
        mnemonic = parts[0].lower()
        args = [p for p in parts[1:] if p]

        if mnemonic in R_TYPE:
            rd, rs1, rs2 = parse_reg(args[0]), parse_reg(args[1]), parse_reg(args[2])
            word = encode_r(mnemonic, rd, rs1, rs2)

        elif mnemonic in I_TYPE_ALU:
            rd, rs1, imm = parse_reg(args[0]), parse_reg(args[1]), parse_imm(args[2])
            word = encode_i_alu(mnemonic, rd, rs1, imm)

        elif mnemonic in I_TYPE_SHIFT:
            rd, rs1, shamt = parse_reg(args[0]), parse_reg(args[1]), parse_imm(args[2])
            word = encode_i_shift(mnemonic, rd, rs1, shamt)

        elif mnemonic == "lw":
            rd = parse_reg(args[0])
            imm, rs1 = parse_offset_reg(args[1])
            word = encode_load(rd, imm, rs1)

        elif mnemonic == "sw":
            rs2 = parse_reg(args[0])
            imm, rs1 = parse_offset_reg(args[1])
            word = encode_store(rs2, imm, rs1)

        elif mnemonic in B_TYPE:
            rs1, rs2 = parse_reg(args[0]), parse_reg(args[1])
            target = labels[args[2]] if args[2] in labels else parse_imm(args[2])
            imm = target - addr if args[2] in labels else target
            word = encode_branch(mnemonic, rs1, rs2, imm)

        elif mnemonic == "jal":
            rd = parse_reg(args[0])
            target = labels[args[1]] if args[1] in labels else parse_imm(args[1])
            imm = target - addr if args[1] in labels else target
            word = encode_jal(rd, imm)

        elif mnemonic == "jalr":
            rd, rs1, imm = parse_reg(args[0]), parse_reg(args[1]), parse_imm(args[2])
            word = encode_jalr(rd, rs1, imm)

        elif mnemonic in ("lui", "auipc"):
            rd, imm = parse_reg(args[0]), parse_imm(args[1])
            word = encode_u(mnemonic, rd, imm << 12 if imm < 0x100000 else imm)

        else:
            raise ValueError(f"Unknown instruction: {mnemonic}")

        instructions.append(word & 0xFFFFFFFF)
        addr += 4

    return instructions


def main():
    if len(sys.argv) != 2:
        print("Usage: python asm_to_hex.py <path/to/program.asm>")
        sys.exit(1)

    asm_path = sys.argv[1]
    hex_path = asm_path.rsplit(".", 1)[0] + ".hex"

    instructions = assemble(asm_path)

    with open(hex_path, "w") as f:
        for word in instructions:
            f.write(f"{word:08x}\n")

    print(f"Assembled {len(instructions)} instructions -> {hex_path}")


if __name__ == "__main__":
    main()