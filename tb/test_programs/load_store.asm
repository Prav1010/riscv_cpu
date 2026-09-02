# Load/store test program
# Exercises SW and LW with various offsets

addi x1, x0, 100          # x1 = 100 (value to store)
addi x2, x0, 0             # x2 = base address 0

sw   x1, 0(x2)              # mem[0] = 100
sw   x1, 4(x2)              # mem[4] = 100 (word offset 1)

addi x3, x0, 200            # x3 = 200
sw   x3, 8(x2)               # mem[8] = 200

lw   x4, 0(x2)                # x4 = mem[0] = 100
lw   x5, 4(x2)                # x5 = mem[4] = 100
lw   x6, 8(x2)                # x6 = mem[8] = 200

add  x7, x4, x5                # x7 = 200 (sanity check: 100+100)
add  x8, x7, x6                # x8 = 400 (sanity check: 200+200)