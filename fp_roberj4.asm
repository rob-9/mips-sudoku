# Robert Ji
# roberj4

.text

##########################################
#  Part #1 Functions
##########################################
checkColors:
	# validates the colors selected by the player to determine
	# if they can be used together to visualize the game
	lw $t0, 0($sp) # load additional arg from stack
	
	# a0: pc_bg (preset cells background)
	# a1: pc_fg (preset cells foreground)
	# a2: gc_bg (game cells background)
	# a3: gc_fg (game cells foreground)
	# t0: err_bg (color for bg of preset/game cell for conflict error)
	
	# check err_bg against all other colors
	beq $t0, $a0, invalid_colors
	beq $t0, $a1, invalid_colors
	beq $t0, $a2, invalid_colors
	beq $t0, $a3, invalid_colors
	
	# check other color conflicts
	beq $a1, $a3, invalid_colors  # pc_fg != gc_fg
	beq $a1, $a0, invalid_colors  # pc_fg != pc_bg
	beq $a2, $a3, invalid_colors  # gc_bg != gc_fg
	
	# Save err_bg before bit operations
	move $t3, $t0   # preserve err_bg in t3
	
	sll $t1, $a0, 12 # pc_bg in bits 15-12
	sll $t2, $a1, 8  # pc_fg in bits 11-8
	or $t1, $t1, $t2 #
	sll $t2, $a2, 4  # gc-bg in bits 7-4
	or $t1, $t1, $t2 # 
	or $t1, $t1, $a3 # gc_fg in bits 3-0
	
	move $v0, $t1    # return CColor structure
	move $v1, $t3    # return err_bg
	jr $ra
	
	
invalid_colors:
	li $v0, 0xFFFF
	li $v1, 0xFF
	jr $ra

setCell:
	# int setCell (int r, int c, int val, byte cellColor)
	# a0: r (row 0-8)
	# a1: c (col 0-8) 
	# a2: val (0-9 for value, -1 for color only)
	# a3: cellColor
	
	# validate row bounds
	bltz $a0, setCell_error
	li $t0, 8
	bgt $a0, $t0, setCell_error
	
	# validate column bounds
	bltz $a1, setCell_error
	bgt $a1, $t0, setCell_error
	
	# validate val bounds
	li $t1, -1
	blt $a2, $t1, setCell_error
	li $t1, 9
	bgt $a2, $t1, setCell_error
	
	# calc memory addr: 0xffff0000 + (row * 9 + col)* 2
	li $t0, 9
	mul $t1, $a0, $t0    # row * 9
	add $t1, $t1, $a1    # row * 9 + col
	sll $t1, $t1, 1      # (row * 9 + col) * 2
	lui $t0, 0xffff      # load base address 0xffff0000
	add $t1, $t0, $t1    # final address
	
	# handle different val cases
	li $t0, -1
	beq $a2, $t0, setCell_color_only
	
	beqz $a2, setCell_clear_cell
	
	# set ascii char
	addi $t0, $a2, 48    # convert
	sb $t0, 0($t1)       # store character
	sb $a3, 1($t1)       # store color
	j setCell_success
	
setCell_clear_cell:
	# val is zero
	sb $zero, 0($t1)     # store null
	sb $a3, 1($t1)       # store color
	j setCell_success
	
setCell_color_only:
	# val is -1
	sb $a3, 1($t1)
	j setCell_success
	
setCell_success:
	li $v0, 0
	jr $ra
	
setCell_error:
	li $v0, -1
	jr $ra

getCell:
	# validate bounds
	bltz $a0, getCell_error
	li $t0, 8
	bgt $a0, $t0, getCell_error
	bltz $a1, getCell_error
	bgt $a1, $t0, getCell_error
	
	# calc memory addr: 0xffff0000 + (row * 9 + col) * 2
	li $t0, 9
	mul $t1, $a0, $t0
	add $t1, $t1, $a1
	sll $t1, $t1, 1
	lui $t0, 0xffff
	add $t1, $t0, $t1
	
	# load char and color
	lbu $t2, 0($t1)
	lbu $t3, 1($t1)
	
	beqz $t2, getCell_empty
	li $t0, 49
	blt $t2, $t0, getCell_error
	li $t0, 57
	bgt $t2, $t0, getCell_error

	addi $t4, $t2, -48
	move $v0, $t3
	move $v1, $t4
	jr $ra
	
getCell_empty:
	move $v0, $t3
	li $v1, 0
	jr $ra
	
getCell_error:
	li $v0, 0xFF
	li $v1, -1
	jr $ra

reset:
	# int reset(CColor curColor, byte err_bg, int numConflicts)
	# a0: curColor (CColor data structure)
	# a1: err_bg  
	# a2: numConflicts
	
	# save regs
	addi $sp, $sp, -24
	sw $ra, 20($sp)
	sw $s0, 16($sp)
	sw $s1, 12($sp)
	sw $s2, 8($sp)
	sw $s3, 4($sp)
	sw $s4, 0($sp)
	
	move $s0, $a0    # curColor
	move $s1, $a1    # err_bg
	move $s2, $a2    # numConflicts
	
	# validate err_bg
	li $t0, 0xF
	bgt $s1, $t0, reset_error

	# check numConflicts cases
	bltz $s2, reset_clear_all
	beqz $s2, reset_preset_only
	j reset_conflicts
	
reset_clear_all:
	# clear entire board
	li $s3, 0        # row
reset_clear_all_row:
	li $s4, 0        # col
reset_clear_all_col:
	move $a0, $s3
	move $a1, $s4
	li $a2, 0        # clear cell
	li $a3, 0xF0     # white bg, black fg
	jal setCell
	bltz $v0, reset_error
	
	addi $s4, $s4, 1
	li $t0, 9
	blt $s4, $t0, reset_clear_all_col
	
	addi $s3, $s3, 1
	li $t0, 9
	blt $s3, $t0, reset_clear_all_row
	j reset_success
	
reset_preset_only:
	andi $t0, $s0, 0xF
	srl $t1, $s0, 4
	andi $t1, $t1, 0xF
	sll $t2, $t1, 4
	or $t2, $t2, $t0

	srl $t3, $s0, 8
	andi $t3, $t3, 0xF
	srl $t4, $s0, 12
	andi $t4, $t4, 0xF
	sll $t5, $t4, 4
	or $t5, $t5, $t3

	addi $sp, $sp, -16
	sw $t0, 12($sp)
	sw $t2, 8($sp)
	sw $t3, 4($sp)
	sw $t5, 0($sp)

	li $s3, 0
reset_preset_row:
	li $s4, 0
reset_preset_col:
	move $a0, $s3
	move $a1, $s4
	jal getCell

	bltz $v1, reset_preset_error_cleanup

	lw $t0, 12($sp)
	lw $t3, 4($sp)

	andi $t6, $v0, 0xF
	beq $t6, $t0, reset_clear_game_cell
	beq $t6, $t3, reset_color_preset_cell
	j reset_preset_error_cleanup

reset_clear_game_cell:
	lw $t2, 8($sp)
	move $a0, $s3
	move $a1, $s4
	li $a2, 0
	move $a3, $t2
	jal setCell
	bltz $v0, reset_preset_error_cleanup
	j reset_preset_next

reset_color_preset_cell:
	lw $t5, 0($sp)
	move $a0, $s3
	move $a1, $s4
	li $a2, -1
	move $a3, $t5
	jal setCell
	bltz $v0, reset_preset_error_cleanup

reset_preset_next:
	addi $s4, $s4, 1
	li $t1, 9
	blt $s4, $t1, reset_preset_col

	addi $s3, $s3, 1
	li $t1, 9
	blt $s3, $t1, reset_preset_row

	addi $sp, $sp, 16
	j reset_success

reset_preset_error_cleanup:
	addi $sp, $sp, 16
	j reset_error
	
reset_conflicts:
	# search for err_bg cells 
	li $t0, 0 # conflicts found
	li $s4, 0 # col
	
reset_conf_col:
	li $s3, 0 # row
	
reset_conf_row:
	# calculate memory addr
	li $t1, 9
	mul $t2, $s3, $t1     # row * 9
	add $t2, $t2, $s4     # row * 9 + col
	sll $t2, $t2, 1       # (row * 9 + col) * 2
	lui $t3, 0xffff
	add $t3, $t3, $t2     # final addr
	
	# load color byte directly
	lbu $t4, 1($t3)
	andi $t4, $t4, 0xFF
	srl $t5, $t4, 4  # bg color
	bne $t5, $s1, reset_conf_next  # not err_bg, continue
	
	# found conflict cell, cnt
	addi $t0, $t0, 1
	
	# determine p/gc by fg color
	andi $t5, $t4, 0xF    # current fg
	srl $t6, $s0, 8
	andi $t6, $t6, 0xF    # pc_fg from curColor
	andi $t7, $s0, 0xF    # gc_fg from curColor
	
	beq $t5, $t6, reset_conf_is_preset
	beq $t5, $t7, reset_conf_is_game
	j reset_error
	
reset_conf_is_preset:
	# reset pc color
	srl $t8, $s0, 12
	andi $t8, $t8, 0xF
	sll $t9, $t8, 4
	or $t9, $t9, $t6
	sb $t9, 1($t3)
	beq $t0, $s2, reset_success
	j reset_conf_next
	
reset_conf_is_game:
	# reset gc color  
	srl $t8, $s0, 4
	andi $t8, $t8, 0xF
	sll $t9, $t8, 4
	or $t9, $t9, $t7
	sb $t9, 1($t3) 
	beq $t0, $s2, reset_success
	
reset_conf_next:
	addi $s3, $s3, 1
	li $t1, 9
	blt $s3, $t1, reset_conf_row
	
	addi $s4, $s4, 1
	li $t1, 9
	blt $s4, $t1, reset_conf_col
	
	j reset_error
	
reset_success:
	li $v0, 0
	j reset_done
	
reset_error:
	li $v0, -1
	
reset_done:
	# restore regs
	lw $s4, 0($sp)
	lw $s3, 4($sp)
	lw $s2, 8($sp)
	lw $s1, 12($sp)
	lw $s0, 16($sp)
	lw $ra, 20($sp)
	addi $sp, $sp, 24
	jr $ra

##########################################
#  Part #2 Function
##########################################

readFile:
	# int readFile(char[] filename, CColor boardColors)
	# a0: filename
	# a1: boardColors (CColor data structure)
	
	# save regs
	addi $sp, $sp, -32
	sw $ra, 28($sp)
	sw $s0, 24($sp)
	sw $s1, 20($sp)
	sw $s2, 16($sp)
	sw $s3, 12($sp)
	sw $s4, 8($sp)
	sw $s5, 4($sp)
	sw $s6, 0($sp)
	
	move $s0, $a0    # filename
	move $s1, $a1    # boardColors
	li $s2, 0        # unique cells count
	
	# reset
	move $a0, $s1    # boardColors
	li $a1, 0x0      # any valid err_bg
	li $a2, -1       # clear all
	jal reset
	bltz $v0, rf_error
	
	# open
	move $a0, $s0    # filename
	li $a1, 0        # read-only
	li $a2, 0        # mode (ignored)
	li $v0, 13       # open file
	syscall
	bltz $v0, rf_error
	move $s3, $v0    # file descriptor
	
	addi $sp, $sp, -8
	
rf_loop:
	move $a0, $s3    # file descriptor
	move $a1, $sp    # buffer
	li $a2, 5        # max chars
	li $v0, 14       # read
	syscall
	blez $v0, rf_done  # eof or error
	
	# nullterm
	add $t0, $sp, $v0
	sb $zero, -1($t0)
	
	# get row, column from line
	move $a0, $sp    # line
	li $a1, 0        # flag = 0
	jal getBoardInfo
	li $t0, -1
	beq $v0, $t0, rf_loop  # skip invalid
	move $s4, $v0    # row
	move $s5, $v1    # col
	
	# get value, type from line
	move $a0, $sp    # line
	li $a1, 1        # flag = 1
	jal getBoardInfo
	li $t0, -1
	beq $v0, $t0, rf_loop  # skip invalid
	move $s6, $v0    # val
	
	# determine color
	li $t0, 'P'
	beq $v1, $t0, rf_preset
	
	# game cell color
	andi $t1, $s1, 0xF     # gc_fg
	srl $t2, $s1, 4
	andi $t2, $t2, 0xF     # gc_bg
	sll $t3, $t2, 4
	or $t3, $t3, $t1       # gc color byte
	j rf_setcell
	
rf_preset:
	# preset cell color
	srl $t1, $s1, 8
	andi $t1, $t1, 0xF     # pc_fg
	srl $t2, $s1, 12
	andi $t2, $t2, 0xF     # pc_bg
	sll $t3, $t2, 4
	or $t3, $t3, $t1       # pc color byte
	
rf_setcell:
	addi $sp, $sp, -4
	sw $t3, 0($sp)

	move $a0, $s4
	move $a1, $s5
	jal getCell

	lw $t3, 0($sp)
	addi $sp, $sp, 4

	move $t4, $v1

	move $a0, $s4
	move $a1, $s5
	move $a2, $s6
	move $a3, $t3
	jal setCell
	bltz $v0, rf_error_file

	bnez $t4, rf_loop
	addi $s2, $s2, 1

	j rf_loop
	
rf_done:
	# close file
	move $a0, $s3
	li $v0, 16
	syscall
	
	addi $sp, $sp, 8
	
	# return
	move $v0, $s2
	j rf_cleanup
	
rf_error_file:
	move $a0, $s3
	li $v0, 16
	syscall

	addi $sp, $sp, 8

	li $v0, -1
	j rf_cleanup

rf_error:
	li $v0, -1
	
rf_cleanup:
	# restore regs
	lw $s6, 0($sp)
	lw $s5, 4($sp)
	lw $s4, 8($sp)
	lw $s3, 12($sp)
	lw $s2, 16($sp)
	lw $s1, 20($sp)
	lw $s0, 24($sp)
	lw $ra, 28($sp)
	addi $sp, $sp, 32
	jr $ra

##########################################
#  Part #3 Functions
##########################################

rowColCheck:
	# (int, int) rowColCheck(int row, int col, int value, int flag)
	# a0: row (0-8)
	# a1: col (0-8)  
	# a2: value (0-9)
	# a3: flag (0=check row, non-zero=check col)
	
	# save regs
	addi $sp, $sp, -24
	sw $ra, 20($sp)
	sw $s0, 16($sp)
	sw $s1, 12($sp)
	sw $s2, 8($sp)
	sw $s3, 4($sp)
	
	# validate bounds
	bltz $a0, rcc_error
	li $t0, 8
	bgt $a0, $t0, rcc_error
	bltz $a1, rcc_error
	bgt $a1, $t0, rcc_error
	
	# validate value (must be >= -1 and <= 9)
	li $t0, -1
	blt $a2, $t0, rcc_error
	li $t0, 9
	bgt $a2, $t0, rcc_error
	
	# save og params
	move $s0, $a0        # original row
	move $s1, $a1        # original col
	move $s2, $a2        # original value
	move $s3, $a3        # original flag
	
	# check flag 
	beqz $s3, rcc_check_row
	
rcc_check_col:
	# check column
	li $t2, 0            # row counter
rcc_col_loop:
	# skip the target cell itself
	beq $t2, $s0, rcc_col_next
	
	# save loop counter before function call
	addi $sp, $sp, -4
	sw $t2, 0($sp)
	
	# get cell at (t2, s1)
	move $a0, $t2        # row
	move $a1, $s1        # col
	jal getCell
	
	# restore loop counter
	lw $t2, 0($sp)
	addi $sp, $sp, 4
	
	bltz $v1, rcc_col_next  # skip if getCell error
	beqz $v1, rcc_col_next  # skip empty cells (value 0)
	
	# check if value matches
	beq $v1, $s2, rcc_found_conflict
	
rcc_col_next:
	addi $t2, $t2, 1
	li $t1, 9
	blt $t2, $t1, rcc_col_loop
	j rcc_no_conflict
	
rcc_check_row:
	# check row
	li $t2, 0            # col counter
rcc_row_loop:
	# skip target cell
	beq $t2, $s1, rcc_row_next
	
	# save loop counter before function call
	addi $sp, $sp, -4
	sw $t2, 0($sp)
	
	# get cell at (s0, t2)
	move $a0, $s0        # row
	move $a1, $t2        # col
	jal getCell
	
	# restore loop counter
	lw $t2, 0($sp)
	addi $sp, $sp, 4
	
	bltz $v1, rcc_row_next  # skip if getCell error
	beqz $v1, rcc_row_next  # skip empty cells (value 0)
	
	# check if value matches
	beq $v1, $s2, rcc_found_conflict
	
rcc_row_next:
	addi $t2, $t2, 1
	li $t1, 9
	blt $t2, $t1, rcc_row_loop
	j rcc_no_conflict

rcc_found_conflict:
	# return position of conflicting cell
	# for row: check conflict at (s0, t2)
	# for col: check conflict at (t2, s1)
	beqz $s3, rcc_row_conflict
	# column conflict
	move $v0, $t2        # conflicting row
	move $v1, $s1        # same column
	j rcc_done
	
rcc_row_conflict:
	move $v0, $s0        # same row  
	move $v1, $t2        # conflicting col
	j rcc_done
	
rcc_no_conflict:
	li $v0, -1
	li $v1, -1
	j rcc_done
	
rcc_error:
	li $v0, -1
	li $v1, -1
	
rcc_done:
	# restore regs
	lw $s3, 4($sp)
	lw $s2, 8($sp)
	lw $s1, 12($sp)
	lw $s0, 16($sp)
	lw $ra, 20($sp)
	addi $sp, $sp, 24
	jr $ra

squareCheck:
	# (int, int) squareCheck(int row, int col, int value)
	# a0: row (0-8)
	# a1: col (0-8)  
	# a2: value (-1 to 9)
	
	# save regs
	addi $sp, $sp, -32
	sw $ra, 28($sp)
	sw $s0, 24($sp)
	sw $s1, 20($sp)
	sw $s2, 16($sp)
	sw $s3, 12($sp)
	sw $s4, 8($sp)
	sw $s5, 4($sp)
	sw $s6, 0($sp)
	
	# validate bounds
	bltz $a0, sq_error
	li $t0, 8
	bgt $a0, $t0, sq_error
	bltz $a1, sq_error
	bgt $a1, $t0, sq_error
	
	# validate value
	li $t0, -1
	blt $a2, $t0, sq_error
	li $t0, 9
	bgt $a2, $t0, sq_error
	
	# save params
	move $s0, $a0        # target row
	move $s1, $a1        # target col
	move $s2, $a2        # target value
	
	# calculate square boundaries
	li $t0, 3
	div $s0, $t0         # row / 3
	mflo $t1             # square_row = row / 3
	mul $s3, $t1, $t0    # start_row = square_row * 3
	
	div $s1, $t0         # col / 3  
	mflo $t1             # square_col = col / 3
	mul $s4, $t1, $t0    # start_col = square_col * 3
	
	# calculate end bounaries
	addi $s5, $s3, 2     # end_row = start_row + 2
	addi $s6, $s4, 2     # end_col = start_col + 2
	
	# check all cells in square
	move $t2, $s3        # current_row = start_row
sq_row_loop:
	move $t3, $s4        # current_col = start_col
sq_col_loop:
	# skip the target cell itself (if both row AND col match)
	bne $t2, $s0, sq_check_cell  # if row doesn't match, check cell
	bne $t3, $s1, sq_check_cell  # if col doesn't match, check cell
	j sq_next_col                # both match, skip this cell
	
sq_check_cell:
	# save loop counters before function call
	addi $sp, $sp, -8
	sw $t2, 4($sp)
	sw $t3, 0($sp)
	
	# get cell at (t2, t3)
	move $a0, $t2        # row
	move $a1, $t3        # col
	jal getCell
	
	# restore loop counters
	lw $t3, 0($sp)
	lw $t2, 4($sp)
	addi $sp, $sp, 8
	
	bltz $v1, sq_next_col    # skip if getCell error
	beqz $v1, sq_next_col    # skip empty cells (value 0)
	
	# check if value matches target
	beq $v1, $s2, sq_found_conflict
	
sq_next_col:
	addi $t3, $t3, 1
	ble $t3, $s6, sq_col_loop
	
	# finished this row, move to next row
	addi $t2, $t2, 1
	ble $t2, $s5, sq_row_loop
	
	# no conflict found
	li $v0, -1
	li $v1, -1
	j sq_done

sq_found_conflict:
	# return pos
	move $v0, $t2        # conflicting row
	move $v1, $t3        # conflicting col
	j sq_done
	
sq_error:
	li $v0, -1
	li $v1, -1
	
sq_done:
	# restore regs
	lw $s6, 0($sp)
	lw $s5, 4($sp)
	lw $s4, 8($sp)
	lw $s3, 12($sp)
	lw $s2, 16($sp)
	lw $s1, 20($sp)
	lw $s0, 24($sp)
	lw $ra, 28($sp)
	addi $sp, $sp, 32
	jr $ra

check:
	addi $sp, $sp, -36
	sw $ra, 32($sp)
	sw $s0, 28($sp)
	sw $s1, 24($sp)
	sw $s2, 20($sp)
	sw $s3, 16($sp)
	sw $s4, 12($sp)
	sw $s5, 8($sp)
	sw $s6, 4($sp)
	sw $s7, 0($sp)

	lw $s5, 36($sp)
	
	# validate bounds
	bltz $a0, check_error
	li $t0, 8
	bgt $a0, $t0, check_error
	bltz $a1, check_error
	bgt $a1, $t0, check_error
	
	# validate val
	li $t0, -1
	blt $a2, $t0, check_error
	li $t0, 9
	bgt $a2, $t0, check_error
	
	# validate err_color
	li $t0, 0xF
	bgtu $a3, $t0, check_error
	
	# save params
	move $s0, $a0    # row
	move $s1, $a1    # col
	move $s2, $a2    # value
	move $s3, $a3    # err_color
	li $s4, 0        # conflict count
	
	# check row conflicts
	move $a0, $s0    # row
	move $a1, $s1    # col
	move $a2, $s2    # value
	li $a3, 0        # flag = 0 (check row)
	jal rowColCheck
	
	# if conflict found
	li $t0, -1
	beq $v0, $t0, check_row_done
	
	# row conflict found
	addi $s4, $s4, 1    # increment conflict count
	
	# if flag = 1
	beqz $s5, check_row_done
	
	move $s6, $v0
	move $s7, $v1

	move $a0, $s6
	move $a1, $s7
	jal getCell

	andi $t0, $v0, 0xF
	sll $t1, $s3, 4
	or $t2, $t1, $t0

	move $a0, $s6
	move $a1, $s7
	li $a2, -1
	move $a3, $t2
	jal setCell

check_row_done:
	move $a0, $s0
	move $a1, $s1
	move $a2, $s2
	li $a3, 1
	jal rowColCheck

	li $t0, -1
	beq $v0, $t0, check_col_done

	addi $s4, $s4, 1

	beqz $s5, check_col_done

	move $s6, $v0
	move $s7, $v1

	move $a0, $s6
	move $a1, $s7
	jal getCell

	andi $t0, $v0, 0xF
	sll $t1, $s3, 4
	or $t2, $t1, $t0

	move $a0, $s6
	move $a1, $s7
	li $a2, -1
	move $a3, $t2
	jal setCell

check_col_done:
	move $a0, $s0
	move $a1, $s1
	move $a2, $s2
	jal squareCheck

	li $t0, -1
	beq $v0, $t0, check_square_done

	addi $s4, $s4, 1

	beqz $s5, check_square_done

	move $s6, $v0
	move $s7, $v1

	move $a0, $s6
	move $a1, $s7
	jal getCell

	andi $t0, $v0, 0xF
	sll $t1, $s3, 4
	or $t2, $t1, $t0

	move $a0, $s6
	move $a1, $s7
	li $a2, -1
	move $a3, $t2
	jal setCell

check_square_done:
	move $v0, $s4
	j check_done

check_error:
	li $v0, -1

check_done:
	lw $s7, 0($sp)
	lw $s6, 4($sp)
	lw $s5, 8($sp)
	lw $s4, 12($sp)
	lw $s3, 16($sp)
	lw $s2, 20($sp)
	lw $s1, 24($sp)
	lw $s0, 28($sp)
	lw $ra, 32($sp)
	addi $sp, $sp, 36
	jr $ra

makeMove:
	# (int, int) makeMove(char[] move, CColor playerColors, byte err_color)
	# a0: move string address
	# a1: playerColors (CColor structure)
	# a2: err_color
	
	# save regs
	addi $sp, $sp, -32
	sw $ra, 28($sp)
	sw $s0, 24($sp)
	sw $s1, 20($sp)
	sw $s2, 16($sp)
	sw $s3, 12($sp)
	sw $s4, 8($sp)
	sw $s5, 4($sp)
	sw $s6, 0($sp)
	
	# save paramns
	move $s0, $a0    # move str
	move $s1, $a1    # playerColors
	move $s2, $a2    # err_color
	
	# parse move str to get row,col
	move $a0, $s0
	li $a1, 0 # flag = 0
	jal getBoardInfo
	li $t0, -1
	beq $v0, $t0, mm_error # invalid loc
	move $s3, $v0    # row
	move $s4, $v1    # col
	
	# parse move str to get val,type
	move $a0, $s0
	li $a1, 1 # flag = 1
	jal getBoardInfo
	li $t0, -1
	beq $v0, $t0, mm_error  # invalid val
	move $s5, $v0
	
	# get current cell state
	move $a0, $s3
	move $a1, $s4
	jal getCell
	bltz $v1, mm_error
	move $s6, $v0
	move $t7, $v1
	
	# check if current value == moveValue && (curValue == '\0' && moveValue == 0)
	# this means no action needed
	beq $t7, $s5, mm_check_same_value
	j mm_validate_preset
	
mm_check_same_value:
	bnez $t7, mm_no_change  # same non-zero values
	beqz $s5, mm_no_change  # both zero
	j mm_validate_preset
	
mm_no_change:
	li $v0, 0
	li $v1, 0
	j mm_done
	
mm_validate_preset:
	# check if trying to modify preset cell
	# extract preset cell fg from playerColors
	srl $t0, $s1, 8
	andi $t0, $t0, 0xF       # pc_fg
	andi $t1, $s6, 0xF       # curr cell fg
	beq $t1, $t0, mm_preset_error
	
	# check if move is to clear the cell
	beqz $s5, mm_clear_cell
	
	# check for conflicts
	addi $sp, $sp, -4
	li $t0, 1  # flag = 1
	sw $t0, 0($sp)
	
	move $a0, $s3    # row
	move $a1, $s4    # col
	move $a2, $s5    # value
	move $a3, $s2    # err_color
	jal check
	
	addi $sp, $sp, 4
	
	# conflicts found
	bnez $v0, mm_conflict_error
	
	# no conflicts, place val
	# extract gc color from playerColors
	andi $t0, $s1, 0xF
	srl $t1, $s1, 4
	andi $t1, $t1, 0xF
	sll $t2, $t1, 4
	or $t3, $t2, $t0
	
	move $a0, $s3
	move $a1, $s4
	move $a2, $s5
	move $a3, $t3
	jal setCell
	bltz $v0, mm_error
	
	li $v0, 0
	li $v1, -1
	j mm_done
	
mm_clear_cell:
	# clear the cell
	# extract gc color from playerColors
	andi $t0, $s1, 0xF       # gc_fg
	srl $t1, $s1, 4
	andi $t1, $t1, 0xF       # gc_bg
	sll $t2, $t1, 4
	or $t3, $t2, $t0         # gc color byte
	
	move $a0, $s3
	move $a1, $s4
	li $a2, 0        # clear cell
	move $a3, $t3    # gc color
	jal setCell
	bltz $v0, mm_error
	
	li $v0, 0
	li $v1, 1
	j mm_done
	
mm_preset_error:
	li $v0, -1 
	li $v1, 0 
	j mm_done
	
mm_conflict_error:
	# conflicts found, return error w cnt
	move $t0, $v0  # num of conflicts
	li $v0, -1     # flag = error
	move $v1, $t0  # cellChange = number of conflicts
	j mm_done
	
mm_error:
	li $v0, -1
	li $v1, 0        # cellChange = no change (not -1 for error)
	
mm_done:
	# restore regs
	lw $s6, 0($sp)
	lw $s5, 4($sp)
	lw $s4, 8($sp)
	lw $s3, 12($sp)
	lw $s2, 16($sp)
	lw $s1, 20($sp)
	lw $s0, 24($sp)
	lw $ra, 28($sp)
	addi $sp, $sp, 32
	jr $ra
