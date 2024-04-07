#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"


.syntax unified
.cpu    cortex-m0plus
.thumb
.global main_asm
.align  4

.equ    DFLT_STATE_STRT, 1            @ Specify the value to start flashing
.equ    DFLT_STATE_STOP, 0            @ Specify the value to stop flashing
.equ    DFLT_ALARM_TIME, 1000000      @ Specify the default alarm timeout
.equ    GPIO_BTN_RISE_MSK, 0x00400000 @ Bit-22 for falling-edge event on GP21
.equ    GPIO_BTN_FALL_MSK, 0x00800000 @ Bit-22 for falling-edge event on GP21
.equ    GPIO_BTN,  21                 @ Specify pin for the input button
.equ    GPIO_LED_PIN, 25                                        @ Specify pin for the built-in LED
.equ    GPIO_ISR_OFFSET, 0x74         @ GPIO is int #13 (vector table entry 29)
.equ    ALRM_ISR_OFFSET, 0x40         @ ALARM0 is int #0 (vector table entry 16)
.equ    GPIO_DIR_IN,   0              @ Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT,  1              @ Specify output direction for a GPIO pin

@ Entry point to the ASM portion of the program
main_asm:
        push     {lr}          
        bl      init_gpio_buttons       @ Initialise the GPIO buttons
        @ bl      init_gpio_led           @Initalise LED
        bl      install_gpio_isr        @install isr for the gpio buttons
        bl      install_alarm_isr         @install alarm

        ldr      r0, =message                         
        bl       printf                         
        wfi           

main_loop:                         
        bl      set_alarm0                                            
        wfi					                                            
        ldr     r2, =ltimer                                        
        ldr     r1, [r2]                                                
        movs    r0, #1                                                  
        cmp     r0, r1                                                  
        bne     main_loop                                                      
        movs    r0, #0                                                  
        str     r0, [r2]                                                
        movs    r0, #3                                                  
        movs    r1, #0                                                  
        bl      add_to_input                                               
        pop     {pc}                                                    



set_alarm0:
        @ Set's the next alarm on alarm 0
        @ R0 is the length of the alarm
        @ Enable timer 0 interrupt
        ldr     r2, =TIMER_BASE
        movs     r1, #1 @ for alarm 0
        str     r1, [r2, #TIMER_INTE_OFFSET]
        @ Set alarm
        ldr     r1, [r2, #TIMER_TIMELR_OFFSET]
        add     r1, r0
        str     r1, [r2, #TIMER_ALARM0_OFFSET]
        bx      lr

install_alarm_isr:
        @Create the new ISR – part of its functionality should be to clear the pending interrupt
        @that it is servicing before it completes
        @Copy the address of the new ISR to the appropriate entry in the vector table
       @ (PPB_BASE + M0PLUS_VTOR_OFFSET + ALARM_ISR_OFFSET).
        ldr     r0, =alarm_isr
        ldr     r2, = (PPB_BASE + M0PLUS_VTOR_OFFSET)   @add the base address of the hardware registers to the offset of IVT
        ldr     r1, [r2]                                @load the address of the IVT to r1
        movs    r2, #ALRM_ISR_OFFSET                    @alarm offset to vector table entry 16
        add     r1, r2                                  @add the offset to the address to get to entry 16
        str     r0, [r1]                                @store the address of the routine handler in the IVT
        @Disable the specific interrupt level by writing to the appropriate bit in (PPB_BASE +
        @M0PLUS_NVIC_ICPR_OFFSET)
         ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
        movs    r1, #1
        str     r1, [r2]
        @Enable the specific interrupt level by writing to the appropriate bit in (PPB_BASE +
        @M0PLUS_NVIC_ICPR_OFFSET)
        ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
        movs    r1, #1
        str     r1, [r2]
        @Exit subroutine
        bx      lr



.thumb_func
alarm_isr:
        @Disable the next interrput from the timer by writing 1 to timerbase and the offset added together
        push    {lr}
        ldr     r2, =TIMER_BASE
        movs    r1, #1
        str     r1, [r2, #TIMER_INTR_OFFSET]
        @Check state of LED to determine next action
        ldr     r2, =ltimer    @current state of the led (if flashing or not)
        movs    r0, #1                              
        str     r0, [r2]                @ put 1 in alarm timer                           
        pop     {pc}        



install_gpio_isr:
         @Copy the address of the new ISR to the appropriate entry in the vector table
       @ (PPB_BASE + M0PLUS_VTOR_OFFSET + ALARM_ISR_OFFSET).
        ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)
        ldr     r1, [r2]
        movs    r2, #GPIO_ISR_OFFSET
        add     r2, r1
        ldr     r0, =gpio_isr
        str     r0, [r2]
        @Disable the specific interrupt level by writing to the appropriate bit in (PPB_BASE +
        @M0PLUS_NVIC_ICPR_OFFSET)
        ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
        movs    r1, #1
        lsls    r1, #13 //GPIO is IRQ13 (IO_IRQ_BANK0)
        str     r1, [r2]
        @Disable the specific interrupt level by writing to the appropriate bit in (PPB_BASE +M0PLUS_NVIC_ICPR_OFFSET)
        ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
        str     r1, [r2]
        @Exit subroutine
        bx      lr


.thumb_func
gpio_isr:
     @Read status from the (IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET) register
    push    {lr}
    ldr     r0, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)
    ldr     r1, [r0]                

    @enter check
    ldr     r2, =GPIO_BTN_RISE_MSK    @load enable mask to r2
    cmp     r1, r2                  @if bit was present in r0 and in the mask then enter button was pressed
    beq     risingEdge      @perform the action done when enter is pressed
   
    @up check
    ldr     r2, =GPIO_BTN_FALL_MSK    @load up mask to r2
    cmp     r1, r2                  @if bit was present in r0 and in the mask then up button was pressed
    beq     fallingEdge         @perform the action done when up is pressed
    interrupt_end:
    bl      timer_begin
    pop     {pc}


risingEdge:
    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET) 
    ldr     r1, =GPIO_BTN_RISE_MSK       
    str     r1, [r2]
    bl      timer_end                                              
    movs    r1, #1                                                 
    cmp     r0, r1                                                 
    bgt     dash                                                   
    b       interrupt_end        


fallingEdge:						           @ Subroutine to distinguish a dot or space when putton is pressed
    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)           @ Get the address of the INTR Register 2
    ldr     r1, =GPIO_BTN_FALL_MSK                              @ Get the mask for GP21 Falling Edge
    str     r1, [r2]                                               @ Reset the GPIO ISR for GP21 Falling Edge
    bl      timer_end                                              @ Calls on c funtion end timer to return time elapsed                              
    movs    r1, #1                                                 @ Stores time elapsed from timer(1 - 1 second)
    cmp     r0, r1                                                 @ Checks if one second has passed
    bgt     add_space                                              @ If time elasped is greater than go to add_space subroutine 
    b       dot                                                    @ Else go to dot subroutine



dash: 
    movs    r0, #1    
    movs    r1, #1
    bl      add_to_input
    b       interrupt_end
    
dot:
    movs    r0, #0    
    movs    r1, #1
    bl      add_to_input
    b       interrupt_end

add_space:
    movs    r0, #2    
    movs    r1, #0
    bl      add_to_input
    b       interrupt_end    
    

    


init_gpio_buttons:
        push {lr}                  @Push Link Register
        @Button
        movs    r0, #GPIO_BTN       @ This value is the GPIO button pin on the PI PICO board
        bl      asm_gpio_init           @  Call the subroutine to initialise the GPIO pin specified by r0
        movs     r0, #GPIO_BTN       @ Button pin value (21)
        movs     r1, #GPIO_DIR_IN       @ Input value (0)
        bl      asm_gpio_set_dir        @ Call the subroutine to set the GPIO button specified by r0 to state specified by r1
        movs     r0, #GPIO_BTN       @ Button pin value (21)
        bl      asm_gpio_set_irq
        pop     {pc}               @Pop Link Register to return to where routine is called


.align 4
message:    .asciz "enter your input %d\n"


.data
lstate: .word   DFLT_STATE_STRT
ltimer: .word   DFLT_ALARM_TIME