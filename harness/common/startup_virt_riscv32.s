/* Bare-metal RISC-V (RV32) startup for the QEMU 'virt' board.
 *
 * Counterpart to startup_mps2_an386.s. QEMU's -kernel loader jumps straight to
 * _start, so this only establishes a C environment: global pointer, stack
 * pointer, a zeroed .bss, then call harness_main and spin. Little-endian RV32. */
    .section .text._start, "ax", @progbits
    .global _start
_start:
    .option push
    .option norelax
    la      gp, __global_pointer$
    .option pop

    la      sp, __stack_top

    /* zero .bss: for (t0 = __bss_start; t0 < __bss_end; t0 += 4) *t0 = 0 */
    la      t0, __bss_start
    la      t1, __bss_end
1:
    bgeu    t0, t1, 2f
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       1b
2:
    call    harness_main
3:
    j       3b              /* harness_main is noreturn; spin as a safety net */
