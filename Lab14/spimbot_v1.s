# this is what I have so far. cannot seem to make it through the night w/o being killed by squirrels 
# (they are able to break stone walls w/in a single night)
# 04/22/21 adam

### syscall constants
PRINT_STRING            = 4
PRINT_CHAR              = 11
PRINT_INT               = 1

### memory-mapped I/O addresses and constants

# movement info
VELOCITY                = 0xffff0010
ANGLE                   = 0xffff0014
ANGLE_CONTROL           = 0xffff0018

BOT_X                   = 0xffff0020
BOT_Y                   = 0xffff0024
GET_OPPONENT_HINT       = 0xffff00ec

TIMER                   = 0xffff001c

REQUEST_PUZZLE          = 0xffff00d0  ## Puzzle
SUBMIT_SOLUTION         = 0xffff00d4  ## Puzzle

# other player info
GET_WOOD                = 0xffff2000
GET_STONE               = 0xffff2004
GET_WOOL                = 0xffff2008
GET_WOODWALL            = 0xffff200c
GET_STONEWALL           = 0xffff2010
GET_BED                 = 0xffff2014
GET_CHEST               = 0xffff2018
GET_DOOR                = 0xffff201c

GET_HYDRATION           = 0xffff2044
GET_HEALTH              = 0xffff2048

GET_INVENTORY           = 0xffff2034
GET_SQUIRRELS               = 0xffff2038

GET_MAP                 = 0xffff2040

# interrupt masks and acknowledge addresses
BONK_INT_MASK           = 0x1000      ## Bonk
BONK_ACK                = 0xffff0060  ## Bonk

TIMER_INT_MASK          = 0x8000      ## Timer
TIMER_ACK               = 0xffff006c  ## Timer

REQUEST_PUZZLE_INT_MASK = 0x800       ## Puzzle
REQUEST_PUZZLE_ACK      = 0xffff00d8  ## Puzzle

RESPAWN_INT_MASK        = 0x2000      ## Respawn
RESPAWN_ACK             = 0xffff00f0  ## Respawn

NIGHT_INT_MASK          = 0x4000      ## Night
NIGHT_ACK               = 0xffff00e0  ## Night

# world interactions -- input format shown with each command
# X = x tile [0, 39]; Y = y tile [0, 39]; t = block or item type [0, 9]; n = number of items [-128, 127]
CRAFT                   = 0xffff2024    # 0xtttttttt
ATTACK                  = 0xffff2028    # 0x0000XXYY

PLACE_BLOCK             = 0xffff202c    # 0xttttXXYY
BREAK_BLOCK             = 0xffff2020    # 0x0000XXYY
USE_BLOCK               = 0xffff2030    # 0xnnttXXYY, if n is positive, take from chest. if n is negative, give to chest.

SUBMIT_BASE             = 0xffff203c    # stand inside your base when using this command

MMIO_STATUS             = 0xffff204c    # updated with a status code after any MMIO operation

# possible values for MMIO_STATUS
# use ./QtSpimbot -debug for more info!
ST_SUCCESS              = 0  # operation completed succesfully
ST_BEYOND_RANGE         = 1  # target tile too far from player
ST_OUT_OF_BOUNDS        = 2  # target tile outside map
ST_NO_RESOURCES         = 3  # no resources available for PLACE_BLOCK
ST_INVALID_TARGET_TYPE  = 4  # block at target position incompatible with operation
ST_TOO_FAST             = 5  # operation performed too quickly after the last one
ST_STILL_HAS_DURABILITY = 6  # block was damaged by BREAK_BLOCK, but is not yet broken. hit it again.

# block/item IDs
ID_WOOD                 = 0
ID_STONE                = 1
ID_WOOL                 = 2
ID_WOODWALL             = 3
ID_STONEWALL            = 4
ID_BED                  = 5
ID_CHEST                = 6
ID_DOOR                 = 7
ID_GROUND               = 8  # not an item
ID_WATER                = 9  # not an item

.data

### Puzzle
puzzle:     .byte   0:400
sol_t:      .word   12      solution
solution:   .byte   0:256

has_puzzle: .word   0
### Puzzle

inventory:   .word  0:8
map:         .word  0:1600

three:       .float 3.0
five:        .float 5.0
PI:          .float 3.141592
F180:        .float 180.0

.text
main:
    sub     $sp, $sp, 28                        # allocate stack/save s-registers
    sw      $ra, 0($sp)
    sw      $s0, 4($sp)
    sw      $s1, 8($sp)
    sw      $s2, 12($sp)
    sw      $s3, 16($sp)
    sw      $s4, 20($sp)
    sw      $s5, 24($sp)
    
    # not using these currently
    # sw      $s6, 28($sp)
    # sw      $s7, 32($sp)

    # Construct interrupt mask
    li      $t4, 0
    or      $t4, $t4, TIMER_INT_MASK            # enable timer interrupt
    or      $t4, $t4, BONK_INT_MASK             # enable bonk interrupt
    or      $t4, $t4, REQUEST_PUZZLE_INT_MASK   # enable puzzle interrupt
    or      $t4, $t4, RESPAWN_INT_MASK          # enable respawn interrupt
    or      $t4, $t4, NIGHT_INT_MASK            # enable nightfall interrupt
    or      $t4, $t4, 1 # global enable
    mtc0    $t4, $12

# 1) save frequently-used values
    li      $s1, 1                              # $s1 is 1 for absolute (and other uses)

    li      $s2, 10                             # $s2 is max velocity
    
    li      $s3, 90                             # $s3 is south (abs) or right-turn (relative)
    li      $s4, 180                            # $s4 is west (abs) or about-face (relative)
    li      $s5, 270                            # $s5 is north (abs) or 3/4 turn right (relative)

# 2) start requesting puzzles
    la      $s0, puzzle                         # $s0 is starting address of puzzle struct
    sw      $s0, REQUEST_PUZZLE                 # requesting puzzle to solve

# head toward tile [5,16] = pixel [40,128] to start collecting sheep/wood
# sb_arctan works great for diagonal movement!
    li      $a0, 40
    li      $a1, 128
    jal     sb_arctan                           # $v0 is now needed angle

    sw      $v0, ANGLE
    sw      $s1, ANGLE_CONTROL
    sw      $s2, VELOCITY                       # max velocity
    
    li      $t1, 128

initial_move:
    lw      $t0, BOT_Y                          # $t0 is y-coord
    bge     $t0, $t1, stop_for_wool             # if y < 128, keep moving
    j       initial_move

stop_for_wool:
    sw      $zero, VELOCITY                     # stop

wool_and_wood:
    
    # WOOL only need 3 (for making bed)
    # located at tiles [3-4,17] and [5,18]
    li      $t0, 0x0512                         # tile [5,18]
    sw      $t0, BREAK_BLOCK

    li      $t0, 0x0311                         # tile [3,17]
    sw      $t0, BREAK_BLOCK

    li      $t0, 0x0411                         # tile [4,17]
    sw      $t0, BREAK_BLOCK

    # WOOD
    # located at tiles [6,15-16] and [7,16] and [8,17]
    li      $t0, 0x060F                         # tile [6,15]
    sw      $t0, BREAK_BLOCK

    li      $t0, 0x0610                         # tile [6,16]
    sw      $t0, BREAK_BLOCK

    li      $t0, 0x070F                         # tile [7,15]
    sw      $t0, BREAK_BLOCK

    li      $t0, 0x0710                         # tile [7,16]
    sw      $t0, BREAK_BLOCK

    li      $t0, 0x0810                         # tile [8,16]
    sw      $t0, BREAK_BLOCK

    li      $t3, 5
    lw      $t1, GET_WOOD
    bge     $t1, $t3, center
    j       wool_and_wood

center:
    sw      $zero, ANGLE                        
    sw      $s1, ANGLE_CONTROL                  # absolute east
    sw      $s2, VELOCITY                       # max velocity

# tile [14,16]
promised_land:
    lw      $t0, BOT_X                          # $t0 is x-coord
    li      $t1, 112                            # (pixel 112 -> tile number 14)
    bge     $t0, $t1, slow_up
    j       promised_land

slow_up:
    sw      $zero, VELOCITY                     # STOP (at tile [14,16])

    # DRINK
    li      $t0, 0x100F                         # tile [16,15] (water)
    sw      $t0, USE_BLOCK

break_it_up:

    # STONE
    li      $t0, 0x0E10                         # tile [14,16] (stone)
    sw      $t0, BREAK_BLOCK                    # (also my location)

    li      $t0, 0x0F10                         # tile [15,16] (stone)
    sw      $t0, BREAK_BLOCK

    li      $t0, 0x0E0F                         # tile [14,15] (stone)
    sw      $t0, BREAK_BLOCK

    li      $t0, 0x0D10                         # tile [13,16] (stone)
    sw      $t0, BREAK_BLOCK

    li      $t0, 0x0D0F                         # tile [13,15] (stone)
    sw      $t0, BREAK_BLOCK

    li      $t0, 0x0D11                         # tile [13,17] (stone)
    sw      $t0, BREAK_BLOCK

    li      $t0, 0x0E12                         # tile [14,18] (stone)
    sw      $t0, BREAK_BLOCK

    li      $t0, 0x0F12                         # tile [15,18] (stone)
    sw      $t0, BREAK_BLOCK

    li      $t0, 0x1011                         # tile [16,17] (stone)
    sw      $t0, BREAK_BLOCK


    # WOOD
    li      $t0, 0x0E11                         # tile [14,17] (wood)
    sw      $t0, BREAK_BLOCK

    li      $t0, 0x0F11                         # tile [15,17] (wood)
    sw      $t0, BREAK_BLOCK

    li      $t0, 0x0E0E                         # tile [14,14] (wood)
    sw      $t0, BREAK_BLOCK

    li      $t0, 0x0F0F                         # tile [15,15] (wood)
    sw      $t0, BREAK_BLOCK

    li      $t0, 0x1010                         # tile [16,16] (wood)
    sw      $t0, BREAK_BLOCK

    li      $t0, 0x0D12                         # tile [13,18] (wood)
    sw      $t0, BREAK_BLOCK


    lw      $t1, GET_STONE
    li      $t2, 9

    bge     $t1, $t2, crafting
    j       break_it_up


crafting:

    # DRINK
    li      $t0, 0x100F                         # tile [16,15] (water)
    sw      $t0, USE_BLOCK

    li      $t0, ID_STONEWALL
    sw      $t0, CRAFT                          # stone wall #1

    # PLACING walls/door (# 0xttttXXYY)
    li      $t0, 0x00040E0F                     # stone wall at [14,15]
    sw      $t0, PLACE_BLOCK

    li      $t0, ID_STONEWALL
    sw      $t0, CRAFT                          # stone wall #2

    li      $t0, 0x00040F10                     # [15,16]
    sw      $t0, PLACE_BLOCK

    li      $t0, ID_STONEWALL
    sw      $t0, CRAFT                          # stone wall #3

    li      $t0, 0x00040D10                     # [13,16]
    sw      $t0, PLACE_BLOCK

    li      $t0, ID_DOOR
    sw      $t0, CRAFT                          # door

    li      $t0, 0x00070E11                     # Door at [14,17]
    sw      $t0, PLACE_BLOCK

    li      $t0, ID_BED
    sw      $t0, CRAFT

    li      $t0, 0x0E10                         # bed at my location [14,16]
    sw      $t0, PLACE_BLOCK
    sw      $t0, SUBMIT_BASE                    # SUBMIT BASE for grading?


    # need some kind of looping that starts at end of night to acquire resources again
    # j       slow_up                             

  
infinite:
    j infinite

# PUZZLE SOLVER FUNCTIONS (HOW TO OPTIMIZE???)
.globl count_disjoint_regions_step
count_disjoint_regions_step:
    sub	    $sp, $sp, 24
	sw	    $ra, 0 ($sp)
	sw	    $s0, 4 ($sp)                    # marker
    sw      $s1, 8 ($sp)                    # canvas
    sw      $s2, 12($sp)                    # region_count
    sw      $s3, 16($sp)                    # row
    sw      $s4, 20($sp)                    # col
	
    move    $s0, $a0
    move    $s1, $a1
	li	    $s2, 0			                # unsigned int region_count = 0;
        
    li      $s3, 0                          # row = 0
cdrs_outer_loop:                            # for (unsigned int row = 0; row < canvas->height; row++) {
    lw      $t0, 0($s1)                     # canvas->height
    bge     $s3, $t0, cdrs_end_outer_loop   # row < canvas->height : fallthrough

    li      $s4, 0                          # col = 0
cdrs_inner_loop:                            # for (unsigned int col = 0; col < canvas->width; col++) {
    lw      $t0, 4($s1)                     # canvas->width
    bge     $s4, $t0, cdrs_end_inner_loop   # col < canvas->width : fallthrough

    # unsigned char curr_char = canvas->canvas[row][col];
    lw      $t1, 12($s1)                    # &(canvas->canvas)
    mul     $t2, $s3, 4                     # $t2 = row * 4
    add     $t2, $t2, $t1                   # $t2 = canvas->canvas + row * sizeof(char*) = canvas[row]
    lw	    $t1, 0($t2)		                # $t1 = &char = char* = & canvas[row][0]
    add	    $t1, $s4, $t1           	    # $t1 = &canvas[row][col]
    lb	    $t1, 0($t1)		                # $t1 = canvas[row][col] = curr_char

    lb      $t2, 8($s1)                     # $t2 = canvas->pattern 

    # temps:        $t1 = curr_char         $t2 = canvas->pattern

    # if (curr_char != canvas->pattern && curr_char != marker) {
    beq     $t1, $t2, cdrs_endif            # if (curr_char != canvas->pattern) fall
    beq	    $t1, $s0, cdrs_endif            # if (curr_char != marker)          fall
    
    add     $s2, $s2, 1                     # region_count ++;
    move    $a0, $s3                        # (row,
    move    $a1, $s4                        #  col,
    move    $a2, $s0                        #  marker,
    move    $a3, $s1                        #  canvas);
    jal     flood_fill                      # flood_fill(row, col, marker, canvas);
 
cdrs_endif:
    add     $s4, $s4, 1                     # col++
    j       cdrs_inner_loop                 # loop again

cdrs_end_inner_loop:
    add     $s3, $s3, 1                     # row++
    j       cdrs_outer_loop                 # loop again

cdrs_end_outer_loop:
	move	$v0, $s2		                # Copy return val
	lw	    $ra, 0($sp)
	lw	    $s0, 4 ($sp)                    # marker
    lw      $s1, 8 ($sp)                    # canvas
    lw      $s2, 12($sp)                    # region_count
    lw      $s3, 16($sp)                    # row
    lw      $s4, 20($sp)                    # col
	add	    $sp, $sp, 24
	jr      $ra


.globl count_disjoint_regions
count_disjoint_regions:
        sub     $sp, $sp, 20
        sw      $ra, 0($sp)
        sw      $s0, 4($sp)
        sw      $s1, 8($sp)
        sw      $s2, 12($sp)
        sw      $s3, 16($sp)

        move    $s0, $a0                # line
        move    $s1, $a1                # canvas
        move    $s2, $a2                # solution

        li      $s3, 0                  # unsigned int i = 0;
cdr_loop:
        lw	    $t0, 0($s0)		        # $t0 = lines->num_lines
        bge     $s3, $t0, cdr_end       # i < lines->num_lines : fallthrough
        
        #lines->coords[0][i];
        lw	    $t1, 4($s0)		        # $t1 = &(lines->coords[0][0])
        lw	    $t2, 8($s0)		        # $t2 = &(lines->coords[1][0])

        mul     $t3, $s3, 4             # i * sizeof(int*)
        add     $t1, $t3, $t1           # $t1 = &(lines->coords[0][i])
        add     $t2, $t3, $t2           # $t2 = &(lines->coords[1][i])

        lw      $a0, 0($t1)             # $a0 = lines->coords[0][i] = start_pos
        lw      $a1, 0($t2)             # $a1 = lines->coords[0][i] = end_pos
        move    $a2, $s1                # $a2 = canvas
        jal     draw_line               # draw_line(start_pos, end_pos, canvas);

        li      $a0, 65                 # Immediate value A
        rem     $t1, $s3, 2             # i % 2
        add     $a0, $a0, $t1           # 'A' or 'B'
        move    $a1, $s1
        jal     count_disjoint_regions_step  # count_disjoint_regions_step('A' + (i % 2), canvas);
        # $v0 = count_disjoint_regions_step('A' + (i % 2), canvas);

        lw      $t0, 4($s2)             # &counts = &counts[0]
        mul     $t1, $s3, 4             #  i * sizeof(unsigned int)
        add     $t0, $t1, $t0           # *counts[i]
        sw      $v0, 0($t0)

##         // Update the solution struct. Memory for counts is preallocated.
##         solution->counts[i] = count;

        add     $s3, $s3, 1             # i++
        j       cdr_loop
cdr_end:
        lw      $ra, 0($sp)
        lw      $s0, 4($sp)
        lw      $s1, 8($sp)
        lw      $s2, 12($sp)
        lw      $s3, 16($sp)
        add     $sp, $sp, 20
        jr      $ra

.globl draw_line
draw_line:
        lw      $t0, 4($a2)     # t0 = width = canvas->width
        li      $t1, 1          # t1 = step_size = 1
        sub     $t2, $a1, $a0   # t2 = end_pos - start_pos
        blt     $t2, $t0, dl_cont
        move    $t1, $t0        # step_size = width;
dl_cont:
        move    $t3, $a0        # t3 = pos = start_pos
        add     $t4, $a1, $t1   # t4 = end_pos + step_size
        lw      $t5, 12($a2)    # t5 = &canvas->canvas
        lbu     $t6, 8($a2)     # t6 = canvas->pattern
dl_for_loop:
        beq     $t3, $t4, dl_end_for
        div     $t3, $t0        #
        mfhi    $t7             # t7 = pos % width
        mflo    $t8             # t8 = pos / width
        mul     $t9, $t8, 4		# t9 = pos/width*4
        add     $t9, $t9, $t5   # t9 = &canvas->canvas[pos / width]
        lw      $t9, 0($t9)     # t9 = canvas->canvas[pos / width]
        add     $t9, $t9, $t7
        sb      $t6, 0($t9)     # canvas->canvas[pos / width][pos % width] = canvas->pattern
        add     $t3, $t3, $t1   # pos += step_size
        j       dl_for_loop
dl_end_for:
        jr      $ra

.globl flood_fill
flood_fill:
	blt	$a0, $zero, ff_end		# row < 0 
	blt	$a1, $zero, ff_end		# col < 0
	lw	$t0, 0($a3)		        # $t0 = canvas->height
	bge	$a0, $t0, ff_end		# row >= canvas->height
	lw	$t0, 4($a3)		        # $t0 = canvas->width
	bge	$a1, $t0, ff_end		# col >= canvas->width
	j 	ff_recur			    # NONE TRUE

ff_recur:
	# Find curr
	lw	$t0, 12($a3)		# canvas->canvas
	mul	$t1, $a0, 4		# row * sizeof(char*)
	add	$t1, $t1, $t0		# $t1 = canvas->canvas + row * sizeof(char*) = canvas[row]
	lw	$t2, 0($t1)		# $t2 = &char = char* = & canvas[row][0]
	add	$t2, $a1, $t2		# $t2 = &canvas[row][col]
	lb	$t3, 0($t2)		# $t3 = curr
	
	lb	$t4, 8($a3)		# $t4 = canvas->pattern
	
	beq	$t3, $t4, ff_end		# curr == canvas->pattern : break 
	beq	$t3, $a2, ff_end		# curr == marker          : break
	
	#FLOODFILL
	sb	$a2, ($t2) 
	
	# Save depenedecies
	sub	$sp, $sp, 12
	sw	$ra, 0($sp)
	sw	$s0, 4($sp)
	sw	$s1, 8($sp)
	move	$s0, $a0
	move	$s1, $a1
	
	sub	$a0, $s0, 1
	move	$a1, $s1
	jal	flood_fill

	move	$a0, $s0
	add	$a1, $s1, 1
	jal	flood_fill

	add	$a0, $s0, 1
	move	$a1, $s1
	jal	flood_fill

	move	$a0, $s0
	sub	$a1, $s1, 1
	jal	flood_fill
	
	# Restore VARS
	lw	$ra, 0($sp)
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	add	$sp, $sp, 12
ff_end:
	jr 	$ra

# $a0 - x
# $a1 - y
# computes arctangent (angle between) x and y
.globl sb_arctan
sb_arctan:
    li      $v0, 0                      # angle = 0;
    abs     $t0, $a0                    # get absolute values
    abs     $t1, $a1
    ble     $t1, $t0, no_TURN_90
    ## if (abs(y) > abs(x)) { rotate 90 degrees }
    move    $t0, $a1                    # int temp = y
    neg     $a1, $a0                    # y = -x
    move    $a0, $t0                    # x = temp
    li      $v0, 90                     # angle = 90
no_TURN_90:
    bgez    $a0, pos_x                  # skip if (x >= 0)
    ## if (x < 0)
    add     $v0, $v0, 180               # angle += 180
pos_x:
    mtc1    $a0, $f0
    mtc1    $a1, $f1 
    cvt.s.w $f0, $f0 
    cvt.s.w $f1, $f1 
    div.s   $f0, $f1, $f0 
    mul.s   $f1, $f0, $f0 
    mul.s   $f2, $f1, $f0 
    l.s     $f3, three 
    div.s   $f3, $f2, $f3 
    sub.s   $f6, $f0, $f3 
    mul.s   $f4, $f1, $f2 
    l.s     $f5, five 
    div.s   $f5, $f4, $f5 
    add.s   $f6, $f6, $f5 
    l.s     $f8, PI
    div.s   $f6, $f6, $f8 
    l.s     $f7, F180 
    mul.s   $f6, $f6, $f7 
    cvt.w.s $f6, $f6
    mfc1    $t0, $f6
    add     $v0, $v0, $t0 
    jr $ra

.kdata
chunkIH:    .space 40
non_intrpt_str:    .asciiz "Non-interrupt exception\n"
unhandled_str:    .asciiz "Unhandled interrupt type\n"
.ktext 0x80000180
interrupt_handler:
.set noat
    move    $k1, $at        # Save $at
                            # NOTE: Don't touch $k1 or else you destroy $at!
.set at
    la      $k0, chunkIH
    sw      $a0, 0($k0)        # Get some free registers
    sw      $v0, 4($k0)        # by storing them to a global variable
    sw      $t0, 8($k0)
    sw      $t1, 12($k0)
    sw      $t2, 16($k0)
    sw      $t3, 20($k0)
    sw      $t4, 24($k0)
    sw      $t5, 28($k0)

    # Save coprocessor1 registers!
    # If you don't do this and you decide to use division or multiplication
    #   in your main code, and interrupt handler code, you get WEIRD bugs.
    mfhi    $t0
    sw      $t0, 32($k0)
    mflo    $t0
    sw      $t0, 36($k0)

    mfc0    $k0, $13                # Get Cause register
    srl     $a0, $k0, 2
    and     $a0, $a0, 0xf           # ExcCode field
    bne     $a0, 0, non_intrpt


interrupt_dispatch:                 # Interrupt:
    mfc0    $k0, $13                # Get Cause register, again
    beq     $k0, 0, done            # handled all outstanding interrupts

    and     $a0, $k0, BONK_INT_MASK     # is there a bonk interrupt?
    bne     $a0, 0, bonk_interrupt

    and     $a0, $k0, TIMER_INT_MASK    # is there a timer interrupt?
    bne     $a0, 0, timer_interrupt

    and     $a0, $k0, REQUEST_PUZZLE_INT_MASK
    bne     $a0, 0, request_puzzle_interrupt

    and     $a0, $k0, RESPAWN_INT_MASK
    bne     $a0, 0, respawn_interrupt

    and     $a0, $k0, NIGHT_INT_MASK
    bne     $a0, 0, night_interrupt

    li      $v0, PRINT_STRING       # Unhandled interrupt types
    la      $a0, unhandled_str
    syscall
    j       done

bonk_interrupt:
    sw      $0, BONK_ACK            # acknowledge bonk

    # this will just keep turning right and going until free from bonks
    sw      $s3, ANGLE              # $s3 is 90
    sw      $zero, ANGLE_CONTROL    # 0 is relative
    sw      $s2, VELOCITY           # $s2 is 10 (max velocity)

    j       interrupt_dispatch      # see if other interrupts are waiting

timer_interrupt:
    sw      $0, TIMER_ACK

    # Request timer for (#?) cycles BEFORE nightfall, to start heading back to fort
    # (before squirrels come out)

    # Request timer for start of day to come out of fort?
    
    j        interrupt_dispatch     # see if other interrupts are waiting

request_puzzle_interrupt:
    sw      $0, REQUEST_PUZZLE_ACK      # acknowledge puzzle interrupt

    sw      $s1, has_puzzle             # has_puzzle = 1 (?)
    
    la      $a1, puzzle                 # 2nd arg is start of Canvas
    add     $a0, $a1, 16                # 1st arg is start of Lines
    la      $a2, sol_t                  # 3rd arg is start of Solution struct

    la      $t0, count_disjoint_regions
    jalr    $t0                         # jalr allows call of c_d_r within ktext

    la      $t0, solution
    sw      $t0, SUBMIT_SOLUTION        # send solution address for check

    sw      $zero, has_puzzle           # has_puzzle = 0 (?)

    # Seem to have enough creativity to build multiple items w/o constantly requesting puzzle (?)
    # sw      $s2, REQUEST_PUZZLE         # request another puzzle

    j       interrupt_dispatch

respawn_interrupt:
    sw      $0, RESPAWN_ACK

    # head back to fort location (currently tile [14,16])
    # this will initially drive spimbot to fort location but then it will go all over due to bonks
    # li      $a0, 112
    # li      $a1, 128
    
    # la      $t0, sb_arctan
    # jalr    $t0                           # $v0 is now needed angle

    # sw      $v0, ANGLE
    # sw      $s1, ANGLE_CONTROL
    # sw      $s2, VELOCITY                       # max velocity
    
    # li      $t1, 128

# return_home:
    # lw      $t0, BOT_Y                          # $t0 is y-coord
    # bge     $t0, $t1, continue                  # if y < 128, keep moving
    # j       return_home

# continue:
    j       interrupt_dispatch

night_interrupt:
    sw      $0, NIGHT_ACK
    #Fill in your nightfall handler code here
    j  interrupt_dispatch

non_intrpt:                         # was some non-interrupt
    li      $v0, PRINT_STRING
    la      $a0, non_intrpt_str
    syscall                         # print out an error message
    # fall through to done

done:
    la      $k0, chunkIH

    # Restore coprocessor1 registers!
    # If you don't do this and you decide to use division or multiplication
    #   in your main code, and interrupt handler code, you get WEIRD bugs.
    lw      $t0, 32($k0)
    mthi    $t0
    lw      $t0, 36($k0)
    mtlo    $t0

    lw      $a0, 0($k0)             # Restore saved registers
    lw      $v0, 4($k0)
    lw      $t0, 8($k0)
    lw      $t1, 12($k0)
    lw      $t2, 16($k0)
    lw      $t3, 20($k0)
    lw      $t4, 24($k0)
    lw      $t5, 28($k0)

.set noat
    move    $at, $k1        # Restore $at
.set at
    eret
