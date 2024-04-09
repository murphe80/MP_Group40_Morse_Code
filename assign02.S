#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified                                               
.cpu    cortex-m0plus                                     
.thumb                                                      
.global main_asm                                             
.align 4                                                      

.equ    GPIO_BTN_INPT, 21              @ Specify pin for the input
.equ    ALRM_ISR_OFFSET, 0x40          @ Vector table 16 for ALARM Interrupt
.equ    GPIO_ISR_OFFSET, 0x74          @ Vector table 29 for GPIO Interrupt
.equ    GPIO_BTN_DN_MSK, 0x00400000    @ Detecting falling-edge event on GP21
.equ    GPIO_BTN_UP_MSK, 0x00800000    @ Detecting rising-edge event on GP21
.equ    DFLT_ALARM_TIME, 3000000        @ 3 second timeout 
.equ    DFLT_STATE, 0                   @alarm not run 

@ Entry point to the ASM portion of the program
main_asm:                                                           
    push     {lr}                                                   
    bl       initialise_button                                         @ Intialise pins
    bl       initialise_gpio                                       @ Install gpio
    bl       initialise_alrm                                       @ Install alarm

    ldr      r0, =instruction_m                                     @ Stores instruction message
    bl       printf                                                 @ And print using printf
    ldr      r0, =input_message                         
    bl       printf                     

    wfi                                                             

main_loop:                         
    bl      enable_alarm                                            
    wfi					                                            
    ldr     r2, =alarm_timer                                        
    ldr     r1, [r2]                                                
    movs    r0, #1                                                  
    cmp     r0, r1                                                  
    bne     main_loop                       @loop if timer not up (infinite loop)                                                
    movs    r0, #0                                                  
    str     r0, [r2]                                                
    movs    r0, #3                                                  
    movs    r1, #0                                                  
    bl      add_input                       @ add_input function in C             
    pop     {pc}                                                    

@ Enable alarm timer interrupts and set alarm
enable_alarm:
    ldr     r2,=TIMER_BASE                                         
    movs    r1, #1                                                  @ set the alarm
    str     r1, [r2, #TIMER_INTE_OFFSET]                            @ Enable the timer interrupt
    ldr     r1, [r2, #TIMER_TIMELR_OFFSET]                         
    ldr     r3, =current_alarm_time                                 @ Get address
    ldr     r0, [r3]                                                @ Get flashing interval
    add     r1, r0                                                  @ Change interval value
    str     r1, [r2, #TIMER_ALARM0_OFFSET]                          @ Set  alarm
    bx      lr                                                      

@ Sets up the alarm_isr in the RAM vector table and enables the correct interrupt
initialise_alrm:
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)                    @ Get the address of the vector table (PPB_BASE + M0PLUS_VTOR_OFFSET) register
    ldr     r1, [r2]                                                
    movs    r3, #ALRM_ISR_OFFSET                                    @ Load correct offset for ALARM0 in the vector table
    add     r3, r1                                                  @ Add the offset to the value in r1. r2 now contains the address of the ALARM ISR
    ldr     r0, =alrm_isr                                           @ Load r0 with the address of the alarm_isr handler
    str     r0, [r3]                                                @ Store the value in r0 at the address of r2 in memory, this activates the SVC ISR
    movs    r0, #1                                                  
    ldr     r1, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)               
    str     r0, [r1]                                                @ Disable the alarm0  irq by writing to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    ldr     r1, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)               
    str     r0, [r1]                                                @ Enable the ALARM0 IRQ
    bx      lr                                              

@ Initialise gpio button on input
initialise_button:
    push    {lr}                       
    movs    r0, #GPIO_BTN_INPT         
    bl      asm_gpio_init              
    movs    r0, #GPIO_BTN_INPT         
    bl      asm_gpio_set_irq           
    pop     {pc}         

@ Sets up the gpio_isr in the RAM vector table and enables the correct interrupt
initialise_gpio:
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)                    @ Get the address of the RAM vector table using the (PPB_BASE + M0PLUS_VTOR_OFFSET) register
    ldr     r1, [r2]                                                
    movs    r2, #GPIO_ISR_OFFSET                                    
    add     r2, r1                                                  
    ldr     r0, =gpio_isr                                           
    str     r0, [r2]                                                @ Store the address of the gpio_isr handler to the correct offset for GPIO in the vector table
    ldr     r0, =8192                                               @ Select bit out of 32 interrupt signals
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)               
    str     r0, [r2]                                                @ Disable the GPIO IRQ
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)               
    str     r0, [r2]                                                @ Disable the GPIO IRQ
    bx      lr                                                      @ Exit subroutine
                      

@ Service interrupt from the ALARM0 TIMER
.thumb_func                     
alrm_isr:
    push    {lr}                                                   @ Store the link register to the stack as we will call nested subroutines
    ldr     r2, =TIMER_BASE                                        @ GetTimer_Base register address
    movs    r1, #1                                                 @ Set alarm
    str     r1, [r2, #TIMER_INTR_OFFSET]                           @ Reset alarm 
    ldr     r2, =alarm_timer                                            
    movs    r0, #1                                                 @ Write 1 
    str     r0, [r2]                                               @ Store 1 in alarm_timer
    pop     {pc}                          

@ Service the pending GPIO interrupt
.thumb_func                                                     
gpio_isr:
    push    {lr}                                                   
    bl      watchdog_update                                        
    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)     
    ldr     r1, [r2]                                               
    ldr     r0, =GPIO_BTN_UP_MSK                                @ Mask (rising edge)
    cmp     r0, r1                                                 @ Checks rising edge the registers
    beq     risingEdge                                            
    ldr     r0, =GPIO_BTN_DN_MSK                               @ Mask (falling edge)
    cmp     r0, r1                                                
    beq     fallingEdge                                            

gpio_isr_done:
    bl      timer_begin                                            @ time to next interrupt
    pop     {pc}                                                   

risingEdge:						                                   
    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)           
    ldr     r1, =GPIO_BTN_UP_MSK                                
    str     r1, [r2]                                               
    bl      timer_end                                              
    movs    r1, #1                                                 
    cmp     r0, r1                                                 
    bgt     dash                                                   
    b       gpio_isr_done                                          
    
fallingEdge:						                               @ Subroutine to distinguish a dot or space when putton is pressed
    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)           @ Get the address of the INTR Register 2
    ldr     r1, =GPIO_BTN_DN_MSK                              @ Get the mask for GP21 Falling Edge
    str     r1, [r2]                                               @ Reset the GPIO ISR for GP21 Falling Edge
    bl      timer_end                                              @ Calls on c funtion end timer to return time elapsed                              
    movs    r1, #1                                                 @ Stores time elapsed from timer(1 - 1 second)
    cmp     r0, r1                                                 @ Checks if one second has passed
    bgt     add_space                                              @ If time elasped is greater than go to add_space subroutine 
    b       dot                                                    @ Else go to dot subroutine
    
@ Add a dot, a dash, or space    
dot:                                                               @ Add dot subroutine
    movs    r0, #0                                                 @ In add_input functoin in c, code for dot is 0
    movs    r1, #0                                                
    bl      add_input                                              @ Call add_input() to add inputs
    b       gpio_isr_done                                       
    
dash:                                                              @ Add dash subroutine by replacing last dot
    movs    r0, #1                                                 @ In add_input function --> dash is 1
    movs    r1, #1                                                 @ Sets the last character to be overwritten at previous index (i.e., the last dot)
    bl      add_input                                              @ Call add_input() to add inputs
    b       gpio_isr_done                                         
    
add_space:                                                         @ Add space subroutine
    movs    r0, #2                                                 @ In add_input function --> space is 2 
    movs    r1, #0                                           
    bl      add_input                                              @ Call add_input() to add inputs
    b       dot				   	                                   @ After a space is added add a dot, overwritten if next input is dash



.align 4
instruction_m:    .asciz "\n\t\tInput your Morse Code using the middle button\n"      
input_message:    .asciz "\n\tInput Entered -> "

@ Set data alignment
.data
    .align 4
    current_alarm_time:         .word   DFLT_ALARM_TIME  @ Stores the current alarm time
    alarm_timer:         .word   DFLT_STATE   @ Initially alarm has not been run
