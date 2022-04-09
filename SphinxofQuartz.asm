                    ROMW    16  

; Future enhancements:
;   1.  Controller presses at title screen change memory slightly.  Use following addresses to
;       seed RNDLO and RNDHI: 0103, 0148, 02F6, 02F7, 02F9, 035E (last one is very random)

;----------
; Constants
;----------

HAND_DEBOUNCE_MAX   EQU     2
HAND_BUTTON_CLEAR   EQU     10
HAND_BUTTON_ENTER   EQU     11
GRAM_MOBS           EQU     $3800 + 56*8
MAX_TASKS           EQU     9
SPARKLE_COUNT       EQU     5
BLD_DRIP_INDEX      EQU     5       ; Blood drip task index
BLD_BTM_INDEX       EQU     6       ; Blood bottom of sword task index
BLD_TOP_INDEX       EQU     7       ; Blood top of sword task index
BLD_XP              EQU     49      ; X position of Blood MOB's upper-left corner
BLD_YP              EQU     64      ; Y position of Blood MOB's upper-left corner
C_JDG               EQU     $1      ; X_BLU
C_SPH               EQU     $1001   ; X_CYN
C_BLD               EQU     $2      ; X_RED

;-------
; Macros
;-------

; Computes a STIC.mob_x value of xSize (1b), Visible (1b), Interacts (1b), and X-coordinate (8b)
MACRO stic_x( size, visi, inte, x )
    ( ( (%size%) SHL 10 ) + ( (%visi%) SHL 9 ) + ( (%inte%) SHL 8 ) + (%x%) )
ENDM

; Computes a STIC.mob_y value of Flip-Y (1b), Flip-X (1b), Size (2b), Resolution y (1b), Y-coordinate (7b) 
MACRO stic_y( flipy, flipx, size, res, y )
    ( ( (%flipy%) SHL 11 ) + ( (%flipx%) SHL 10 ) + ( (%size%) SHL 8 ) + ( (%res%) SHL 7 ) + (%y%) )
ENDM

; Computes a STIC.mob_a value of Priority (1b), GRAM? (1b), Card number (8b), Color (3b)
MACRO stic_a( pri, gram, card, color )
    ( ( (%pri%) SHL 13 ) + ( (%gram%) SHL 11 ) + ( (%card%) SHL 3 ) + (%color%) )
ENDM

; Computes a backtab card value of Advance? (1b), GRAM? (1b), Card number (8b), Color (3b)
MACRO backtab_cs( adv, gram, card, color )
    ( ( (%adv%) SHL 13 ) + ( (%gram%) SHL 11 ) + ( (%card%) SHL 3 ) + (%color%) )
ENDM

;----------------
; 8-bit variables
;----------------
ISR_VECTOR          EQU     $0100

VARS_8B             ORG     $015D, $015D, "-RWBN"

IS_ISR_BLOCKING     RMB     1
HAND_DEBOUNCE_COUNT RMB     1
HAND_VALUE_LEGIT    RMB     1
HAND_VALUE_PENDING  RMB     1
GRAM_MOBS_SHADOW    RMB     8*8
EASTER_EGG_STATE    RMB     1
BLD_STATE           RMB     1

__VARS_8B           EQU     $

;-----------------
; 16-bit variables
;-----------------
VARS_16B            ORG     $031D, $031D, "-RWBN"

ISR_EXEC            RMB     1
TASK_TABLE          RMB     MAX_TASKS*2                 ; Pairs of timer countdown (before function is called) and function's address
                                                        ; The first 8 are intended for MOBs, the others are for non-MOBs
STIC_SHADOW         STRUCT  $
@@mob_x             RMB     8
@@mob_y             RMB     8
@@mob_a             RMB     8
__STIC_SHADOW       EQU     $
                    ENDS
                    ORG     __STIC_SHADOW, __STIC_SHADOW, "-RWBN"
SPARKLE_STATE       RMB     SPARKLE_COUNT
RNDLO               RMB     1    ; RAND          16-bit          Random number state
RNDHI               RMB     1    ; RAND          16-bit          Random number state
                    
__VARS_16B          EQU     $

;------------------
; EXEC routines
;------------------
X_PLAY_MUS3:        EQU     $1B95
X_PLAY_SFX1:        EQU     $1BBB
X_FILL_ZERO:        EQU     $1738

                    ORG     $5000

;------------------------------------------------------------------------------
; EXEC-friendly ROM header.
;------------------------------------------------------------------------------
ROMHDR: BIDECLE ZERO            ; MOB picture base   (points to NULL list)
        BIDECLE ZERO            ; Process table      (points to NULL list)
        BIDECLE MAIN_INIT       ; Program start address
        BIDECLE GRAM_CARDS      ; Bkgnd picture base (points to NULL list)
        BIDECLE GRAM_INIT       ; GRAM pictures      (points to NULL list)
        BIDECLE TITLE           ; Cartridge title/date
        DECLE   $03C0           ; Flags:  No ECS title, run code after title,
                                ; ... no clicks
ZERO:   DECLE   $0000           ; Screen border control
        DECLE   $0000           ; 0 = color stack, 1 = f/b mode
        DECLE   0, 0, 0, 0      ; Color stack init
        DECLE   0               ; Border color init
;------------------------------------------------------------------------------

; Title year, text, and screen update code
TITLE               PROC
                    DECLE   119, "Sphinx of Quartz Judge My Black Vow", 0
                    BEGIN
                    CALL    PRINT.FLS                       ; -.
                    DECLE   X_WHT                           ;  |
                    DECLE   $200 + 3*20                     ;  |
                    DECLE   "      Lathe26       ", 0       ;  |             
                    CALL    PRINT.FLS                       ;  |
                    DECLE   X_BLK                           ;  |
                    DECLE   $200 + 6*20                     ;  |
                    DECLE   "  Sphinx of Quartz, ", 0       ;  |
                    CALL    PRINT.FLS                       ;  |
                    DECLE   X_BLK                           ;  |_ Update the title screen with custom text.
                    DECLE   $200 + 7*20                     ;  |
                    DECLE   " Judge My Black Vow ", 0       ;  |
                    CALL    PRINT.FLS                       ;  |
                    DECLE   X_BLK                           ;  |
                    DECLE   $200 + 8*20                     ;  |
                    DECLE   "                    ", 0       ;  |
                    CALL    PRINT.FLS                       ;  |
                    DECLE   X_WHT                           ;  |    
                    DECLE   $200 + 10*20 + 1                ;  |
                    DECLE   "  Copywrite 2019  ", 0         ; -'
                    RETURN
                    ENDP
                    
; Handles interrupt processing, then calls the EXEC's original ISR code.
ISR_HANDLER         PROC
                    PSHR    R5                              ; Save return address while the ISR does its work
                    CALL    MEMCPY                          ; -._ Copy the STIC shadow data to the actual registers
                    DECLE   STIC, STIC_SHADOW, 24           ; -'
                    CALL    MEMCPY                          ; -.
                    DECLE   GRAM_MOBS                       ;  |- Copy the 8 MOBs to GRAM
                    DECLE   GRAM_MOBS_SHADOW, 64            ; -'
                    CLRR    R0                              ; -._ Clear the IS_ISR_BLOCKING flag so BLOCK_FOR_ISR will exit.
                    MVO     R0, IS_ISR_BLOCKING             ; -'
                    PULR    R5                              ; Restore the return address since this ISR is almost done
                    MVI     ISR_EXEC, R7                    ; Call the original EXEC ISR
                    ENDP

; Installs the new ISR, called ISR_HANDLER.
INSTALL_ISR         PROC
                    BEGIN
                    DIS                                     ; Disable interrupts
                    MVII    #ISR_VECTOR, R4                 ; -.
                    SDBD                                    ;  |_ Save original EXEC's ISR to ISR_EXEC
                    MVI@    R4, R0                          ;  |  
                    MVO     R0, ISR_EXEC                    ; -' 
                    MVII    #ISR_HANDLER, R0                ; -.
                    MVO     R0, ISR_VECTOR                  ;  |_ Install new ISR_HANDLER.  It does work and
                    SWAP    R0                              ;  |  then will call the original EXEC's ISR
                    MVO     R0, ISR_VECTOR+1                ; -'
                    EIS                                     ; Enable interrupts
                    RETURN
                    ENDP
                 
; Causes code to block execution until after the ISR has executed.
; This is used to synchronize with VBLANKs.                 
BLOCK_FOR_ISR       PROC
                    MVII    #1, R0                          ; -._ Set IS_ISR_BLOCKING flag
                    MVO     R0, IS_ISR_BLOCKING             ; -'
@@wait              MVI     IS_ISR_BLOCKING, R0             ; -.
                    TSTR    R0                              ;  |- See if flag is still set, loop until it clears.
                    BNEQ    @@wait                          ; -'
                    MOVR    R5, R7                          ; Return to caller
                    ENDP

; The main starting execution point and where initialization happens.
; The real MAIN is called from here at the end.
MAIN_INIT           PROC
                    MVII    #__VARS_8B - VARS_8B, R1        ; -.
                    MVII    #VARS_8B, R4                    ;  |
                    CALL    FILLZERO                        ;  |_ Zero out all variables
                    MVII    #__VARS_16B - VARS_16B, R1      ;  |
                    MVII    #VARS_16B, R4                   ;  |
                    CALL    FILLZERO                        ; -'                    
                    CALL    INSTALL_ISR                     ; -._ Initialize things
                    CALL    DISPLAY_INIT                    ; -'                    
                    CLRR    R3                              ; -.
@@next_sparkle      CALL    INIT_SPARKLE_VAR                ;  |
                    CALL    SET_TASK.TF                     ;  |
                    DECLE   0, TASK_SPARKLE                 ;  |- Initialize the sparkle animation tasks
                    INCR    R3                              ;  |
                    CMPI    #SPARKLE_COUNT, R3              ;  |
                    BLT     @@next_sparkle                  ; -'  
                    CALL    SET_TASK.ITF                    ; -.
                    DECLE   BLD_DRIP_INDEX, 0, TASK_BLD_DRIP;  |
                    CALL    SET_TASK.ITF                    ;  |_ Initialize the blood on the sword
                    DECLE   BLD_TOP_INDEX, 0, TASK_BLD_TOP  ;  |
                    CALL    SET_TASK.ITF                    ;  |
                    DECLE   BLD_BTM_INDEX, 0, TASK_BLD_BTM  ; -'
                    CALL    MAIN_LOOP                       ; Run the main code loop
                    ENDP
                    
; MAIN loop code
MAIN_LOOP           PROC
                    CALL    BLOCK_FOR_ISR                   ; At the start of the loop, sync up with the ISR.
                    CALL    HANDLE_CONTROLLERS              ; Handle the hand controllers, dispatch any keypad presses.
                    CALL    HANDLE_TASKS                    ; Handle any tasks that are ready to execute.
                    B       MAIN_LOOP                       ; Goto MAIN_LOOP, run this forever.
                    ENDP

; Initialize the display
DISPLAY_INIT        PROC
                    BEGIN
                    CALL    CLRSCR                          ; Clear the screen
                    MVII    #THE_JUDGED_CARDS, R1           ; -.
                    MVII    #$200 + 5*20 +2, R4             ;  |
                    MVII    #4, R0                          ;  |
                    CALL    MEMCPY.1                        ;  |
                    MOVR    R5, R1                          ;  |
                    MVII    #$200 + 6*20 +2, R4             ;  |
                    MVII    #4, R0                          ;  |
                    CALL    MEMCPY.1                        ;  |_ Display "The Judged"
                    MOVR    R5, R1                          ;  |
                    MVII    #$200 + 7*20 +2, R4             ;  |
                    MVII    #4, R0                          ;  |
                    CALL    MEMCPY.1                        ;  |
                    MOVR    R5, R1                          ;  |
                    MVII    #$200 + 8*20 +2, R4             ;  |
                    MVII    #4, R0                          ;  |
                    CALL    MEMCPY.1                        ; -'
                    CALL    PRINT.FLS                       ; -.
                    DECLE   X_GRY + $0F0*8                  ;  |_ Display the floor
                    DECLE   $200 + 9*20                     ;  |  
                    DECLE   "01010101010101010101", 0       ; -'
                    CALL    PRINT.FLS                       ; -.
                    DECLE   X_GRY + $0F0*8                  ;  |_ Display the floor
                    DECLE   $200 + 8*20 + 9                 ;  |  
                    DECLE   "10101010101", 0                ; -'
                    CALL    PRINT.FLS                       ; -.
                    DECLE   X_WHT                           ;  |    
                    DECLE   $200 + 10*20 + 0                ;  |
                    DECLE   " 1. Kiosk Tune      ", 0       ;  |_ Display the menu
                    CALL    PRINT.FLS                       ;  |
                    DECLE   X_WHT                           ;  |    
                    DECLE   $200 + 11*20 + 0                ;  |
                    DECLE   " 2. Hidden Sound FX ", 0       ; -'
                    MVII    #SPHINX_CARDS, R1               ; -.
                    MVII    #$200 + 0*20 +12, R4            ;  |
                    MVII    #8, R0                          ;  |
                    CALL    MEMCPY.1                        ;  |
                    MOVR    R5, R1                          ;  |
                    MVII    #$200 + 1*20 +12, R4            ;  |
                    MVII    #8, R0                          ;  |
                    CALL    MEMCPY.1                        ;  |
                    MOVR    R5, R1                          ;  |
                    MVII    #$200 + 2*20 +12, R4            ;  |
                    MVII    #8, R0                          ;  |
                    CALL    MEMCPY.1                        ;  |
                    MOVR    R5, R1                          ;  |
                    MVII    #$200 + 3*20 +12, R4            ;  |
                    MVII    #8, R0                          ;  |
                    CALL    MEMCPY.1                        ;  |_ Display Sphinx
                    MOVR    R5, R1                          ;  |
                    MVII    #$200 + 4*20 +12, R4            ;  |
                    MVII    #8, R0                          ;  |
                    CALL    MEMCPY.1                        ;  |
                    MOVR    R5, R1                          ;  |
                    MVII    #$200 + 5*20 +12, R4            ;  |
                    MVII    #8, R0                          ;  |
                    CALL    MEMCPY.1                        ;  |
                    MOVR    R5, R1                          ;  |
                    MVII    #$200 + 6*20 +12, R4            ;  |
                    MVII    #8, R0                          ;  |
                    CALL    MEMCPY.1                        ;  |
                    MOVR    R5, R1                          ;  |
                    MVII    #$200 + 7*20 +12, R4            ;  |
                    MVII    #8, R0                          ;  |
                    CALL    MEMCPY.1                        ; -'
                    RETURN
                    ENDP                 
                 
THE_JUDGED_CARDS:                                           ; Backtab card data to be copied for "The Judged"
                    DECLE   backtab_cs( 0, 0,  0, C_JDG ), backtab_cs( 0, 1,  2, C_JDG ), backtab_cs( 0, 1,  3, C_JDG ), backtab_cs( 0, 1,  4, C_JDG )
                    DECLE   backtab_cs( 0, 0,  0, C_JDG ), backtab_cs( 0, 1,  5, C_JDG ), backtab_cs( 0, 1,  6, C_JDG ), backtab_cs( 0, 1,  7, C_JDG )
                    DECLE   backtab_cs( 0, 0,  0, C_JDG ), backtab_cs( 0, 1,  8, C_JDG ), backtab_cs( 0, 1,  9, C_JDG ), backtab_cs( 0, 1, 10, C_JDG )
                    DECLE   backtab_cs( 0, 1, 11, C_JDG ), backtab_cs( 0, 1, 12, C_JDG ), backtab_cs( 0, 1, 13, C_JDG ), backtab_cs( 0, 1, 14, C_JDG )
                    
SPHINX_CARDS:                                               ; Backtab card data to be copied for the Sphinx
                    DECLE   backtab_cs( 0, 0,  0, X_BLK), backtab_cs( 0, 0,  0, X_BLK), backtab_cs( 0, 1, 15, C_SPH), backtab_cs( 0, 1, 16, C_SPH)
                    DECLE   backtab_cs( 0, 1, 17, C_SPH), backtab_cs( 0, 1, 18, C_SPH), backtab_cs( 0, 0,  0, X_BLK), backtab_cs( 0, 0,  0, X_BLK)
                    DECLE   backtab_cs( 0, 0,  0, X_BLK), backtab_cs( 0, 0,  0, X_BLK), backtab_cs( 0, 1, 19, C_SPH), backtab_cs( 0, 1, 20, C_SPH)
                    DECLE   backtab_cs( 0, 1, 21, C_SPH), backtab_cs( 0, 1, 22, C_SPH), backtab_cs( 0, 1, 23, C_SPH), backtab_cs( 0, 0,  0, X_BLK)
                    DECLE   backtab_cs( 0, 0,  0, X_BLK), backtab_cs( 0, 0,  0, X_BLK), backtab_cs( 0, 1, 24, C_SPH), backtab_cs( 0, 1, 25, C_SPH)
                    DECLE   backtab_cs( 0, 1, 26, C_SPH), backtab_cs( 0, 1, 27, C_SPH), backtab_cs( 0, 1, 28, C_SPH), backtab_cs( 0, 0,  0, X_BLK)
                    DECLE   backtab_cs( 0, 0,  0, X_BLK), backtab_cs( 0, 0,  0, X_BLK), backtab_cs( 0, 1, 29, C_SPH), backtab_cs( 0, 1, 30, C_SPH)
                    DECLE   backtab_cs( 0, 1, 31, C_SPH), backtab_cs( 0, 1, 32, C_SPH), backtab_cs( 0, 1, 33, C_SPH), backtab_cs( 0, 1, 34, C_SPH)
                    DECLE   backtab_cs( 0, 0,  0, X_BLK), backtab_cs( 0, 0,  0, X_BLK), backtab_cs( 0, 1, 35, C_SPH), backtab_cs( 0, 1, 36, C_SPH)
                    DECLE   backtab_cs( 0, 1, 37, C_SPH), backtab_cs( 0, 1, 38, C_SPH), backtab_cs( 0, 1, 39, C_SPH), backtab_cs( 0, 1, 40, C_SPH)
                    DECLE   backtab_cs( 0, 0,  0, X_BLK), backtab_cs( 0, 0,  0, X_BLK), backtab_cs( 0, 0,  0, X_BLK), backtab_cs( 0, 1, 41, C_SPH)
                    DECLE   backtab_cs( 0, 1, 42, C_SPH), backtab_cs( 0, 1, 43, C_SPH), backtab_cs( 0, 1, 51, C_SPH), backtab_cs( 0, 1, 51, C_SPH)
                    DECLE   backtab_cs( 0, 0,  0, X_BLK), backtab_cs( 0, 0,  0, X_BLK), backtab_cs( 0, 1, 44, C_SPH), backtab_cs( 0, 1, 45, C_SPH)
                    DECLE   backtab_cs( 0, 1, 51, C_SPH), backtab_cs( 0, 1, 46, C_SPH), backtab_cs( 0, 1, 51, C_SPH), backtab_cs( 0, 1, 51, C_SPH)
                    DECLE   backtab_cs( 0, 1, 47, C_SPH), backtab_cs( 0, 1, 48, C_SPH), backtab_cs( 0, 1, 51, C_SPH), backtab_cs( 0, 1, 51, C_SPH)
                    DECLE   backtab_cs( 0, 1, 49, C_SPH), backtab_cs( 0, 1, 50, C_SPH), backtab_cs( 0, 1, 51, C_SPH), backtab_cs( 0, 1, 51, C_SPH)

SPHINX_INDEX:       ; Table of Backtab locations where the Sphinx is located at, indexed by the random number 
                    DECLE               $20E, $20F, $210, $211
                    DECLE               $222, $223, $224, $225, $226
                    DECLE               $236, $237, $238, $239, $23A
                    DECLE               $24A, $24B, $24C, $24D, $24E, $24F
                    DECLE               $25E, $25F, $260, $261, $262, $263
                    DECLE                     $273, $274, $275, $276, $277
                    DECLE               $286, $287, $288, $289, $28A, $28B
                    DECLE   $298, $299, $29A, $29B, $29C, $29D, $29E, $29F                    
SPHINX_INDEX_SIZE   EQU     $ - SPHINX_INDEX
                    
; Handle the tasks.
; Each task has a timeout and a function address.  When the timeout reaches zero, the function is called.
; The function is called with the following parameters:
;   R3 = Task index
;   R5 = Return address
; A task is disabled if the function address is 0.
HANDLE_TASKS        PROC
                    BEGIN
                    CLRR    R3                              ; -._ Initialize R3, the task index, to -1.
                    COMR    R3                              ; -'
                    MVII    #TASK_TABLE, R4                 ; Initialize R4 as the task table entry pointer.
@@next_task         INCR    R3                              ; -.
                    CMPI    #MAX_TASKS, R3                  ;  |- Increment the task index, see if we're done.
                    BGE     @@exit                          ; -'
                    MOVR    R4, R2                          ; Have R2 point to this task's timer tick counter.
                    MVI@    R4, R1                          ; Read remaining time ticks for this task into R1.
                    MVI@    R4, R0                          ; -.
                    TSTR    R0                              ;  |- Read task's function into R0.
                    BEQ     @@next_task                     ; -'  If NULL, do nothing and goto the next task.
                    TSTR    R1                              ; -._ If no ticks remain, it is time to execute
                    BEQ     @@execute_task                  ; -'  the task.
                    DECR    R1                              ; -.
                    MVO@    R1, R2                          ;  |- Task not ready to execute.  Decrement its
                    B       @@next_task                     ; -'  timer ticks and goto the next task
@@execute_task      PSHR    R3                              ; -
                    PSHR    R4                              ;  |
                    MVII    #@@ret_addr, R5                 ;  |  Execute the current task.  Push and pop
                    MOVR    R0, R7                          ;  |- R3 and R4 since they are needed for the
@@ret_addr          PULR    R4                              ;  |  next task after we're done here.  When done...
                    PULR    R3                              ;  |  ... goto the next task.
                    B       @@next_task                     ; -'
@@exit              RETURN
                    ENDP
                    
; Copies a MOB's CARD data into the appropriate index into GRAM_MOBS_SHADOW
; Inputs:
;       SET_MOB_CARD.IC   After call is MOB index (0-7) and CARD address.
;       SET_MOB_CARD.C    After call is CARD address.  R3 contains MOB index
;       SET_MOB_CARD.R    R3 contains MOB index, R4 is CARD address
; Outputs:
;   R3      MOB index
;   R4      Address after CARD
;   R5      Return address
SET_MOB_CARD        PROC
@@IC                MVI@    R5, R3                          ; Load MOB index into R3
@@C                 MVI@    R5, R4                          ; Load card address into R4
@@R                 PSHR    R3                              ; Save MOB index
                    PSHR    R5                              ; Save return address
                    SLL     R3, 2                           ; -.
                    SLL     R3, 1                           ;  |_ Use MOB index to get address into GRAM_MOBS_SHADOW
                    ADDI    #GRAM_MOBS_SHADOW, R3           ;  |
                    MOVR    R3, R5                          ; -'
                    REPEAT  8                               ; -.
                    MVI@    R4, R3                          ;  |_ Copy the card
                    MVO@    R3, R5                          ;  |
                    ENDR                                    ; -'
                    PULR    R5                              ; Restore return address
                    PULR    R3                              ; Restore MOB index
                    MOVR    R5, R7                          ; Return
                    ENDP
      
; Sets a MOB's properties in the STIC_SHADOW
; Inputs:
;       SET_MOB_PROP.IXYA   After call is MOB's index (0-7), X reg, Y reg, and A reg.
;       SET_MOB_PROP.XYA    After call is MOB's X reg, Y reg, and A reg.  R3 is MOB's index (0-7).
;       SET_MOB_PROP.YA     After call is MOB's Y reg, and A reg.  R3 is MOB's index (0-7).  R0 is X reg.
;       SET_MOB_PROP.A      After call is MOB's A reg.  R3 is MOB's index (0-7).  R0-R1 is X reg and Y reg.
;       SET_MOB_PROP.R      R0 - R3 are MOB's X reg, Y reg, A reg, and the MOB's index (0-7)
; Outputs:
;   R0      MOB's X reg value
;   R1      MOB's Y reg value
;   R2      MOB's A reg value
;   R3      MOB's index (0-7)
SET_MOB_PROP        PROC
@@IXYA              MVI@    R5, R3                          ; Load MOB index into R3
@@XYA               MVI@    R5, R0                          ; Load X reg into R0
@@YA                MVI@    R5, R1                          ; Load Y reg into R1 
@@A                 MVI@    R5, R2                          ; Load A reg into R2
@@R                 PSHR    R3                              ; Save MOB index
                    ADDI    #STIC_SHADOW, R3                ; Use MOB index as offset into STIC_SHADOW
                    MVO@    R0, R3                          ; Store X reg
                    ADDI    #8, R3                          ; -._ Store Y reg
                    MVO@    R1, R3                          ; -'
                    ADDI    #8, R3                          ; -._ Store A reg
                    MVO@    R2, R3                          ; -'
                    PULR    R3                              ; Restore MOB index
                    MOVR    R5, R7                          ; Return
                    ENDP
                    
; Set a task (timeout and function)
; Inputs:
;       SET_TASK.ITF    After call is task index, timeout, function.
;       SET_TASK.TF     After call is timeout and function.  R3 is task index.
;       SET_TASK.F      After call is functions.  R3 is task index.  R0 timeout. 
;       SET_TASK.R      R3 is task index.  R0 is timeout.  R1 is function.
; Outputs:
;       R0  Timeout
;       R1  Function address
;       R3  Task index
SET_TASK            PROC
@@ITF               MVI@    R5, R3                          ; Load task index into R3
@@TF                MVI@    R5, R0                          ; Load timeout value into R0
@@F                 MVI@    R5, R1                          ; Load task's function into R1
@@R                 PSHR    R3                              ; Save MOB index
                    SLL     R3, 1                           ; -._ Compute address of task entry in TASK_TABLE
                    ADDI    #TASK_TABLE, R3                 ; -'  (hence the multiply task index by 2)
                    MVO@    R0, R3                          ; -.
                    INCR    R3                              ;  |- Store the timeout and function in the entry
                    MVO@    R1, R3                          ; -'
                    PULR    R3                              ; Restore MOB index
                    MOVR    R5, R7                          ; Done
                    ENDP
                    
; Process the hand controllers
HANDLE_CONTROLLERS  PROC
                    BEGIN
                    MVI     PSG0.io_port0, R0               ; -.
                    AND     PSG0.io_port1, R0               ;  |_ Read and merge both hand controllers,
                    COMR    R0                              ;  |  place values into R0.
                    ANDI    #$00FF, R0                      ; -'
                    MVI     HAND_DEBOUNCE_COUNT, R1         ; Read the debounce countdown
                    TSTR    R0                              ; -._ See if the controller is
                    BEQ     @@nothing_pressed               ; -'  not / no-longer pressed.
                    MVI     HAND_VALUE_PENDING, R2          ; -.
                    CMPR    R2, R0                          ;  |- Still pressed, see if the current value
                    BNEQ    @@new_value                     ; -'  is the same as last time checked.
                    DECR    R1                              ; -.
                    MVO     R1, HAND_DEBOUNCE_COUNT         ;  |- Still the same value, decrement the debounce
                    BNEQ    @@exit                          ; -'  count.  If count hasn't finished, then just exit.
                    MVO     R0, HAND_VALUE_LEGIT            ; -.  Debounce count finished.  Store the value as a
                    MVII    #HAND_DEBOUNCE_MAX, R1          ;  |_ "legitimate" button press, reset the debounce count
                    MVO     R1, HAND_DEBOUNCE_COUNT         ;  |  to be != 0 as a flag for when controller is released
                    B       @@exit                          ; -'  (non-zero means unprocessed event).  Lastly, exit.
@@new_value         MVO     R0, HAND_VALUE_PENDING          ; -.
                    MVII    #HAND_DEBOUNCE_MAX, R1          ;  |_ New value so update "pending", set the debounce count
                    MVO     R1, HAND_DEBOUNCE_COUNT         ;  |  to the max value, and exit.
                    B       @@exit                          ; -'
@@nothing_pressed   TSTR    R1                              ; -._ Nothing pressed and debounce count == 0 means
                    BEQ     @@exit                          ; -'  event already processed.
                    MVI     HAND_VALUE_LEGIT, R0            ; -.  See if a "legitimate" button press occurred (versus
                    TSTR    R0                              ;  |- just static).  If none, just exit.
                    BEQ     @@exit                          ; -'
                    CLRR    R1                              ; -._ Initialize walking the KEYPAD_DISPATCH table.
                    MVII    #KEYPAD_DISPATCH, R4            ; -'
@@next_entry        MVI@    R4, R2                          ; -.
                    CMPR    R2, R0                          ;  |_ Check if "legit" button press matches a keypad button,
                    MVI@    R4, R2                          ;  |  also load dispatch function into R2 in case it does.
                    BEQ     @@dispatch_call                 ; -'
                    INCR    R1                              ; -.
                    CMPI    #HAND_BUTTON_ENTER, R1          ;  |- No match, see if there are more table entries.
                    BLE     @@next_entry                    ; -' 
                    B       @@dispatch_return               ; No more entries.  Ignore the button press.
@@dispatch_call     MVII    #@@dispatch_return, R5          ; -._ Finally call the dispatch function with R1 and R5 params.
                    MOVR    R2, R7                          ; -'
@@dispatch_return   CLRR    R0                              ; -.
                    MVO     R0, HAND_VALUE_LEGIT            ;  |_ When dispatched or not, reset all the variables.
                    MVO     R0, HAND_VALUE_PENDING          ;  |
                    MVO     R0, HAND_DEBOUNCE_COUNT         ; -'
@@exit              RETURN
                    ENDP
                 
; Simple dispatch table for keypad buttons       
;   1st DECLE:      keypad code
;   2nd DECLE:      Function call with the following parameters
;                       R1  Keypad digit or HAND_BUTTON_CLEAR or HAND_BUTTON_ENTER
;                       R5  Return Address       
KEYPAD_DISPATCH:
                    DECLE   $48, DISPATCH_EASTER_EGG        ; 0 pressed
                    DECLE   $81, DISPATCH_TUNE              ; 1 pressed
                    DECLE   $41, DISPATCH_SFX               ; 2 pressed
                    DECLE   $21, DISPATCH_NOTHING           ; 3 pressed
                    DECLE   $82, DISPATCH_NOTHING           ; 4 pressed
                    DECLE   $42, DISPATCH_NOTHING           ; 5 pressed
                    DECLE   $22, DISPATCH_NOTHING           ; 6 pressed
                    DECLE   $84, DISPATCH_NOTHING           ; 7 pressed
                    DECLE   $44, DISPATCH_NOTHING           ; 8 pressed
                    DECLE   $24, DISPATCH_NOTHING           ; 9 pressed
                    DECLE   $88, DISPATCH_NOTHING           ; Clear pressed
                    DECLE   $28, DISPATCH_NOTHING           ; Enter pressed
                    
; Dispatch function that does nothing.
DISPATCH_NOTHING    PROC
                    MOVR    R5, R7                          ; Dispatch handler that does nothing, just returns
                    ENDP
            
; Dispatch function that plays the Kiosk's tune
DISPATCH_TUNE       PROC
                    BEGIN
                    JSR     R5, PLAY_KIOSK_TUNE             ; Display handler that calls PLAY_KIOSK_TUNE
                    RETURN
                    ENDP

; Play the tune built into the Kiosk Multiplexer
PLAY_KIOSK_TUNE     PROC
                    BEGIN
                    JSR     R5,     X_PLAY_MUS3             ; -.
                    DECLE   $0184                           ;  |                          Note (short)
                    DECLE   $01B4                           ;  |                          Note (short)
                    DECLE   $0204                           ;  |                          Note (short)
                    DECLE   $0240                           ;  |                          Note (short)
                    DECLE   $0008                           ;  |                          Note (short)
                    DECLE   $0280                           ;  |- Play some music         Note (short)
                    DECLE   $0008                           ;  |                          Note (short)
                    DECLE   $02B0                           ;  |                          Note (short)
                    DECLE   $01C0                           ;  |                          Note (short)
                    DECLE   $01F8                           ;  |                          Note (short)
                    DECLE   $0302                           ;  |                          Note (short)
                    DECLE   $0000                           ; -'                          End of music
                    RETURN
                    ENDP

; Dispatch function that plays the Kiosk's hidden sound effect                    
DISPATCH_SFX        PROC
                    BEGIN
                    JSR     R5, PLAY_KIOSK_SFX              ; Display handler that calls PLAY_KIOSK_SPX
                    RETURN
                    ENDP

; Play the Sound Effect from the Kiosk Multiplexer
PLAY_KIOSK_SFX      PROC
                    PSHR    R5                              ; Push return address to stack
                    JSR     R5,     X_PLAY_SFX1             ; -.
                    DECLE   $0389                           ;  |                          SFX data
                    DECLE   $0280,  $0200                   ;  |                          SFX data
                    DECLE   $0288,  $0180                   ;  |                          SFX data
                    DECLE   $0284,  $0080                   ;  |                          SFX data
                    DECLE   $0001,  $0300                   ;  |                          SFX data
                    DECLE   $0001,  $0382                   ;  |- Play a sound effect     SFX data
                    DECLE   $0001,  $0081                   ;  |                          SFX data
                    DECLE   $008E                           ;  |                          SFX data
                    DECLE   $00EB                           ;  |                          SFX data
                    DECLE   $0001,  $0003                   ;  |                          SFX data
                    DECLE   $03EE                           ;  |                          SFX data
                    DECLE   $008F,  $001F                   ;  |                          SFX data
                    DECLE   $02CF                           ; -'                          SFX end 
                    ENDP

; Dispatch for the Easter Egg, initializes variables and start a task in slot 8      
DISPATCH_EASTER_EGG PROC
                    BEGIN
                    CLRR    R0                              ; -._ Reset the state to 0
                    MVO     R0, EASTER_EGG_STATE            ; -'
                    MVII    #8, R3                          ; -.
                    CALL    SET_TASK.TF                     ;  |- Setup the task in slot 8
                    DECLE   0, TASK_EASTER_EGG              ; -'
                    RETURN
                    ENDP
                  
; Task code for the Easter Egg.  It just prints a string on the screen (from a table) and sets up the next TASK_TABLE.                  
TASK_EASTER_EGG     PROC
                    BEGIN
                    MVI     EASTER_EGG_STATE, R1            ; -.
                    MOVR    R1, R2                          ;  |_ Read state and multiply by 16
                    SLL     R1, 2                           ;  |  Keep copy in R2
                    SLL     R1, 2                           ; -'
                    INCR    R2                              ; -._ Increment the EASTER_EGG_STATE
                    MVO     R2, EASTER_EGG_STATE            ; -'
                    ADDI    #EASTER_EGG_TEXT, R1            ; -._ Calculate address of entry and store in R4
                    MOVR    R1, R4                          ; -'
                    CLRR    R1                              ; R1 = Function pointer (null for the moment)
                    MVI@    R4, R0                          ; R0 = Timeout
                    TSTR    R0                              ; -.
                    BEQ     @@set_null_task                 ;  |- If timeout != 0, then set R1 (function) to real address.
                    MVII    #TASK_EASTER_EGG, R1            ; -'
@@set_null_task     CALL    SET_TASK.R                      ; Set the next task (R3 still has task index)
                    MOVR    R4, R0                          ; -.  R0 = string
                    MVII    #X_WHT, R1                      ;  |_ R1 = format screen word
                    MVII    #$200 + 20, R4                  ;  |  R4 = screen position
                    CALL    PRINT.R                         ; -'  Print the string
                    RETURN
                    ENDP
                    
;  Timeout (post) and null-terminated Text (pre) to display (last 2 DECLES are padding).  A timeout of 0 means "done".
;  Each entry is 16 DECLEs long (easy multiplication).
EASTER_EGG_TEXT:    ;     Timeout   Message       nul,  pad ; -.
                    DECLE   180,    "Hi Intvnut! ", 0, 0, 0 ;  |
                    DECLE    30,    "            ", 0, 0, 0 ;  |- Messages and their timeouts
                    DECLE   180,    "Hello Decle!", 0, 0, 0 ;  |
                    DECLE     0,    "            ", 0, 0, 0 ; -'
       
; Initialize the sparkle task.
; Input:
;   R3      Address of the sparkle variables
INIT_SPARKLE_VAR    PROC
                    BEGIN
                    PSHR    R1                              ; -.
                    PSHR    R2                              ;  |
                    MVII    #SPARKLE_CARD_SEQ, R1           ;  |
                    MVII    #SPARKLE_STATE, R2              ;  |_ Initializes SPARKLE_STATE to 1st SPARKLE_CARD_SEQ element
                    ADDR    R3, R2                          ;  |
                    MVO@    R1, R2                          ;  |
                    PULR    R2                              ;  |
                    PULR    R1                              ; -'
                    RETURN
                    ENDP
                  
; Task code for animating a sparkle.  R3 contains the task/MOB index on input
TASK_SPARKLE        PROC
                    BEGIN
@@common_start      MVII    #SPARKLE_STATE, R4              ; -.
                    ADDR    R3, R4                          ;  |- Compute address of this particular sparkle's state.
                    MOVR    R4, R2                          ; -'  It points into SPARKLE_CARD_SEQ table.  Keep address in R2
                    MVI@    R4, R4                          ; Dereference the address to get the address in SPARKLE_CARD_SEQ table.
                    MVI@    R4, R1                          ; -._ Finally read the SPARKLE_CARD_SEQ entry
                    MVI@    R4, R0                          ; -'  R1 = next timeout, R0 = card address
                    CMPI    #SPARKLE_CARD_SEQ+2, R4         ; -._ See if we just read the 1st entry in the table?
                    BEQ     @@first_seq                     ; -'  If so, do the tricky stuff to find a fresh location for the sparkle.
@@check_seq_end     TSTR    R0                              ; -._ If the address to the card is valid, go display it.
                    BNEQ    @@display                       ; -'
                    CALL    INIT_SPARKLE_VAR                ; -._ Reached the end of the sequence.  Start the sequence over again.
                    B       @@common_start                  ; -'
@@display           PSHR    R1                              ; Push next timeout to the stack
                    MOVR    R0, R4                          ; -._ Update the sparkle's pixels (need to copy card address to R4)
                    CALL    SET_MOB_CARD.R                  ; -'
                    MVI@    R2, R1                          ; -.
                    ADDI    #2, R1                          ;  |- Increment the sparkle's state
                    MVO@    R1, R2                          ; -'
                    PULR    R0                              ; Pop R0 = next timeout
                    CALL    SET_TASK.F                      ; -._ Set the timeout and next task to be TASK_SPARKLE 
                    DECLE   TASK_SPARKLE                    ; -'
                    RETURN                                  ; Return, we're done
@@first_seq         PSHR    R0                              ; Save the card's addres
                    PSHR    R2                              ; Save the sparkle's state value
@@next_rand         MVII    #13, R0                         ; -.
                    CALL    RAND                            ;  |_ Randomly pick a location inside the Sphinx's active pixels
                    CMPI    #64*SPHINX_INDEX_SIZE, R0       ;  |
                    BGT     @@next_rand                     ; -'
                    MOVR    R0, R4                          ; -._ R4 contains the random coordinate within a card.
                    ANDI    #$3F, R4                        ; -'  It's a value that ranges from 0-63
                    MOVR    R0, R2                          ; -.
                    SLR     R2, 2                           ;  |_ R2 is the random index into SPHINX_INDEX
                    SLR     R2, 2                           ;  |
                    SLR     R2, 2                           ; -'
                    ADDI    #SPHINX_INDEX, R2               ; -._ Read the Backtab address in SPHINX_INDEX into R2
                    MVI@    R2, R2                          ; -'
                    CALL    CARD_TO_PIXEL                   ; X, Y coordinates of Backtab card's uppper left corner (in R0, R1)
                    CALL    ADD_PIXEL_OFFSET                ; Use R4 to find coordinates of the n'th pixel in the card
                    ADDI    #stic_x(0,1,0,0), R0            ; -._ Compute X and Y STIC registers
                    ADDI    #stic_y(0,0,1,0,0), R1          ; -'
                    MOVR    R3, R2                          ; -.
                    SLL     R2, 2                           ;  |_ Compute the A STIC register, needs to point to GRAM card 
                    SLL     R2, 1                           ;  |  at MOB index + 56
                    ADDI    #stic_a(0,1,56,X_WHT), R2       ; -'
                    CALL    SET_MOB_PROP.R                  ; - Set all 3 STIC registers in the STIC shadow
                    PULR    R2                              ; Restore the sparkle's state value
                    MVII    #9, R0                          ; -.
                    CALL    RAND                            ;  |- Set the amount of time to display the 1st sequence to a random number
                    MOVR    R0, R1                          ; -'
                    PULR    R0                              ; Restore the card's addres
                    B       @@display                       ; Done setting up the 1st element in animation sequence, go display it
                    ENDP               

; Given a Backtab address, computer the X and Y coordinates of the upper left corner
; Inputs:
;   R2  Backtab address
; Outputs:
;   R0  X coordinate of upper left corner
;   R1  Y coordinate of upper left corner
;   R2  Backtab address
CARD_TO_PIXEL:      PROC
                    BEGIN
                    PSHR    R2                              ; Store Backtab address
                    SUBI    #$200, R2                       ; Convert to card index into the Backtab
                    MVII    #-3, R1                         ; -.  Set Y = (card index ) / 20 * 8 + 5
@@count_y_cards     ADDI    #8, R1                          ;  |_ The "+ 5" is because the MOB coordinate 8,8 is the
                    SUBI    #20, R2                         ;  |  screen coordinate 0,0... but then need to subtract 3
                    BGE     @@count_y_cards                 ; -'  because of offset of the _center_ of the MOB.
                    ADDI    #20, R2                         ; -.
                    SLL     R2, 2                           ;  |  Set X = (card index ) % 20 * 8 + 5
                    SLL     R2, 1                           ;  |- The "+ 5" is for the same reason as above.
                    MVII    #5, R0                          ;  |
                    ADDR    R2, R0                          ; -'
                    PULR    R2                              ; Restore Backtab address
                    RETURN
                    ENDP
                    
; Add the pixel offset to the X, Y coordinate of card's upper left corner, based on the Backtab address
; The contents of the Backtab address is used so that offset lands on an active pixel within the card (offset can wrap around).
; Inputs:
;   R0  X coordinate of card's upper left corner
;   R1  Y coordinate of card's upper left corner
;   R2  Backtab address
;   R4  Pixel offset that can be 0-63
; Outputs:
;   R0  X coordinate of upper left corner + X offset
;   R1  Y coordinate of upper left corner
ADD_PIXEL_OFFSET:   PROC
                    BEGIN
                    PSHR    R0                              ; Store X coordinate of card's upper left corner
                    PSHR    R1                              ; Store Y coordinate of card's upper left corner
                    PSHR    R2                              ; Store Backtab address
                    PSHR    R3                              ; Store R3
                    PSHR    R4                              ; Store Pixel offset
                    MOVR    R4, R3                          ; -._ R3 = Pixel count up (when finally >0, we're done here)
                    NEGR    R3                              ; -'
                    MVI@    R2, R4                          ; -.
                    ANDI    #$07F8, R4                      ;  |- R4 = pointer to current row of pixels from the card
                    ADDI    #GRAM_CARDS, R4                 ; -'
                    CLRR    R0                              ; R0 = Computed pixel X coordindate offset
@@first_row         CLRR    R1                              ; R1 = Computed pixel Y coordindate offset (note: dupe of R0's bits 6-4)
@@next_row          MVI@    R4, R2                          ; -._ R2's high bytes = Card's actual pixels
                    SWAP    R2                              ; -'  R4 = pointer to next row of pixels
                    REPEAT  8                               ; -.
                    INCR    R0                              ;  |  Repeat for all 8 potential pixels:
                    SLLC    R2, 1                           ;  |_ If pixel is set, increment pixel count up.  If latter
                    ADCR    R3                              ;  |  is >0, we're done.
                    BGT     @@done                          ;  |  As we go along, keep incrementing the X coordinate.
                    ENDR                                    ; -'
                    INCR    R1                              ; -.
                    CMPI    #8, R1                          ;  |
                    BNE     @@next_row                      ;  |- Increment the Y coordinate and goto to get the next row of pixels.
                    SUBI    #8, R4                          ;  |  Before we do, though, if Y overflows 8, then have it reset to 0.
                    B       @@first_row                     ; -'
@@done              DECR    R0                              ; Decrement X since it went 1 too far.
                    PULR    R4                              ; Restore R4 (Pixel offset)
                    PULR    R3                              ; Restore R3
                    PULR    R2                              ; Restore Backtab address
                    ADD@    SP, R1                          ; Add Y coodindate of card's upper left corner to R1
                    ANDI    #$7, R0                         ; -._ Add X coodindate of card's upper left corner to R0.
                    ADD@    SP, R0                          ; -'
                    RETURN
                    ENDP
                    
SPARKLE_CARD_SEQ:   DECLE    0, SPARKLE_CARD_0              ; -.
                    DECLE    4, SPARKLE_CARD_1              ;  |
                    DECLE    4, SPARKLE_CARD_2              ;  |
                    DECLE    4, SPARKLE_CARD_3              ;  |
                    DECLE   10, SPARKLE_CARD_4              ;  |
                    DECLE    4, SPARKLE_CARD_5              ;  |  The sequence that the sparkle animation is played in
                    DECLE    4, SPARKLE_CARD_6              ;  |- First element is how many ticks to display it for,
                    DECLE    4, SPARKLE_CARD_7              ;  |  Second is the actual card data to display.
                    DECLE   10, SPARKLE_CARD_4              ;  |
                    DECLE    4, SPARKLE_CARD_3              ;  |
                    DECLE    4, SPARKLE_CARD_2              ;  |
                    DECLE    4, SPARKLE_CARD_1              ;  |
                    DECLE    4, SPARKLE_CARD_0              ; -'
                    DECLE    0, 0                           ; End of sequence marker

SPARKLE_CARD_0:     DECLE   %00000000                       ; -.
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |_ Sparkle card 0
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ; -'
SPARKLE_CARD_1:     DECLE   %00000000                       ; -.
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00010000                       ;  |_ Sparkle card 1
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ; -'
SPARKLE_CARD_2:     DECLE   %00000000                       ; -.
                    DECLE   %00000000                       ;  |
                    DECLE   %00010000                       ;  |
                    DECLE   %00111000                       ;  |_ Sparkle card 2
                    DECLE   %00010000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ; -'
SPARKLE_CARD_3:     DECLE   %00010000                       ; -.
                    DECLE   %00000000                       ;  |
                    DECLE   %00010000                       ;  |
                    DECLE   %10111010                       ;  |_ Sparkle card 3
                    DECLE   %00010000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00010000                       ;  |
                    DECLE   %00000000                       ; -'
SPARKLE_CARD_4:     DECLE   %00010000                       ; -.
                    DECLE   %00000000                       ;  |
                    DECLE   %00111000                       ;  |
                    DECLE   %10111010                       ;  |_ Sparkle card 4
                    DECLE   %00111000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00010000                       ;  |
                    DECLE   %00000000                       ; -'
SPARKLE_CARD_5:     DECLE   %00100000                       ; -.
                    DECLE   %00000000                       ;  |
                    DECLE   %00111010                       ;  |
                    DECLE   %00111000                       ;  |_ Sparkle card 5
                    DECLE   %10111000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00001000                       ;  |
                    DECLE   %00000000                       ; -'
SPARKLE_CARD_6:     DECLE   %00000000                       ; -.
                    DECLE   %01000100                       ;  |
                    DECLE   %00111000                       ;  |
                    DECLE   %00111000                       ;  |_ Sparkle card 6
                    DECLE   %00111000                       ;  |
                    DECLE   %01000100                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ; -'
SPARKLE_CARD_7:     DECLE   %00001000                       ; -.
                    DECLE   %00000000                       ;  |
                    DECLE   %10111000                       ;  |
                    DECLE   %00111000                       ;  |_ Sparkle card 7
                    DECLE   %00111010                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00100000                       ;  |
                    DECLE   %00000000                       ; -'
                    
; Task code setting up the top of the sword's blood.  R3 contains the task/MOB index on input (hardcoded to BLD_TOP_INDEX)
TASK_BLD_TOP        PROC
                    BEGIN
                    CALL    SET_MOB_CARD.IC                     ; -._ Copy blood to MOB's card
                    DECLE   BLD_TOP_INDEX, BLD_SWORD_TOP        ; -'
                    CALL    SET_MOB_PROP.IXYA                   ; -.
                    DECLE   BLD_TOP_INDEX                       ;  |
                    DECLE   stic_x(0,1,0,BLD_XP)                ;  |- Place the blood on the sword
                    DECLE   stic_y(0,0,1,0,BLD_YP)              ;  |
                    DECLE   stic_a(0,1,56+BLD_TOP_INDEX,C_BLD)  ; -'
                    CALL    SET_TASK.ITF                        ; -._ Task is done executing
                    DECLE   BLD_TOP_INDEX, 0, 0                 ; -'
                    RETURN
                    ENDP
                    
; Task code setting up the bottom of the sword's blood.  R3 contains the task/MOB index on input
TASK_BLD_BTM        PROC
                    BEGIN
                    CALL    SET_MOB_CARD.IC                     ; -._ Copy blood to MOB's card
                    DECLE   BLD_BTM_INDEX, BLD_SWORD_BTM        ; -'
                    CALL    SET_MOB_PROP.IXYA                   ; -.
                    DECLE   BLD_BTM_INDEX                       ;  |
                    DECLE   stic_x(0,1,0,BLD_XP)                ;  |- Place the blood on the sword
                    DECLE   stic_y(0,0,1,0,BLD_YP+8)            ;  |
                    DECLE   stic_a(0,1,56+BLD_BTM_INDEX,X_RED)  ; -'
                    CALL    SET_TASK.ITF                        ; -._ Task is done executing
                    DECLE   BLD_BTM_INDEX, 0, 0                 ; -'
                    RETURN
                    ENDP

BLD_SWORD_TOP:      DECLE   %00000000                       ; -.
                    DECLE   %00000000                       ;  |
                    DECLE   %01000000                       ;  |
                    DECLE   %01100000                       ;  |_ Top part of sword's blood
                    DECLE   %01110000                       ;  |
                    DECLE   %01111000                       ;  |
                    DECLE   %01111100                       ;  |
                    DECLE   %01111100                       ; -'
BLD_SWORD_BTM:      DECLE   %01111100                       ; -.
                    DECLE   %01111100                       ;  |
                    DECLE   %01111100                       ;  |
                    DECLE   %01111100                       ;  |_ Bottom part of sword's blood 
                    DECLE   %01111100                       ;  |
                    DECLE   %01111100                       ;  |
                    DECLE   %00111000                       ;  |
                    DECLE   %00010000                       ; -'
                    
; Task code animating blood on the sword.  R3 contains the task/MOB index on input
TASK_BLD_DRIP       PROC
                    BEGIN
                    MVI     BLD_STATE, R1                       ; Read the blood's state
                    MOVR    R1, R2                              ; -.
                    ADDI    #BLD_DRIP_TIMES, R2                 ;  |- Read appropriate timeout in BLD_DRIP_TIMES
                    MVI@    R2, R2                              ; -'
                    INCR    R1                                  ; -._ Write the incremented blood state
                    MVO     R1, BLD_STATE                       ; -'
                    CMPI    #$FFFF, R2                          ; -._ Is the timeout a "drip sequence done"?
                    BEQ     @@drip_seq_done                     ; -'
                    DECR    R1                                  ; Nope, so decrement R1 back to current state
                    BNE     @@do_drip                           ; Is the state not the 1st one?
                    CALL    SET_MOB_PROP.IXYA                   ; -.
                    DECLE   BLD_DRIP_INDEX                      ;  |
                    MVII    #stic_x(0,0,0,BLD_XP), R0           ;  |- It is the 1st one, so set the STIC properties
                    ADDI    #stic_y(0,0,1,0,BLD_YP+5), R1       ;  |
                    DECLE   stic_a(0,1,56+BLD_DRIP_INDEX,X_RED) ; -'
                    MVII    #8, R0                              ; -.
                    CALL    RAND                                ;  |_ The 1st one gets a random timeout
                    ADDI    #120, R0                            ;  |  of 2 to 6 seconds.  Go set the next task.
                    B       @@set_next_task                     ; -'
@@do_drip           CALL    SET_MOB_CARD.IC                     ; -._ Copy blood drip to MOB's card
                    DECLE   BLD_DRIP_INDEX, BLD_DRIP_CARD       ; -'
                    PSHR    R2                                  ; Save the timeout
                    MVII    #stic_x(0,1,0,BLD_XP), R0           ; -.
                    ADDI    #stic_y(0,0,1,0,BLD_YP+5), R1       ;  |_ Place the blood drop on the edge of sword,
                    CALL    SET_MOB_PROP.A                      ;  |  making sure to update the Y position.
                    DECLE   stic_a(0,1,56+BLD_DRIP_INDEX,X_RED) ; -'
                    PULR    R0                                  ; Restore the timeout                    
@@set_next_task     CALL    SET_TASK.F                          ; -._ Set the next task
                    DECLE   TASK_BLD_DRIP                       ; -'
                    RETURN                                      ; Done, return
@@drip_seq_done     CLRR    R1                                  ; -._ Sequence is done, reset the blood's state back to 0.
                    MVO     R1, BLD_STATE                       ; -'
                    CALL    SET_TASK.ITF                        ; -._ Switch the task to blood splash.
                    DECLE   BLD_DRIP_INDEX,0,TASK_BLD_SPLASH    ; -'
                    RETURN
                    ENDP

BLD_DRIP_TIMES:     DECLE   0,30,13,11,8,7,6,5,3,2,1,$FFFF  ; List of timeouts for each blood drop movement

BLD_DRIP_CARD:      DECLE   $0002,$0000,$0000,$0000         ; -._ Blood drop card
                    DECLE   $0000,$0000,$0000,$0000         ; -'

TASK_BLD_SPLASH:    PROC
                    BEGIN
                    MVI     BLD_STATE, R1                       ; Read the blood's state
                    MOVR    R1, R2                              ; -.
                    ADDI    #BLD_SPLASH_TIMES, R2               ;  |- Read appropriate timeout in BLD_SPLASH_TIMES
                    MVI@    R2, R2                              ; -'
                    INCR    R1                                  ; -._ Write the incremented blood state
                    MVO     R1, BLD_STATE                       ; -'
                    CMPI    #$FFFF, R2                          ; -._ Is the timeout a "splash sequence done"?
                    BEQ     @@splash_seq_done                   ; -'
                    DECR    R1                                  ; Nope, so decrement R1 back to current state
                    PSHR    R2                                  ; Save the timeout
                    MVII    #BLD_BTM_INDEX, R3                  ; -.
                    SLL     R1, 2                               ;  |
                    SLL     R1, 1                               ;  |_ Update the left side of splash (overlaps sword)
                    MOVR    R1,R4                               ;  |  No need to update STIC properties since MOB
                    ADDI    #BLD_SPLASH_LEFT, R4                ;  |  doesn't move.
                    CALL    SET_MOB_CARD.R                      ; -'
                    MVII    #BLD_DRIP_INDEX, R3                 ; -.
                    MOVR    R1,R4                               ;  |_ Update the right side of splash
                    ADDI    #BLD_SPLASH_RIGHT, R4               ;  |
                    CALL    SET_MOB_CARD.R                      ; -'
                    CALL    SET_MOB_PROP.XYA                    ; -.
                    DECLE   stic_x(0,1,0,BLD_XP+8)              ;  |- Place the splash in the right location on the screen
                    DECLE   stic_y(0,0,1,0,BLD_YP+8)            ;  |
                    DECLE   stic_a(0,1,56+BLD_DRIP_INDEX,X_RED) ; -'                                        
                    PULR    R0                                  ; Restore the timeout
@@set_next_task     CALL    SET_TASK.F                          ; -._ Set the next task and its timeout
                    DECLE   TASK_BLD_SPLASH                     ; -'
                    RETURN                                      ; Return, done
@@splash_seq_done   CLRR    R1                                  ; -._ Sequence is done, reset the blood's state back to 0.
                    MVO     R1, BLD_STATE                       ; -'
                    CALL    SET_TASK.ITF                        ; -._ Switch the task to blood drip.
                    DECLE   BLD_DRIP_INDEX,0,TASK_BLD_DRIP      ; -'
                    CALL    SET_MOB_CARD.IC                     ; -._ Copy normal bloody sword to MOB's card
                    DECLE   BLD_BTM_INDEX, BLD_SWORD_BTM        ; -'
                    RETURN
                    ENDP

BLD_SPLASH_TIMES:   DECLE   4,4,5,7,7,5,4,4,$FFFF           ; List of timeouts for each blood splash movement

BLD_SPLASH_LEFT:    DECLE   %01111100                       ; -.
                    DECLE   %01111100                       ;  |
                    DECLE   %01111100                       ;  |
                    DECLE   %01111100                       ;  |_ Splash card 0 (left side)
                    DECLE   %01111100                       ;  |
                    DECLE   %01111100                       ;  |
                    DECLE   %00111010                       ;  |
                    DECLE   %00010000                       ; -'
                    DECLE   %01111100                       ; -.
                    DECLE   %01111100                       ;  |
                    DECLE   %01111100                       ;  |
                    DECLE   %01111100                       ;  |_ Splash card 1 (left side) 
                    DECLE   %01111100                       ;  |
                    DECLE   %01111001                       ;  |
                    DECLE   %00111000                       ;  |
                    DECLE   %00010000                       ; -'
                    DECLE   %01111100                       ; -.
                    DECLE   %01111100                       ;  |
                    DECLE   %01111100                       ;  |
                    DECLE   %01111100                       ;  |_ Splash card 2 (left side)
                    DECLE   %01110100                       ;  |
                    DECLE   %01110100                       ;  |
                    DECLE   %00110000                       ;  |
                    DECLE   %00010000                       ; -'
                    DECLE   %01111100                       ; -.
                    DECLE   %01111100                       ;  |
                    DECLE   %01111100                       ;  |
                    DECLE   %01111100                       ;  |_ Splash card 3 (left side)
                    DECLE   %01101100                       ;  |
                    DECLE   %01101100                       ;  |
                    DECLE   %00111000                       ;  |
                    DECLE   %00011000                       ; -'
                    DECLE   %01111100                       ; -.
                    DECLE   %01111100                       ;  |
                    DECLE   %01111100                       ;  |
                    DECLE   %01111100                       ;  |_ Splash card 4 (left side)
                    DECLE   %01011100                       ;  |
                    DECLE   %01111100                       ;  |
                    DECLE   %00011000                       ;  |
                    DECLE   %00010000                       ; -'
                    DECLE   %01111100                       ; -.
                    DECLE   %01111100                       ;  |
                    DECLE   %01111100                       ;  |
                    DECLE   %01111100                       ;  |_ Splash card 5 (left side)
                    DECLE   %01111100                       ;  |
                    DECLE   %00111100                       ;  |
                    DECLE   %00111000                       ;  |
                    DECLE   %00110000                       ; -'
                    DECLE   %01111100                       ; -.
                    DECLE   %01111100                       ;  |
                    DECLE   %01111100                       ;  |
                    DECLE   %01111100                       ;  |_ Splash card 6 (left side)
                    DECLE   %01111100                       ;  |
                    DECLE   %01111100                       ;  |
                    DECLE   %10111000                       ;  |
                    DECLE   %00010000                       ; -'
                    DECLE   %01111100                       ; -.
                    DECLE   %01111100                       ;  |
                    DECLE   %01111100                       ;  |
                    DECLE   %01111100                       ;  |_ Splash card 7 (left side)
                    DECLE   %01111100                       ;  |
                    DECLE   %01111100                       ;  |
                    DECLE   %00111000                       ;  |
                    DECLE   %10010000                       ; -'
                    
BLD_SPLASH_RIGHT:   DECLE   %00000000                       ; -.
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |_ Splash card 0 (right side)
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ; -'
                    DECLE   %00000000                       ; -.
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |_ Splash card 1 (right side)
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ; -'
                    DECLE   %00000000                       ; -.
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |_ Splash card 2 (right side)
                    DECLE   %10000000                       ;  |
                    DECLE   %10000000                       ;  |
                    DECLE   %10000000                       ;  |
                    DECLE   %00000000                       ; -'
                    DECLE   %00000000                       ; -.
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |_ Splash card 3 (right side)
                    DECLE   %01000000                       ;  |
                    DECLE   %01000000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %10000000                       ; -'
                    DECLE   %00000000                       ; -.
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |_ Splash card 4 (right side)
                    DECLE   %00100000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00100000                       ;  |
                    DECLE   %00000000                       ; -'
                    DECLE   %00000000                       ; -.
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |_ Splash card 5 (right side)
                    DECLE   %00000000                       ;  |
                    DECLE   %00010000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00100000                       ; -'
                    DECLE   %00000000                       ; -.
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |_ Splash card 6 (right side)
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00001000                       ;  |
                    DECLE   %00000000                       ; -'
                    DECLE   %00000000                       ; -.
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |_ Splash card 7 (right side)
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00000000                       ;  |
                    DECLE   %00001000                       ; -'
                    
GRAM_INIT:          DECLE   $0038                           ; Number of GRAM cards to init (56)
                    DECLE   $0001,  $0380                   ; #00-07:  CART #00-07 ----
                    DECLE   $0011,  $0380                   ; #08-0F:  CART #08-0F ----
                    DECLE   $0021,  $0380                   ; #10-17:  CART #10-17 ----
                    DECLE   $0031,  $0380                   ; #18-1F:  CART #18-1F ----
                    DECLE   $0041,  $0380                   ; #20-27:  CART #20-27 ----
                    DECLE   $0051,  $0380                   ; #28-2F:  CART #28-2F ----
                    DECLE   $0061,  $0180                   ; #30-33:  CART #30-33 ----

GRAM_CARDS:         DECLE   %11110111                       ; -.
                    DECLE   %11110111                       ;  |
                    DECLE   %11110111                       ;  |
                    DECLE   %00000000                       ;  |_ Bricks part 1
                    DECLE   %11111111                       ;  |
                    DECLE   %11111111                       ;  |
                    DECLE   %11111111                       ;  |
                    DECLE   %00000000                       ; -'
                    DECLE   %11111111                       ; -.
                    DECLE   %11111111                       ;  |
                    DECLE   %11111111                       ;  |
                    DECLE   %00000000                       ;  |_ Bricks part 2
                    DECLE   %11110111                       ;  |
                    DECLE   %11110111                       ;  |
                    DECLE   %11110111                       ;  |
                    DECLE   %00000000                       ; -'

                    ; The judged.  Comment after each line is the coordinate in a 4x4 grid
                    ; These are placed in GRAM from card 2 thru 14 ($0E)                    X,Y
                    DECLE $0000, $0000, $0000, $0000, $0001, $0002, $0004, $0008        ;   1,0
                    DECLE $0000, $000C, $0012, $0022, $00C1, $0001, $0000, $0080        ;   2,0
                    DECLE $0000, $0000, $0000, $0000, $0000, $0000, $009C, $009C        ;   3,0
                    DECLE $0009, $0010, $0012, $0020, $0024, $0020, $0020, $0020        ;   1,1
                    DECLE $0007, $0018, $0020, $001F, $0020, $0000, $0027, $0008        ;   2,1
                    DECLE $0008, $003C, $00CC, $001C, $0028, $00FF, $0022, $0022        ;   3,1
                    DECLE $0014, $0021, $0040, $0040, $0040, $0044, $0040, $0044        ;   1,2
                    DECLE $0010, $0020, $0060, $0020, $0010, $0008, $0084, $0042        ;   2,2
                    DECLE $0022, $0022, $0022, $0022, $0022, $0022, $0022, $0022        ;   3,2
                    DECLE $0000, $0000, $0078, $0047, $0041, $009D, $00A2, $00E7        ;   0,3
                    DECLE $0040, $0088, $0080, $0010, $0000, $0020, $0001, $00FE        ;   1,3
                    DECLE $0002, $0042, $0004, $001C, $0024, $00D3, $0010, $001F        ;   2,3
                    DECLE $0000, $0000, $0000, $0000, $0000, $0000, $0080, $0080        ;   3,3
                                                                                        
                    ; The Sphinx.  Comment after each line is the coordinate in a 8x8 grid
                    ; These are placed in GRAM from card 15 thru 51 ($33)                   X,Y
                    DECLE $0000, $0000, $0000, $000C, $0016, $001F, $000E, $0006        ;   2,0
                    DECLE $0000, $0007, $001F, $007C, $00F1, $0067, $00CC, $0093        ;   3,0
                    DECLE $0070, $00FE, $009F, $0003, $00F8, $000E, $0063, $00F8        ;   4,0
                    DECLE $0000, $0000, $0080, $00E0, $00F0, $0038, $009C, $00CE        ;   5,0
                    DECLE $0005, $0003, $0003, $0003, $0001, $0000, $0000, $0000        ;   2,1
                    DECLE $00A7, $00AE, $000C, $0059, $0080, $00FF, $00FF, $00FF        ;   3,1
                    DECLE $001E, $0043, $00F9, $001C, $002F, $00A1, $00DC, $00EE        ;   4,1
                    DECLE $0067, $0033, $00C9, $006E, $0033, $0099, $00E6, $0073        ;   5,1
                    DECLE $0000, $0000, $0080, $0080, $0040, $00C0, $0060, $00A0        ;   6,1
                    DECLE $0001, $0003, $0006, $000E, $000F, $0003, $0007, $0007        ;   2,2
                    DECLE $007E, $001F, $0007, $007F, $00FF, $00FF, $00FF, $00FF        ;   3,2
                    DECLE $00EF, $0061, $00A0, $00AE, $00AF, $0063, $00E1, $00EC        ;   4,2
                    DECLE $0018, $00CE, $00E3, $0079, $001C, $00C6, $00F3, $0039        ;   5,2
                    DECLE $00D0, $0070, $0038, $00D8, $00E8, $0034, $009C, $00CC        ;   6,2
                    DECLE $0005, $0007, $0003, $0003, $0003, $0001, $0000, $0000        ;   2,3
                    DECLE $00FF, $00FF, $00FF, $00FF, $00FF, $00FF, $0042, $00FD        ;   3,3
                    DECLE $00EF, $00E1, $00E0, $00EF, $00CF, $0020, $00EF, $00E0        ;   4,3
                    DECLE $008E, $00E3, $007C, $0086, $00F3, $007C, $0083, $007C        ;   5,3
                    DECLE $0076, $009B, $00E7, $0079, $0007, $007B, $009C, $0027        ;   6,3
                    DECLE $0000, $0000, $0000, $0000, $0000, $0080, $0080, $0040        ;   7,3
                    DECLE $0000, $0000, $0001, $0001, $0001, $0001, $0001, $0000        ;   2,4
                    DECLE $00FD, $00FD, $00FD, $00FF, $00FB, $00F7, $00E4, $000F        ;   3,4
                    DECLE $00EF, $00C3, $00FD, $0086, $00F3, $001F, $00EC, $003B        ;   4,4
                    DECLE $0093, $00CF, $003F, $00FF, $00FF, $00FF, $00FF, $003F        ;   5,4
                    DECLE $00F9, $00FE, $00FF, $00FF, $00FF, $00FF, $00FF, $00FF        ;   6,4
                    DECLE $00C0, $0020, $00D0, $00FC, $00FF, $00FF, $00FF, $00FF        ;   7,4
                    DECLE $0011, $003E, $0023, $003C, $0023, $003D, $0027, $0019        ;   3,5
                    DECLE $00FF, $007F, $00FF, $00FF, $00FF, $00FF, $00FF, $00FF        ;   4,5
                    DECLE $00DF, $00EF, $00EF, $00FF, $00EF, $00EF, $00FF, $00F7        ;   5,5
                    DECLE $0000, $0000, $0000, $0000, $0000, $0000, $0003, $003F        ;   2,6
                    DECLE $001F, $0013, $001F, $001F, $001F, $0037, $00FD, $00FE        ;   3,6
                    DECLE $00F7, $00FF, $00F7, $00F7, $00FF, $00F7, $00F7, $00FF        ;   5,6
                    DECLE $0001, $0003, $000F, $001F, $003B, $0037, $0037, $001B        ;   0,7
                    DECLE $0087, $00CF, $00FF, $00FF, $00FF, $00FF, $00FF, $00FF        ;   1,7
                    DECLE $007F, $00FF, $00FF, $00FF, $00FF, $00FF, $00FF, $00FF        ;   4,7
                    DECLE $00F7, $00F7, $00FF, $00F7, $00FF, $00EF, $00DF, $00BF        ;   5,7
                    DECLE $00FF, $00FF, $00FF, $00FF, $00FF, $00FF, $00FF, $00FF        ;   6,5  7,5  4,6  6,6  7,6  2,7  3,7  6,7 and 7,7

;; ======================================================================== ;;
;;  LIBRARY INCLUDES                                                        ;;
;; ======================================================================== ;;
                    INCLUDE "gimini.asm"                    ; Color and registers
                    INCLUDE "print.asm"                     ; PRINT.xxx routines
                    INCLUDE "fillmem.asm"                   ; CLRSCR/FILLZERO/FILLMEM
                    INCLUDE "memcpy.asm"                    ; MEMCPY
                    INCLUDE "rand.asm"                      ; RAND
