.syntax unified
.cpu cortex-m4
.thumb

.extern harness_main
.extern __stack_top
.extern __bss_start
.extern __bss_end

.global _start
.global Reset_Handler
.global Default_Handler

.section .vectors, "a", %progbits
.word __stack_top
.word Reset_Handler + 1
.word Default_Handler + 1
.word Default_Handler + 1
.word Default_Handler + 1
.word Default_Handler + 1
.word Default_Handler + 1
.word 0
.word 0
.word 0
.word 0
.word Default_Handler + 1
.word Default_Handler + 1
.word 0
.word Default_Handler + 1
.word Default_Handler + 1

.section .text.Reset_Handler, "ax", %progbits
.thumb_func
_start:
Reset_Handler:
    ldr r0, =__stack_top
    mov sp, r0

    ldr r0, =__bss_start
    ldr r1, =__bss_end
    movs r2, #0
1:
    cmp r0, r1
    bhs 2f
    str r2, [r0], #4
    b 1b
2:
    bl harness_main
    b .

.thumb_func
Default_Handler:
    b Default_Handler
