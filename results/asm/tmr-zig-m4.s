
zig-out/harness/tmr-harness-zig-m4.elf:	file format elf32-littlearm

Disassembly of section .text:

00000040 <_start>:
      40: 4807         	ldr	r0, [pc, #0x1c]         @ 0x60 <Default_Handler+0x6>
      42: 4685         	mov	sp, r0
      44: 4807         	ldr	r0, [pc, #0x1c]         @ 0x64 <Default_Handler+0xa>
      46: 4908         	ldr	r1, [pc, #0x20]         @ 0x68 <Default_Handler+0xe>
      48: 2200         	movs	r2, #0x0
      4a: 4288         	cmp	r0, r1
      4c: d202         	bhs	0x54 <_start+0x14>      @ imm = #0x4
      4e: f840 2b04    	str	r2, [r0], #4
      52: e7fa         	b	0x4a <_start+0xa>       @ imm = #-0xc
      54: f000 f80a    	bl	0x6c <tmr_harness.harness_main> @ imm = #0x14
      58: e7fe         	b	0x58 <_start+0x18>      @ imm = #-0x4

0000005a <Default_Handler>:
      5a: f7ff bffe    	b.w	0x5a <Default_Handler>  @ imm = #-0x4
      5e: 0000         	movs	r0, r0
      60: 00 00 40 20  	.word	0x20400000
      64: 00 00 00 20  	.word	0x20000000
      68: 38 00 00 20  	.word	0x20000038

0000006c <tmr_harness.harness_main>:
      6c: b5f0         	push	{r4, r5, r6, r7, lr}
      6e: af03         	add	r7, sp, #0xc
      70: e92d 0f00    	push.w	{r8, r9, r10, r11}
      74: b081         	sub	sp, #0x4
      76: f240 0400    	movw	r4, #0x0
      7a: f2c2 0400    	movt	r4, #0x2000
      7e: f04f 0a00    	mov.w	r10, #0x0
      82: f04f 0b02    	mov.w	r11, #0x2
      86: f04f 0903    	mov.w	r9, #0x3
      8a: f8c4 a030    	str.w	r10, [r4, #0x30]
      8e: e023         	b	0xd8 <tmr_harness.harness_main+0x6c> @ imm = #0x46
      90: 1a43         	subs	r3, r0, r1
      92: 4615         	mov	r5, r2
      94: bf18         	it	ne
      96: 2301         	movne	r3, #0x1
      98: 461e         	mov	r6, r3
      9a: 6225         	str	r5, [r4, #0x20]
      9c: 2300         	movs	r3, #0x0
      9e: 61e3         	str	r3, [r4, #0x1c]
      a0: 60e0         	str	r0, [r4, #0xc]
      a2: 60a2         	str	r2, [r4, #0x8]
      a4: 6061         	str	r1, [r4, #0x4]
      a6: 6026         	str	r6, [r4]
      a8: f8c4 9030    	str.w	r9, [r4, #0x30]
      ac: 69e0         	ldr	r0, [r4, #0x1c]
      ae: 6a21         	ldr	r1, [r4, #0x20]
      b0: 6922         	ldr	r2, [r4, #0x10]
      b2: 2a02         	cmp	r2, #0x2
      b4: bf1a         	itte	ne
      b6: ea81 0108    	eorne.w	r1, r1, r8
      ba: 4308         	orrne	r0, r1
      bc: 3801         	subeq	r0, #0x1
      be: fab0 f080    	clz	r0, r0
      c2: 0940         	lsrs	r0, r0, #0x5
      c4: 2800         	cmp	r0, #0x0
      c6: f04f 0014    	mov.w	r0, #0x14
      ca: bf18         	it	ne
      cc: 2018         	movne	r0, #0x18
      ce: 5821         	ldr	r1, [r4, r0]
      d0: 3101         	adds	r1, #0x1
      d2: 5021         	str	r1, [r4, r0]
      d4: f000 f848    	bl	0x168 <tmr_harness.harness_injection_point_after_read> @ imm = #0x90
      d8: 6b60         	ldr	r0, [r4, #0x34]
      da: f647 11b1    	movw	r1, #0x79b1
      de: 3001         	adds	r0, #0x1
      e0: f6c9 6137    	movt	r1, #0x9e37
      e4: 2200         	movs	r2, #0x0
      e6: 4341         	muls	r1, r0, r1
      e8: f6c5 225a    	movt	r2, #0x5a5a
      ec: ea81 0802    	eor.w	r8, r1, r2
      f0: 6360         	str	r0, [r4, #0x34]
      f2: 2001         	movs	r0, #0x1
      f4: f8c4 8024    	str.w	r8, [r4, #0x24]
      f8: f8c4 a020    	str.w	r10, [r4, #0x20]
      fc: f8c4 a01c    	str.w	r10, [r4, #0x1c]
     100: f8c4 a010    	str.w	r10, [r4, #0x10]
     104: f8c4 800c    	str.w	r8, [r4, #0xc]
     108: f8c4 8008    	str.w	r8, [r4, #0x8]
     10c: f8c4 8004    	str.w	r8, [r4, #0x4]
     110: f8c4 a000    	str.w	r10, [r4]
     114: 6320         	str	r0, [r4, #0x30]
     116: f000 f82b    	bl	0x170 <tmr_harness.harness_injection_point_after_init> @ imm = #0x56
     11a: 6ae1         	ldr	r1, [r4, #0x2c]
     11c: 6aa0         	ldr	r0, [r4, #0x28]
     11e: 2902         	cmp	r1, #0x2
     120: 6121         	str	r1, [r4, #0x10]
     122: d005         	beq	0x130 <tmr_harness.harness_main+0xc4> @ imm = #0xa
     124: 2901         	cmp	r1, #0x1
     126: 4641         	mov	r1, r8
     128: 4642         	mov	r2, r8
     12a: bf18         	it	ne
     12c: 4640         	movne	r0, r8
     12e: e003         	b	0x138 <tmr_harness.harness_main+0xcc> @ imm = #0x6
     130: f080 3211    	eor	r2, r0, #0x11111111
     134: f080 3122    	eor	r1, r0, #0x22222222
     138: 4290         	cmp	r0, r2
     13a: f8c4 a02c    	str.w	r10, [r4, #0x2c]
     13e: 60e0         	str	r0, [r4, #0xc]
     140: 60a2         	str	r2, [r4, #0x8]
     142: 6061         	str	r1, [r4, #0x4]
     144: f8c4 a000    	str.w	r10, [r4]
     148: f8c4 b030    	str.w	r11, [r4, #0x30]
     14c: d0a0         	beq	0x90 <tmr_harness.harness_main+0x24> @ imm = #-0xc0
     14e: 4288         	cmp	r0, r1
     150: f04f 0301    	mov.w	r3, #0x1
     154: d006         	beq	0x164 <tmr_harness.harness_main+0xf8> @ imm = #0xc
     156: 428a         	cmp	r2, r1
     158: f04f 0601    	mov.w	r6, #0x1
     15c: 460d         	mov	r5, r1
     15e: d19e         	bne	0x9e <tmr_harness.harness_main+0x32> @ imm = #-0xc4
     160: e79a         	b	0x98 <tmr_harness.harness_main+0x2c> @ imm = #-0xcc
     162: bf00         	nop
     164: 460d         	mov	r5, r1
     166: e797         	b	0x98 <tmr_harness.harness_main+0x2c> @ imm = #-0xd2

00000168 <tmr_harness.harness_injection_point_after_read>:
     168: b580         	push	{r7, lr}
     16a: 466f         	mov	r7, sp
     16c: bf00         	nop
     16e: bd80         	pop	{r7, pc}

00000170 <tmr_harness.harness_injection_point_after_init>:
     170: b580         	push	{r7, lr}
     172: 466f         	mov	r7, sp
     174: bf00         	nop
     176: bd80         	pop	{r7, pc}

00000178 <compiler_rt.arm.__aeabi_unwind_cpp_pr0>:
     178: b580         	push	{r7, lr}
     17a: 466f         	mov	r7, sp
     17c: bd80         	pop	{r7, pc}
     17e: d4d4         	bmi	0x12a <tmr_harness.harness_main+0xbe> @ imm = #-0x58
     180: 9746         	str	r7, [sp, #0x118]
     182: 8101         	strh	r1, [r0, #0x8]
     184: abb0         	add	r3, sp, #0x2c0
     186: 80f0         	strh	r0, [r6, #0x6]
     188: 0000         	movs	r0, r0
     18a: 0000         	movs	r0, r0
