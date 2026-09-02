# Basic arithmetic and logic test program
# Exercises R-type and I-type ALU instructions

addi x1, x0, 10        # x1 = 10
addi x2, x0, 3          # x2 = 3
add  x3, x1, x2          # x3 = 13
sub  x4, x1, x2          # x4 = 7
and  x5, x1, x2          # x5 = 2
or   x6, x1, x2          # x6 = 11
xor  x7, x1, x2          # x7 = 9
slli x8, x1, 2            # x8 = 40
srli x9, x1, 1            # x9 = 5
slt  x10, x2, x1          # x10 = 1 (3 < 10)
sltu x11, x1, x2          # x11 = 0 (10 < 3 is false)
addi x12, x0, -5           # x12 = -5 (test negative immediate)
lui  x13, 0x10             # x13 = 0x10000
auipc x14, 0x1              # x14 = pc + 0x1000