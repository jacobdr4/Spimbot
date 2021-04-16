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
puzzle:     .byte 0:268
solution:   .byte 0:256

has_puzzle: .word 0
### Puzzle

inventory:    .word 0:8
map:          .word 0:1600

.text
main:
    sub $sp, $sp, 4
    sw  $ra, 0($sp)

    # Construct interrupt mask
    li      $t4, 0
    or      $t4, $t4, TIMER_INT_MASK            # enable timer interrupt
    or      $t4, $t4, BONK_INT_MASK             # enable bonk interrupt
    or      $t4, $t4, REQUEST_PUZZLE_INT_MASK   # enable puzzle interrupt
    or      $t4, $t4, RESPAWN_INT_MASK          # enable respawn interrupt
    or      $t4, $t4, NIGHT_INT_MASK            # enable nightfall interrupt
    or      $t4, $t4, 1 # global enable
    mtc0    $t4, $12

infinite:
    j infinite


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
    sw      $0, BONK_ACK
    #Fill in your bonk handler code here
    j       interrupt_dispatch      # see if other interrupts are waiting

timer_interrupt:
    sw      $0, TIMER_ACK
    #Fill in your timer handler code here
    j        interrupt_dispatch     # see if other interrupts are waiting

request_puzzle_interrupt:
    sw      $0, REQUEST_PUZZLE_ACK
    #Fill in your puzzle interrupt code here
    j       interrupt_dispatch

respawn_interrupt:
    sw      $0, RESPAWN_ACK
    #Fill in your respawn handler code here
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

