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
	# insert code here
	li $v0, -1111 # replace this line
	jr $ra

##########################################
#  Part #3 Functions
##########################################

rowColCheck:
	# insert code here
	li $v0, 0xBEEF # replace this line
	jr $ra

squareCheck:
	# insert code here
	li $v0, 0xF0F0  # replace this line
	jr $ra

check:
	# insert code here
	li $v0, 0XAAA  # replace this line
	jr $ra

makeMove:
	li $v0, 0XDEAD  # replace this line
	jr $ra
