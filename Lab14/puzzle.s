# MINIMAL EXAMPLE OF INTEGRATING PUZZLE SOLVING.
# THIS FILE IS NOT GRADED

# interrupt constants

REQUEST_PUZZLE_INT_MASK = 0x800
REQUEST_PUZZLE_ACK      = 0xffff00d8

REQUEST_PUZZLE          = 0xffff00d0
SUBMIT_SOLUTION         = 0xffff00d4

LINE_OFFSET = 16
PUZZLE_SIZE = 512
SOLUTION_SIZE = 64


.data
# put your data things here
.align 2
puzzle_ready: .word 0
puzzle_solution: .space SOLUTION_SIZE
puzzle_data: .space PUZZLE_SIZE

.text
main:
  #Enable all interrupts here
  move $t4, $zero
  or  $t4, $t4, REQUEST_PUZZLE_INT_MASK
  or  $t4, $t4, 1

  li  $t1, 0
  sw  $t1, THROW_PUZZLE

  mtc0  $t4, $12

puzzle_loop:
  #Request puzzle
  la $t0, puzzle_data
  sw $t0, REQUEST_PUZZLE

  #Wait for puzzle
puzzle_wait:
  lw    $t0, puzzle_ready
  bne   $zero, $t0, puzzle_wait_end
  j puzzle_wait
puzzle_wait_end:

  #set the resource desired

  #Solve the puzzle
  jal   solve_puzzle
  sw    $0, puzzle_ready

  # note that we infinite loop to avoid stopping the simulation early
  j     puzzle_loop

#solve puzzle function of a given inpu
solve_puzzle:
  sub $sp, $sp, 32
  sw $ra, 0($sp)
  sw $s0, 4($sp)
  sw $s1, 8($sp)
  sw $s2, 12($sp)

  la $s0, puzzle_solution
  add $t2, $s0, 8
  sw $t2, 4($s0)
  la $s1, puzzle_data
  lw $t0, LINE_OFFSET($s1) #Grab the num of lines
  sw $t0, 0($s0) #Store in solution struct

  add $a0, $s1, LINE_OFFSET
  move $a1, $s1
  move $a2, $s0
  jal count_disjoint_regions
 
  add $s0, $s0, 8 #point to the array of solution
  sw $s0, SUBMIT_SOLUTION #submit the puzzle


  lw $ra, 0($sp)
  lw $s0, 4($sp)
  lw $s1, 8($sp)
  lw $s2, 12($sp)
  add $sp, $sp, 32

  jr $ra

#Puzzle solving functions
.globl draw_line
draw_line:
        lw      $t0, 4($a2)     # t0 = width = canvas->width
        li      $t1, 1          # t1 = step_size = 1
        sub     $t2, $a1, $a0   # t2 = end_pos - start_pos
        blt     $t2, $t0, cont
        move    $t1, $t0        # step_size = width;
cont:
        move    $t3, $a0        # t3 = pos = start_pos
        add     $t4, $a1, $t1   # t4 = end_pos + step_size
        lw      $t5, 12($a2)    # t5 = &canvas->canvas
        lbu     $t6, 8($a2)     # t6 = canvas->pattern
for_loop_draw_line:
        beq     $t3, $t4, end_for_draw_line
        div     $t3, $t0        #
        mfhi    $t7             # t7 = pos % width
        mflo    $t8             # t8 = pos / width
        mul     $t9, $t8, 4     # t9 = pos/width*4
        add     $t9, $t9, $t5   # t9 = &canvas->canvas[pos / width]
        lw      $t9, 0($t9)     # t9 = canvas->canvas[pos / width]
        add     $t9, $t9, $t7
        sb      $t6, 0($t9)     # canvas->canvas[pos / width][pos % width] = canvas->pattern
        add     $t3, $t3, $t1   # pos += step_size
        j       for_loop_draw_line
end_for_draw_line:
        jr      $ra



.globl flood_fill
flood_fill:
        sub     $sp, $sp, 20
        sw      $ra, 0($sp)
        sw      $s0, 4($sp)
        sw      $s1, 8($sp)
        sw      $s2, 12($sp)
        sw      $s3, 16($sp)
        move    $s0, $a0                # $s0 = row
        move    $s1, $a1                # $s1 = col
        move    $s2, $a2                # $s2 = marker
        move    $s3, $a3                # $s3 = canvas
        blt     $s0, $0, ff_return      # row < 0
        blt     $s1, $0, ff_return      # col < 0
        lw      $t0, 0($s3)             # $t0 = canvas->height
        bge     $s0, $t0, ff_return     # row >= canvas->height
        lw      $t0, 4($s3)             # $t0 = canvas->width
        bge     $s1, $t0, ff_return     # col >= canvas->width

        lw      $t0, 12($s3)            # canvas->canvas
        mul     $t1, $s0, 4
        add     $t0, $t1, $t0           # $t0 = &canvas->canvas[row]
        lw      $t0, 0($t0)             # canvas->canvas[row]
        add     $t1, $s1, $t0           # $t1 = &canvas->canvas[row][col]
        lbu     $t0, 0($t1)             # $t0 = curr = canvas->canvas[row][col]
        lbu     $t2, 8($s3)             # $t2 = canvas->pattern
        beq     $t0, $t2, ff_return     # curr == canvas->pattern
        beq     $t0, $s2, ff_return     # curr == marker

        sb      $s2, 0($t1)             # canvas->canvas[row][col] = marker
        sub     $a0, $s0, 1             # $a0 = row - 1
        jal     flood_fill              # flood_fill(row - 1, col, marker, canvas);
        move    $a0, $s0
        add     $a1, $s1, 1
        move    $a2, $s2
        move    $a3, $s3
        jal     flood_fill              # flood_fill(row, col + 1, marker, canvas);
        add     $a0, $s0, 1
        move    $a1, $s1
        move    $a2, $s2
        move    $a3, $s3
        jal     flood_fill              # flood_fill(row + 1, col, marker, canvas);
        move    $a0, $s0
        sub     $a1, $s1, 1
        move    $a2, $s2
        move    $a3, $s3
        jal     flood_fill              # flood_fill(row, col - 1, marker, canvas);

ff_return:
        lw      $ra, 0($sp)
        lw      $s0, 4($sp)
        lw      $s1, 8($sp)
        lw      $s2, 12($sp)
        lw      $s3, 16($sp)
        add     $sp, $sp, 20
        jr      $ra


.globl count_disjoint_regions_step
count_disjoint_regions_step:
        sub     $sp, $sp, 36
        sw      $ra, 0($sp)
        sw      $s0, 4($sp)
        sw      $s1, 8($sp)
        sw      $s2, 12($sp)
        sw      $s3, 16($sp)
        sw      $s4, 20($sp)
        sw      $s5, 24($sp)
        sw      $s6, 28($sp)
        sw      $s7, 32($sp)

        move    $s0, $a0
        move    $s1, $a1

        li      $s2, 0                  # $s2 = region_count
        li      $s3, 0                  # $s3 = row
        lw      $s4, 0($s1)             # $s4 = canvas->height
        lw      $s6, 4($s1)             # $s6 = canvas->width
        lw      $s7, 8($s1)             # canvas->pattern

cdrs_outer_for_loop:
        bge     $s3, $s4, cdrs_outer_end
        li      $s5, 0                  # $s5 = col

cdrs_inner_for_loop:
        bge     $s5, $s6, cdrs_inner_end
        lw      $t0, 12($s1)            # canvas->canvas
        mul     $t5, $s3, 4             # row * 4
        add     $t5, $t0, $t5           # &canvas->canvas[row]
        lw      $t0, 0($t5)             # canvas->canvas[row] 
        add     $t0, $t0, $s5           # &canvas->canvas[row][col]
        lbu     $t0, 0($t0)             # $t0 = canvas->canvas[row][col]
        beq     $t0, $s7, cdrs_skip_if  # curr_char != canvas->pattern
        beq     $t0, $s0, cdrs_skip_if  # curr_char != canvas->marker
        add     $s2, $s2, 1             # region_count++
        move    $a0, $s3
        move    $a1, $s5
        move    $a2, $s0
        move    $a3, $s1
        jal     flood_fill

cdrs_skip_if:
        add     $s5, $s5, 1             # col++
        j       cdrs_inner_for_loop

cdrs_inner_end:
        add     $s3, $s3, 1             # row++
        j       cdrs_outer_for_loop

cdrs_outer_end:
        move    $v0, $s2
        lw      $ra, 0($sp)
        lw      $s0, 4($sp)
        lw      $s1, 8($sp)
        lw      $s2, 12($sp)
        lw      $s3, 16($sp)
        lw      $s4, 20($sp)
        lw      $s5, 24($sp)
        lw      $s6, 28($sp)
        lw      $s7, 32($sp)
        add     $sp, $sp, 36
        jr      $ra



.globl count_disjoint_regions
count_disjoint_regions:
        sub     $sp, $sp, 36
        sw      $ra, 0($sp)
        sw      $s0, 4($sp)
        sw      $s1, 8($sp)
        sw      $s2, 12($sp)
        sw      $s3, 16($sp)
        sw      $s4, 20($sp)
        sw      $s5, 24($sp)
        sw      $s6, 28($sp)
        sw      $s7, 32($sp)
        move    $s0, $a0        # s0 = lines
        move    $s1, $a1        # s1 = canvas
        move    $s2, $a2        # s2 = solution

        lw      $s4, 0($s0)     # s4 = lines->num_lines
        li      $s5, 0          # s5 = i
        lw      $s6, 4($s0)     # s6 = lines->coords[0]
        lw      $s7, 8($s0)     # s7 = lines->coords[1]
for_loop_disjoint_regions:
        bgeu    $s5, $s4, end_for_disjoint_regions
        mul     $t2, $s5, 4     # t2 = i*4
        add     $t3, $s6, $t2   # t3 = &lines->coords[0][i]
        lw      $a0, 0($t3)     # a0 = start_pos = lines->coords[0][i]
        add     $t4, $s7, $t2   # t4 = &lines->coords[1][i]
        lw      $a1, 0($t4)     # a1 = end_pos = lines->coords[1][i]
        move    $a2, $s1
        jal     draw_line
        li      $t9, 2
        div     $s5, $t9
        mfhi    $t6             # t6 = i % 2
        addi    $a0, $t6, 65    # a0 = 'A' + (i % 2)
        move    $a1, $s1        # count_disjoint_regions_step('A' + (i % 2), canvas)
        jal     count_disjoint_regions_step   # v0 = count
        lw      $t6, 4($s2)     # t6 = solution->counts
        mul     $t7, $s5, 4
        add     $t7, $t7, $t6   # t7 = &solution->counts[i]
        sw      $v0, 0($t7)     # solution->counts[i] = count
        addi    $s5, $s5, 1     # i++
        j       for_loop_disjoint_regions

end_for_disjoint_regions:
        lw      $ra, 0($sp)
        lw      $s0, 4($sp)
        lw      $s1, 8($sp)
        lw      $s2, 12($sp)
        lw      $s3, 16($sp)
        lw      $s4, 20($sp)
        lw      $s5, 24($sp)
        lw      $s6, 28($sp)
        lw      $s7, 32($sp)
        add     $sp, $sp, 36
        jr      $ra




#Interrupt handler code
.kdata
chunkIH:    .space 28
non_intrpt_str:    .asciiz "Non-interrupt exception\n"
unhandled_str:    .asciiz "Unhandled interrupt type\n"

.ktext 0x80000180
interrupt_handler:
.set noat
        move      $k1, $at        # Save $at
.set at
        la        $k0, chunkIH
        sw        $a0, 0($k0)        # Get some free registers
        sw        $v0, 4($k0)        # by storing them to a global variable
        sw        $t0, 8($k0)
        sw        $t1, 12($k0)
        sw        $t2, 16($k0)
        sw        $t3, 20($k0)

        mfc0      $k0, $13        # Get Cause register
        srl       $a0, $k0, 2
        and       $a0, $a0, 0xf        # ExcCode field
        bne       $a0, 0, non_intrpt



interrupt_dispatch:            # Interrupt:
    mfc0       $k0, $13        # Get Cause register, again
    beq        $k0, 0, done        # handled all outstanding interrupts

    and        $a0, $k0, REQUEST_PUZZLE_INT_MASK
    bne        $a0, 0, puzzle_interrupt
    # add dispatch for other interrupt types here.

    li        $v0, PRINT_STRING    # Unhandled interrupt types
    la        $a0, unhandled_str
    syscall
    j    done

puzzle_interrupt:
    li      $v0, 1
    sw      $v0, REQUEST_PUZZLE_ACK
    sw      $v0, puzzle_ready
    j       interrupt_dispatch

non_intrpt:                # was some non-interrupt
    li        $v0, PRINT_STRING
    la        $a0, non_intrpt_str
    syscall                # print out an error message
    # fall through to done

done:
    la        $k0, chunkIH
    lw        $a0, 0($k0)        # Restore saved registers
    lw        $v0, 4($k0)
    lw        $t0, 8($k0)
    lw      $t1, 12($k0)
    lw      $t2, 16($k0)
    lw      $t3, 20($k0)
.set noat
    move    $at, $k1        # Restore $at
.set at
    eret
