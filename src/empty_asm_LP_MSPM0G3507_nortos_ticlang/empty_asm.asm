    .syntax unified
    .thumb
    .section .text
    .align 2
    .global main
    .global SysTick_Handler
    .global HardFault_Handler

/* ========================================================================= */
/* REGISTER DEFINITIONS                                                      */
/* ========================================================================= */
/* ---------------- SysTick registers (Cortex-M0+) ---------------- */
.equ SYST_CSR, 0xE000E010
.equ SYST_RVR, 0xE000E014
.equ SYST_CVR, 0xE000E018

.equ SYST_ENABLE,    (1 << 0)
.equ SYST_TICKINT,   (1 << 1)
.equ SYST_CLKSOURCE, (1 << 2)   /* processor clock */
/* GPIOB Base: 0x400A2000 */
.equ GPIOB_PWREN,   0x400A2800  /* Power Enable */
.equ GPIOB_DOE,     0x400A32C0  /* Direction */
.equ GPIOB_DOUTTGL, 0x400A32B0  /* Toggle */
.equ PWREN_KEY,     0x26000001  /* Key to unlock Power */

/* Pins */
.equ PIN_22,        (1 << 22)
.equ PIN_26,        (1 << 26)
.equ PIN_27,        (1 << 27)
.equ ALL_PINS,      (PIN_22 | PIN_26 | PIN_27)

/* SysTick */
.equ SCS_BASE,      0xE000E000
.equ SYST_CSR,      0xE000E010
.equ SYST_RVR,      0xE000E014
.equ SYST_CVR,      0xE000E018
.equ SYSTICK_CFG,   0x00000007  
.equ SYSTICK_LOAD,  0x000F4240  /* ~1M cycles (Default Clock 32MHz = ~30ms) */
.equ SYSTICK_RELOAD, 31999 
/* ========================================================================= */
/* DATA SECTION                                                              */
/* ========================================================================= */
    .data
    .align 8    /* CRITICAL: Ensure Data starts on 8-byte boundary */

/* Task Control Blocks */
TCB1:   .space 4
        .word  TCB2
TCB2:   .space 4
        .word  TCB3
TCB3:   .space 4
        .word  TCB1

CurrentTCB: .word TCB1

/* CRITICAL: Stacks must be 8-byte aligned to prevent Hard Faults */
    .align 8
Stack1_End: .space 512
Stack1_Top:

    .align 8
Stack2_End: .space 512
Stack2_Top:

    .align 8
Stack3_End: .space 512
Stack3_Top:

/* ========================================================================= */
/* MAIN                                                                      */
/* ========================================================================= */
    .text
    .type main, %function
main:
    /* Init from SysConfig */
    bl      SYSCFG_DL_init

    /* SysTick setup */
    ldr     r0, =SYST_RVR
    ldr     r1, =SYSTICK_RELOAD
    str     r1, [r0]

    ldr     r0, =SYST_CVR
    movs    r1, #0
    str     r1, [r0]              /* clear current */

    ldr     r0, =SYST_CSR
    ldr     r1, =(SYST_ENABLE | SYST_TICKINT | SYST_CLKSOURCE)
    str     r1, [r0]

    cpsie   i                      /* enable IRQs */

    /* 3. Initialize Task Stacks */
    
    /* Task 1 */
    ldr     r0, =Stack1_Top     /* Stack Top */
    ldr     r1, =Task1          /* PC (Entry Point) */
    bl      Init_Stack          /* Helper to build stack frame */
    ldr     r2, =TCB1
    str     r0, [r2]            /* Save SP to TCB */

    /* Task 2 */
    ldr     r0, =Stack2_Top
    ldr     r1, =Task2
    bl      Init_Stack
    ldr     r2, =TCB2
    str     r0, [r2]

    /* Task 3 */
    ldr     r0, =Stack3_Top
    ldr     r1, =Task3
    bl      Init_Stack
    ldr     r2, =TCB3
    str     r0, [r2]

    /* 4. Configure SysTick */
    ldr     r0, =SYST_RVR
    ldr     r1, =SYSTICK_LOAD
    str     r1, [r0]
    ldr     r0, =SYST_CVR
    movs    r1, #0
    str     r1, [r0]
    ldr     r0, =SYST_CSR
    ldr     r1, =SYSTICK_CFG
    str     r1, [r0]

    /* 5. Start First Task Manually */
    ldr     r0, =CurrentTCB
    ldr     r1, [r0]            /* Get Address of TCB1 */
    ldr     r2, [r1]            /* Get SP from TCB1 */

    msr     psp, r2
    movs    r0, #2
    msr     control, r0
    isb
    cpsie   i

    b       Task1

/* ========================================================================= */
/* HELPERS                                                                   */
/* ========================================================================= */
Init_Stack:
    /* Input: R0 = Stack Top, R1 = Task Function Address */
    mov     r2, r0 

    /* Build Hardware Stack Frame (8 words: xPSR, PC, LR, R12, R3-R0) */
    subs    r2, #32
    
    /* xPSR: Set Thumb bit (Bit 24) */
    movs    r3, #1
    lsls    r3, r3, #24
    str     r3, [r2, #28]
    
    /* PC: CRITICAL FIX - Ensure Bit 0 is 1 (Thumb Mode) */
    movs    r3, #1
    orrs    r1, r3          /* Force bit 0 to 1 */
    str     r1, [r2, #24]   /* Store corrected PC */

    /* LR: Error handler if task returns */
    ldr     r3, =Task_Return
    str     r3, [r2, #20]
    
    /* Build Software Stack Frame (8 words: R11-R4) */
    subs    r2, #32
    
    mov     r0, r2          /* Return new SP */
    bx      lr

Task_Return:
    b       Task_Return

/* ========================================================================= */
/* TASKS                                                                     */
/* ========================================================================= */
Task1:
    ldr     r0, =GPIOB_DOUTTGL
    ldr     r1, =PIN_22
t1_loop:
    str     r1, [r0]
    ldr     r2, =0x00001FFF    /* Short Delay */
    bl      Delay
    b       t1_loop

Task2:
    ldr     r0, =GPIOB_DOUTTGL
    ldr     r1, =PIN_26
t2_loop:
    str     r1, [r0]
    ldr     r2, =0x000FFFFF     /* Medium Delay */
    bl      Delay
    b       t2_loop

Task3:
    ldr     r0, =GPIOB_DOUTTGL
    ldr     r1, =PIN_27
t3_loop:
    str     r1, [r0]
    ldr     r2, =0x01FFFFFF    /* Long Delay */
    bl      Delay
    b       t3_loop

Delay:
    subs    r2, #1
    bne     Delay
    bx      lr

/* ========================================================================= */
/* HANDLERS                                                                  */
/* ========================================================================= */
    .type SysTick_Handler, %function
SysTick_Handler:
    /* r0 = PSP points to hardware frame pushed by CPU */
    mrs     r0, psp

    /* ---- Save r4-r7 ---- */
    subs    r0, r0, #16
    str     r4, [r0, #0]
    str     r5, [r0, #4]
    str     r6, [r0, #8]
    str     r7, [r0, #12]

    /* ---- Save r8-r11 (via temp r4-r7) ---- */
    mov     r4, r8
    mov     r5, r9
    mov     r6, r10
    mov     r7, r11
    subs    r0, r0, #16
    str     r4, [r0, #0]
    str     r5, [r0, #4]
    str     r6, [r0, #8]
    str     r7, [r0, #12]
    /* r0 now points to start of saved SW context (r8-r11 block) */

    /* ---- Save PSP into current TCB ---- */
    ldr     r1, =CurrentTCB
    ldr     r2, [r1]            /* r2 = Current TCB ptr */
    str     r0, [r2]            /* TCB->sp = r0 */

    /* ---- Switch to next TCB ---- */
    ldr     r2, [r2, #4]        /* r2 = TCB->next */
    str     r2, [r1]            /* CurrentTCB = next */

    /* ---- Restore PSP from new TCB ---- */
    ldr     r0, [r2]            /* r0 = next task saved SP */

    /* ---- Restore r8-r11 first ---- */
    ldr     r4, [r0, #0]
    ldr     r5, [r0, #4]
    ldr     r6, [r0, #8]
    ldr     r7, [r0, #12]
    mov     r8,  r4
    mov     r9,  r5
    mov     r10, r6
    mov     r11, r7
    adds    r0, r0, #16

    /* ---- Restore r4-r7 ---- */
    ldr     r4, [r0, #0]
    ldr     r5, [r0, #4]
    ldr     r6, [r0, #8]
    ldr     r7, [r0, #12]
    adds    r0, r0, #16

    /* r0 now points back to the hardware frame */
    msr     psp, r0
    bx      lr

/* HardFault Handler - If you get stuck here, check stack alignment! */
    .type HardFault_Handler, %function
HardFault_Handler:
    b       HardFault_Handler