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
	
	# check valid char
	beqz $t2, getCell_empty
	li $t0, 48
	blt $t2, $t0, getCell_error
	li $t0, 57
	bgt $t2, $t0, getCell_error
	
	# convert to int
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
	# extract colors from curColor
	andi $t0, $s0, 0xF    # gc_fg
	srl $t1, $s0, 4
	andi $t1, $t1, 0xF    # gc_bg
	sll $t2, $t1, 4
	or $t2, $t2, $t0      # gc color byte
	
	li $s3, 0        # row
reset_preset_row:
	li $s4, 0        # col
reset_preset_col:
	# get current cell
	move $a0, $s3
	move $a1, $s4
	jal getCell
	bltz $v1, reset_error
	
	# check if game cell (fg matches gc_fg)
	andi $t3, $v0, 0xF    # current fg
	beq $t3, $t0, reset_clear_game_cell
	j reset_preset_next
	
reset_clear_game_cell:
	move $a0, $s3
	move $a1, $s4
	li $a2, 0        # clear
	move $a3, $t2    # gc color
	jal setCell
	bltz $v0, reset_error
	
reset_preset_next:
	addi $s4, $s4, 1
	li $t1, 9
	blt $s4, $t1, reset_preset_col
	
	addi $s3, $s3, 1
	li $t1, 9
	blt $s3, $t1, reset_preset_row
	j reset_success
	
reset_conflicts:
	# search column-major for err_bg cells
	li $s3, 0        # col
	li $t0, 0        # conflicts found
reset_conf_col:
	li $s4, 0        # row
reset_conf_row:
	# get cell
	move $a0, $s4
	move $a1, $s3
	jal getCell
	bltz $v1, reset_error
	
	# check if bg matches err_bg
	srl $t1, $v0, 4
	andi $t1, $t1, 0xF
	bne $t1, $s1, reset_conf_next
	
	# found conflict cell - determine type & reset
	andi $t2, $v0, 0xF    # current fg
	
	# extract gc_fg and pc_fg from curColor
	andi $t3, $s0, 0xF    # gc_fg
	srl $t4, $s0, 8
	andi $t4, $t4, 0xF    # pc_fg
	
	beq $t2, $t3, reset_conf_game
	beq $t2, $t4, reset_conf_preset
	j reset_error
	
reset_conf_game:
	# reset game cell
	srl $t5, $s0, 4
	andi $t5, $t5, 0xF    # gc_bg
	sll $t6, $t5, 4
	or $t6, $t6, $t3      # gc color
	move $a0, $s4
	move $a1, $s3
	li $a2, 0
	move $a3, $t6
	jal setCell
	bltz $v0, reset_error
	j reset_conf_found
	
reset_conf_preset:
	# reset preset cell
	srl $t5, $s0, 12
	andi $t5, $t5, 0xF    # pc_bg
	sll $t6, $t5, 4
	or $t6, $t6, $t4      # pc color
	move $a0, $s4
	move $a1, $s3
	li $a2, -1
	move $a3, $t6
	jal setCell
	bltz $v0, reset_error
	
reset_conf_found:
	addi $t0, $t0, 1
	beq $t0, $s2, reset_success
	
reset_conf_next:
	addi $s4, $s4, 1
	li $t1, 9
	blt $s4, $t1, reset_conf_row
	
	addi $s3, $s3, 1
	li $t1, 9
	blt $s3, $t1, reset_conf_col
	
	# not enough conflicts found
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
	# set cell
	move $a0, $s4    # row
	move $a1, $s5    # col
	move $a2, $s6    # val
	move $a3, $t3    # color
	jal setCell
	bltz $v0, rf_error
	
	# increment cnt
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
	
rf_error:
	# close file if open
	move $a0, $s3
	li $v0, 16
	syscall
	
	addi $sp, $sp, 8
	
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
	# insert code here
	li $v0, 0XAAA  # replace this line
	jr $ra

makeMove:
	li $v0, 0XDEAD  # replace this line
	jr $ra
