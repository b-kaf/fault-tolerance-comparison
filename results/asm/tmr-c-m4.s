
zig-out/harness/tmr-harness-c-m4.elf:	file format elf32-littlearm

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
      54: f000 f81e    	bl	0x94 <harness_main>     @ imm = #0x3c
      58: e7fe         	b	0x58 <_start+0x18>      @ imm = #-0x4

0000005a <Default_Handler>:
      5a: f7ff bffe    	b.w	0x5a <Default_Handler>  @ imm = #-0x4
      5e: 0000         	movs	r0, r0
      60: 00 00 40 20  	.word	0x20400000
      64: 00 00 00 20  	.word	0x20000000
      68: 38 00 00 20  	.word	0x20000038
      6c: fe ca 05 c1  	.word	0xc105cafe
      70: bc 3e f2 35  	.word	0x35f23ebc

00000074 <harness_injection_point_after_init>:
      74: b580         	push	{r7, lr}
      76: 466f         	mov	r7, sp
      78: bf00         	nop
      7a: bd80         	pop	{r7, pc}
      7c: fe ca 05 c1  	.word	0xc105cafe
      80: bc 3e f2 35  	.word	0x35f23ebc

00000084 <harness_injection_point_after_read>:
      84: b580         	push	{r7, lr}
      86: 466f         	mov	r7, sp
      88: bf00         	nop
      8a: bd80         	pop	{r7, pc}
      8c: fe ca 05 c1  	.word	0xc105cafe
      90: bc 3e f2 35  	.word	0x35f23ebc

00000094 <harness_main>:
      94: b5f0         	push	{r4, r5, r6, r7, lr}
      96: af03         	add	r7, sp, #0xc
      98: e92d 0f00    	push.w	{r8, r9, r10, r11}
      9c: b085         	sub	sp, #0x14
      9e: f240 0600    	movw	r6, #0x0
      a2: f240 040c    	movw	r4, #0xc
      a6: f240 0810    	movw	r8, #0x10
      aa: f240 0914    	movw	r9, #0x14
      ae: f240 0a18    	movw	r10, #0x18
      b2: f2c2 0600    	movt	r6, #0x2000
      b6: 2500         	movs	r5, #0x0
      b8: f2c2 0400    	movt	r4, #0x2000
      bc: f2c2 0800    	movt	r8, #0x2000
      c0: f2c2 0900    	movt	r9, #0x2000
      c4: f2c2 0a00    	movt	r10, #0x2000
      c8: 6035         	str	r5, [r6]
      ca: e02f         	b	0x12c <harness_main+0x98> @ imm = #0x5e
      cc: f8da 200c    	ldr.w	r2, [r10, #0xc]
      d0: 1c51         	adds	r1, r2, #0x1
      d2: f04f 0100    	mov.w	r1, #0x0
      d6: d002         	beq	0xde <harness_main+0x4a> @ imm = #0x4
      d8: 3201         	adds	r2, #0x1
      da: f8ca 200c    	str.w	r2, [r10, #0xc]
      de: f240 040c    	movw	r4, #0xc
      e2: f2c2 0400    	movt	r4, #0x2000
      e6: 6020         	str	r0, [r4]
      e8: 2003         	movs	r0, #0x3
      ea: f8c8 1000    	str.w	r1, [r8]
      ee: 6030         	str	r0, [r6]
      f0: f8d8 0000    	ldr.w	r0, [r8]
      f4: 6821         	ldr	r1, [r4]
      f6: f8d9 2000    	ldr.w	r2, [r9]
      fa: 2a02         	cmp	r2, #0x2
      fc: bf1a         	itte	ne
      fe: ea81 010b    	eorne.w	r1, r1, r11
     102: 4308         	orrne	r0, r1
     104: 3801         	subeq	r0, #0x1
     106: fab0 f080    	clz	r0, r0
     10a: 0940         	lsrs	r0, r0, #0x5
     10c: 2800         	cmp	r0, #0x0
     10e: f240 0034    	movw	r0, #0x34
     112: f240 0130    	movw	r1, #0x30
     116: f2c2 0000    	movt	r0, #0x2000
     11a: f2c2 0100    	movt	r1, #0x2000
     11e: bf18         	it	ne
     120: 4608         	movne	r0, r1
     122: 6801         	ldr	r1, [r0]
     124: 3101         	adds	r1, #0x1
     126: 6001         	str	r1, [r0]
     128: f7ff ffac    	bl	0x84 <harness_injection_point_after_read> @ imm = #-0xa8
     12c: f240 0204    	movw	r2, #0x4
     130: f2c2 0200    	movt	r2, #0x2000
     134: 6810         	ldr	r0, [r2]
     136: f647 11b1    	movw	r1, #0x79b1
     13a: 3001         	adds	r0, #0x1
     13c: f6c9 6137    	movt	r1, #0x9e37
     140: 2300         	movs	r3, #0x0
     142: 4341         	muls	r1, r0, r1
     144: f6c5 235a    	movt	r3, #0x5a5a
     148: 6010         	str	r0, [r2]
     14a: f240 0008    	movw	r0, #0x8
     14e: ea81 0b03    	eor.w	r11, r1, r3
     152: f2c2 0000    	movt	r0, #0x2000
     156: f8c0 b000    	str.w	r11, [r0]
     15a: 6025         	str	r5, [r4]
     15c: f8c8 5000    	str.w	r5, [r8]
     160: f8c9 5000    	str.w	r5, [r9]
     164: e9cd bb03    	strd	r11, r11, [sp, #12]
     168: e9cd 5b01    	strd	r5, r11, [sp, #4]
     16c: 9804         	ldr	r0, [sp, #0x10]
     16e: f8ca 0000    	str.w	r0, [r10]
     172: 9803         	ldr	r0, [sp, #0xc]
     174: f8ca 0004    	str.w	r0, [r10, #0x4]
     178: 9802         	ldr	r0, [sp, #0x8]
     17a: f8ca 0008    	str.w	r0, [r10, #0x8]
     17e: 9801         	ldr	r0, [sp, #0x4]
     180: f8ca 000c    	str.w	r0, [r10, #0xc]
     184: 2001         	movs	r0, #0x1
     186: 6030         	str	r0, [r6]
     188: f7ff ff74    	bl	0x74 <harness_injection_point_after_init> @ imm = #-0x118
     18c: f240 0028    	movw	r0, #0x28
     190: f2c2 0000    	movt	r0, #0x2000
     194: 6801         	ldr	r1, [r0]
     196: f240 002c    	movw	r0, #0x2c
     19a: f2c2 0000    	movt	r0, #0x2000
     19e: 6800         	ldr	r0, [r0]
     1a0: 2901         	cmp	r1, #0x1
     1a2: f8c9 1000    	str.w	r1, [r9]
     1a6: d009         	beq	0x1bc <harness_main+0x128> @ imm = #0x12
     1a8: 2902         	cmp	r1, #0x2
     1aa: d10b         	bne	0x1c4 <harness_main+0x130> @ imm = #0x16
     1ac: f080 3111    	eor	r1, r0, #0x11111111
     1b0: f080 3222    	eor	r2, r0, #0x22222222
     1b4: e88a 0007    	stm.w	r10, {r0, r1, r2}
     1b8: e006         	b	0x1c8 <harness_main+0x134> @ imm = #0xc
     1ba: bf00         	nop
     1bc: f8ca 0000    	str.w	r0, [r10]
     1c0: e002         	b	0x1c8 <harness_main+0x134> @ imm = #0x4
     1c2: bf00         	nop
     1c4: f8da 0000    	ldr.w	r0, [r10]
     1c8: f240 0228    	movw	r2, #0x28
     1cc: 2100         	movs	r1, #0x0
     1ce: f2c2 0200    	movt	r2, #0x2000
     1d2: 6011         	str	r1, [r2]
     1d4: 2202         	movs	r2, #0x2
     1d6: 6032         	str	r2, [r6]
     1d8: e9da 3401    	ldrd	r3, r4, [r10, #4]
     1dc: 4298         	cmp	r0, r3
     1de: bf08         	it	eq
     1e0: 42a3         	cmpeq	r3, r4
     1e2: f43f af7c    	beq.w	0xde <harness_main+0x4a> @ imm = #-0x108
     1e6: 4298         	cmp	r0, r3
     1e8: f43f af70    	beq.w	0xcc <harness_main+0x38> @ imm = #-0x120
     1ec: f8da 200c    	ldr.w	r2, [r10, #0xc]
     1f0: 46b4         	mov	r12, r6
     1f2: 42a0         	cmp	r0, r4
     1f4: f102 0601    	add.w	r6, r2, #0x1
     1f8: d104         	bne	0x204 <harness_main+0x170> @ imm = #0x8
     1fa: 2e00         	cmp	r6, #0x0
     1fc: 4666         	mov	r6, r12
     1fe: f47f af6b    	bne.w	0xd8 <harness_main+0x44> @ imm = #-0x12a
     202: e76c         	b	0xde <harness_main+0x4a> @ imm = #-0x128
     204: 1b19         	subs	r1, r3, r4
     206: bf18         	it	ne
     208: 2101         	movne	r1, #0x1
     20a: 42a3         	cmp	r3, r4
     20c: bf18         	it	ne
     20e: 462b         	movne	r3, r5
     210: 2e00         	cmp	r6, #0x0
     212: 4618         	mov	r0, r3
     214: 4666         	mov	r6, r12
     216: f47f af5f    	bne.w	0xd8 <harness_main+0x44> @ imm = #-0x142
     21a: e760         	b	0xde <harness_main+0x4a> @ imm = #-0x140

0000021c <compiler_rt.arm.__aeabi_unwind_cpp_pr0>:
     21c: b580         	push	{r7, lr}
     21e: 466f         	mov	r7, sp
     220: bd80         	pop	{r7, pc}
     222: d4d4         	bmi	0x1ce <harness_main+0x13a> @ imm = #-0x58
     224: 9746         	str	r7, [sp, #0x118]
     226: 8101         	strh	r1, [r0, #0x8]
     228: abb0         	add	r3, sp, #0x2c0
     22a: 80f0         	strh	r0, [r6, #0x6]
     22c: 0000         	movs	r0, r0
     22e: 0000         	movs	r0, r0
