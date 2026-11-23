# Coverage extension test
# Exercises the 14 instructions not run by the first three programs:
# ANDI ORI XORI SLTI SLTIU SRAI SLL SRL SRA BNE BGE BLTU BGEU JALR
# Every branch is tested in both the taken and the not-taken direction.
# A flag register is incremented only on the path that must execute.

addi x1, x0, 12            # x1 = 12  (binary 1100)
addi x2, x0, 10            # x2 = 10  (binary 1010)
addi x3, x0, -16           # x3 = -16 (0xFFFFFFF0)
addi x4, x0, 3             # x4 = 3   (shift amount)

andi  x5, x1, 10           # x5 = 12 & 10 = 8
ori   x6, x1, 3            # x6 = 12 | 3  = 15
xori  x7, x1, 10           # x7 = 12 ^ 10 = 6
slti  x8, x3, 0            # x8 = 1  (-16 < 0 signed)
sltiu x9, x3, 5            # x9 = 0  (0xFFFFFFF0 < 5 is false unsigned)
srai  x10, x3, 2           # x10 = -4 (arithmetic shift keeps the sign)
sll   x11, x1, x4          # x11 = 12 << 3 = 96
srl   x12, x3, x4          # x12 = 0xFFFFFFF0 >> 3 = 536870910 (logical)
sra   x13, x3, x4          # x13 = -16 >> 3 = -2 (arithmetic)

addi x14, x0, 0            # x14 counts BNE results
bne  x1, x2, bne_t         # 12 != 10: taken, skips the next addi
addi x14, x14, 1
bne_t:
bne  x1, x1, bne_n         # 12 != 12 is false: not taken
addi x14, x14, 2           # must run, x14 = 2
bne_n:

bge  x1, x2, bge_t         # 12 >= 10 signed: taken
addi x15, x15, 1
bge_t:
bge  x3, x1, bge_n         # -16 >= 12 signed is false: not taken
addi x15, x15, 2           # must run, x15 = 2
bge_n:

bltu x1, x3, bltu_t        # 12 < 0xFFFFFFF0 unsigned: taken
addi x16, x16, 1
bltu_t:
bltu x3, x1, bltu_n        # 0xFFFFFFF0 < 12 unsigned is false: not taken
addi x16, x16, 2           # must run, x16 = 2
bltu_n:

bgeu x3, x1, bgeu_t        # 0xFFFFFFF0 >= 12 unsigned: taken
addi x17, x17, 1
bgeu_t:
bgeu x1, x3, bgeu_n        # 12 >= 0xFFFFFFF0 unsigned is false: not taken
addi x17, x17, 2           # must run, x17 = 2
bgeu_n:

auipc x18, 0               # x18 = address of this instruction (A)
addi  x18, x18, 17         # x18 = A + 17, an odd address
jalr  x19, x18, 0          # x19 = A + 12; jumps to A + 16 (bit 0 cleared)
addi  x20, x0, 99          # skipped by the jump, x20 stays 0
addi  x21, x0, 7           # jump target, x21 = 7
