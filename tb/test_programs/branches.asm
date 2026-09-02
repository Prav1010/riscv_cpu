# Branch and jump test program
# Exercises B-type branches and J-type/JALR jumps

addi x1, x0, 5           # x1 = 5
addi x2, x0, 5           # x2 = 5
addi x3, x0, 0           # x3 = 0 (result accumulator)

beq  x1, x2, equal_case   # should branch (5 == 5)
addi x3, x3, 100          # skipped if branch taken

equal_case:
addi x3, x3, 1            # x3 = 1

addi x4, x0, 10          # x4 = 10
addi x5, x0, 20          # x5 = 20
blt  x4, x5, less_case    # should branch (10 < 20)
addi x3, x3, 200          # skipped if branch taken

less_case:
addi x3, x3, 10           # x3 = 11

jal  x6, skip_ahead        # x6 = return address (pc+4), jump forward
addi x3, x3, 300           # skipped

skip_ahead:
addi x3, x3, 100           # x3 = 111

addi x7, x0, 8             # target for jalr test
jalr x8, x7, 0              # x8 = return addr, jump to address in x7 (address 8 = second instruction)