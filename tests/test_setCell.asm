# test setCell function
.include "../fp_roberj4.asm"
.include "../fp_helpers.asm"

.text
.globl main

main:
    # valid set
    li $a0, 2
    li $a1, 1
    li $a2, 4
    li $a3, 0xA0
    jal setCell
    move $a0, $v0
    li $v0, 1
    syscall
    li $v0, 11
    li $a0, '\n'
    syscall
    
    # clear
    li $a0, 3
    li $a1, 3
    li $a2, 0
    li $a3, 0xF0
    jal setCell
    move $a0, $v0
    li $v0, 1
    syscall
    li $v0, 11
    li $a0, '\n'
    syscall
    
    # color only
    li $a0, 2
    li $a1, 1
    li $a2, -1
    li $a3, 0x69
    jal setCell
    move $a0, $v0
    li $v0, 1
    syscall
    li $v0, 11
    li $a0, '\n'
    syscall
    
    # invalid row
    li $a0, -1
    li $a1, 1
    li $a2, 4
    li $a3, 0xA0
    jal setCell
    move $a0, $v0
    li $v0, 1
    syscall
    li $v0, 11
    li $a0, '\n'
    syscall
    
    # invalid val
    li $a0, 2
    li $a1, 1
    li $a2, 10
    li $a3, 0xA0
    jal setCell
    move $a0, $v0
    li $v0, 1
    syscall
    
    li $v0, 10
    syscall
