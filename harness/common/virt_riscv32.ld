ENTRY(_start)

/* QEMU riscv 'virt' board: DRAM at 0x80000000. With -bios none -kernel, QEMU's
 * built-in reset stub jumps to the kernel load address (0x80000000). Single
 * RAM region, VMA == LMA, so .data needs no copy (unlike the Cortex-M script);
 * the startup only zeroes .bss, matching the ARM and overall design. */
MEMORY
{
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 16M
}

__stack_top = ORIGIN(RAM) + LENGTH(RAM);

SECTIONS
{
    . = ORIGIN(RAM);

    .text :
    {
        *(.text._start*)
        *(.text*)
        *(.rodata*)
    } > RAM
    . = ALIGN(8);
    _etext = .;

    .data :
    {
        . = ALIGN(8);
        __data_start = .;
        *(.data*)
        . = ALIGN(8);
        __global_pointer$ = . + 0x800;   /* gp base for linker-relaxed access */
        *(.sdata*)
        . = ALIGN(8);
        __data_end = .;
    } > RAM

    .bss (NOLOAD) :
    {
        . = ALIGN(4);
        __bss_start = .;
        *(.sbss*)
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM
}
