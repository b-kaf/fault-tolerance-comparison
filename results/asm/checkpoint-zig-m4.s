
zig-out/harness/checkpoint-harness-zig-m4.elf:	file format elf32-littlearm

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
      54: f000 f80a    	bl	0x6c <harness_main>     @ imm = #0x14
      58: e7fe         	b	0x58 <_start+0x18>      @ imm = #-0x4

0000005a <Default_Handler>:
      5a: f7ff bffe    	b.w	0x5a <Default_Handler>  @ imm = #-0x4
      5e: 0000         	movs	r0, r0
      60: 00 00 40 20  	.word	0x20400000
      64: 00 00 00 20  	.word	0x20000000
      68: 58 00 00 20  	.word	0x20000058

0000006c <harness_main>:
      6c: b5f0         	push	{r4, r5, r6, r7, lr}
      6e: af03         	add	r7, sp, #0xc
      70: e92d 0f00    	push.w	{r8, r9, r10, r11}
      74: b081         	sub	sp, #0x4
      76: f240 0600    	movw	r6, #0x0
      7a: f2c2 0600    	movt	r6, #0x2000
      7e: 2000         	movs	r0, #0x0
      80: 6530         	str	r0, [r6, #0x50]
      82: e017         	b	0xb4 <harness_main+0x48> @ imm = #0x2e
      84: 4310         	orrs	r0, r2
      86: 454b         	cmp	r3, r9
      88: f04f 0228    	mov.w	r2, #0x28
      8c: bf08         	it	eq
      8e: 2204         	moveq	r2, #0x4
      90: 4549         	cmp	r1, r9
      92: f04f 0128    	mov.w	r1, #0x28
      96: bf18         	it	ne
      98: 460a         	movne	r2, r1
      9a: f1bc 0f00    	cmp.w	r12, #0x0
      9e: bf18         	it	ne
      a0: 460a         	movne	r2, r1
      a2: 2800         	cmp	r0, #0x0
      a4: bf18         	it	ne
      a6: 460a         	movne	r2, r1
      a8: 18b0         	adds	r0, r6, r2
      aa: 6801         	ldr	r1, [r0]
      ac: 3101         	adds	r1, #0x1
      ae: 6001         	str	r1, [r0]
      b0: f000 f958    	bl	0x364 <harness_injection_point_after_commit> @ imm = #0x2b0
      b4: 6d71         	ldr	r1, [r6, #0x54]
      b6: 2225         	movs	r2, #0x25
      b8: 1c48         	adds	r0, r1, #0x1
      ba: f247 3491    	movw	r4, #0x7391
      be: 4342         	muls	r2, r0, r2
      c0: f6c5 549f    	movt	r4, #0x5d9f
      c4: fba2 3504    	umull	r3, r5, r2, r4
      c8: 2335         	movs	r3, #0x35
      ca: 4359         	muls	r1, r3, r1
      cc: f501 7184    	add.w	r1, r1, #0x108
      d0: fba1 3404    	umull	r3, r4, r1, r4
      d4: 0a2b         	lsrs	r3, r5, #0x8
      d6: f44f 752f    	mov.w	r5, #0x2bc
      da: fb03 2215    	mls	r2, r3, r5, r2
      de: 0a23         	lsrs	r3, r4, #0x8
      e0: fb03 1115    	mls	r1, r3, r5, r1
      e4: f102 0964    	add.w	r9, r2, #0x64
      e8: f101 0a64    	add.w	r10, r1, #0x64
      ec: f247 1280    	movw	r2, #0x7180
      f0: 6570         	str	r0, [r6, #0x54]
      f2: 2000         	movs	r0, #0x0
      f4: f2c8 128b    	movt	r2, #0x818b
      f8: f240 1393    	movw	r3, #0x193
      fc: f8c6 9038    	str.w	r9, [r6, #0x38]
     100: f8c6 a03c    	str.w	r10, [r6, #0x3c]
     104: 6370         	str	r0, [r6, #0x34]
     106: 62f0         	str	r0, [r6, #0x2c]
     108: 6270         	str	r0, [r6, #0x24]
     10a: 61f0         	str	r0, [r6, #0x1c]
     10c: 6170         	str	r0, [r6, #0x14]
     10e: 6030         	str	r0, [r6]
     110: 2004         	movs	r0, #0x4
     112: ea89 0102    	eor.w	r1, r9, r2
     116: f2c0 1300    	movt	r3, #0x100
     11a: 6530         	str	r0, [r6, #0x50]
     11c: ea8a 0002    	eor.w	r0, r10, r2
     120: 4359         	muls	r1, r3, r1
     122: 4358         	muls	r0, r3, r0
     124: ea4f 61f1    	ror.w	r1, r1, #0x1b
     128: ea4f 60f0    	ror.w	r0, r0, #0x1b
     12c: 4359         	muls	r1, r3, r1
     12e: f44f 7c7a    	mov.w	r12, #0x3e8
     132: 4358         	muls	r0, r3, r0
     134: ea8c 61f1    	eor.w	r1, r12, r1, ror #27
     138: ea8c 60f0    	eor.w	r0, r12, r0, ror #27
     13c: 4359         	muls	r1, r3, r1
     13e: 2506         	movs	r5, #0x6
     140: 4358         	muls	r0, r3, r0
     142: ea85 61f1    	eor.w	r1, r5, r1, ror #27
     146: ea85 60f0    	eor.w	r0, r5, r0, ror #27
     14a: 4359         	muls	r1, r3, r1
     14c: 2410         	movs	r4, #0x10
     14e: 4358         	muls	r0, r3, r0
     150: ea84 61f1    	eor.w	r1, r4, r1, ror #27
     154: ea84 60f0    	eor.w	r0, r4, r0, ror #27
     158: 4359         	muls	r1, r3, r1
     15a: 4358         	muls	r0, r3, r0
     15c: ea4f 68f1    	ror.w	r8, r1, #0x1b
     160: ea4f 6bf0    	ror.w	r11, r0, #0x1b
     164: 2401         	movs	r4, #0x1
     166: 2005         	movs	r0, #0x5
     168: f8c6 a00c    	str.w	r10, [r6, #0xc]
     16c: f8c6 9008    	str.w	r9, [r6, #0x8]
     170: 64b4         	str	r4, [r6, #0x48]
     172: 61b5         	str	r5, [r6, #0x18]
     174: f8c6 b040    	str.w	r11, [r6, #0x40]
     178: 6334         	str	r4, [r6, #0x30]
     17a: 6235         	str	r5, [r6, #0x20]
     17c: f8c6 8010    	str.w	r8, [r6, #0x10]
     180: 6530         	str	r0, [r6, #0x50]
     182: f000 f8f3    	bl	0x36c <harness_injection_point_after_mutation> @ imm = #0x1e6
     186: 6cf2         	ldr	r2, [r6, #0x4c]
     188: 6c71         	ldr	r1, [r6, #0x44]
     18a: f1a2 000a    	sub.w	r0, r2, #0xa
     18e: 2805         	cmp	r0, #0x5
     190: 6032         	str	r2, [r6]
     192: d80f         	bhi	0x1b4 <harness_main+0x148> @ imm = #0x1e
     194: e8df f000    	tbb	[pc, r0]
     198: 18 04 0c 12  	.word	0x120c0418
     19c: 08 16 00 bf  	.word	0xbf001608
     1a0: 468e         	mov	lr, r1
     1a2: 4652         	mov	r2, r10
     1a4: e013         	b	0x1ce <harness_main+0x162> @ imm = #0x26
     1a6: bf00         	nop
     1a8: ea88 0801    	eor.w	r8, r8, r1
     1ac: e002         	b	0x1b4 <harness_main+0x148> @ imm = #0x4
     1ae: bf00         	nop
     1b0: ea8b 0b01    	eor.w	r11, r11, r1
     1b4: f04f 0e06    	mov.w	lr, #0x6
     1b8: 4652         	mov	r2, r10
     1ba: e008         	b	0x1ce <harness_main+0x162> @ imm = #0x10
     1bc: f04f 0e06    	mov.w	lr, #0x6
     1c0: 4652         	mov	r2, r10
     1c2: e005         	b	0x1d0 <harness_main+0x164> @ imm = #0xa
     1c4: f088 0810    	eor	r8, r8, #0x10
     1c8: f04f 0e06    	mov.w	lr, #0x6
     1cc: 460a         	mov	r2, r1
     1ce: 4649         	mov	r1, r9
     1d0: 2000         	movs	r0, #0x0
     1d2: 64f0         	str	r0, [r6, #0x4c]
     1d4: 2006         	movs	r0, #0x6
     1d6: f5b2 7f7a    	cmp.w	r2, #0x3e8
     1da: 60f2         	str	r2, [r6, #0xc]
     1dc: 60b1         	str	r1, [r6, #0x8]
     1de: 64b4         	str	r4, [r6, #0x48]
     1e0: f8c6 e018    	str.w	lr, [r6, #0x18]
     1e4: f8c6 b040    	str.w	r11, [r6, #0x40]
     1e8: 6334         	str	r4, [r6, #0x30]
     1ea: 6230         	str	r0, [r6, #0x20]
     1ec: f8c6 8010    	str.w	r8, [r6, #0x10]
     1f0: 6530         	str	r0, [r6, #0x50]
     1f2: d907         	bls	0x204 <harness_main+0x198> @ imm = #0xe
     1f4: f04f 0c02    	mov.w	r12, #0x2
     1f8: f5b1 7f7a    	cmp.w	r1, #0x3e8
     1fc: f04f 0006    	mov.w	r0, #0x6
     200: d80a         	bhi	0x218 <harness_main+0x1ac> @ imm = #0x14
     202: e039         	b	0x278 <harness_main+0x20c> @ imm = #0x72
     204: f1be 0f10    	cmp.w	lr, #0x10
     208: d90a         	bls	0x220 <harness_main+0x1b4> @ imm = #0x14
     20a: f04f 0c03    	mov.w	r12, #0x3
     20e: f5b1 7f7a    	cmp.w	r1, #0x3e8
     212: f04f 0006    	mov.w	r0, #0x6
     216: d92f         	bls	0x278 <harness_main+0x20c> @ imm = #0x5e
     218: 2502         	movs	r5, #0x2
     21a: 2302         	movs	r3, #0x2
     21c: e053         	b	0x2c6 <harness_main+0x25a> @ imm = #0xa6
     21e: bf00         	nop
     220: f247 1080    	movw	r0, #0x7180
     224: f2c8 108b    	movt	r0, #0x818b
     228: f240 1393    	movw	r3, #0x193
     22c: 4050         	eors	r0, r2
     22e: f2c0 1300    	movt	r3, #0x100
     232: 4358         	muls	r0, r3, r0
     234: ea4f 60f0    	ror.w	r0, r0, #0x1b
     238: 4358         	muls	r0, r3, r0
     23a: f44f 757a    	mov.w	r5, #0x3e8
     23e: ea85 60f0    	eor.w	r0, r5, r0, ror #27
     242: 4358         	muls	r0, r3, r0
     244: ea8e 60f0    	eor.w	r0, lr, r0, ror #27
     248: 4358         	muls	r0, r3, r0
     24a: 2510         	movs	r5, #0x10
     24c: ea85 60f0    	eor.w	r0, r5, r0, ror #27
     250: 4358         	muls	r0, r3, r0
     252: ebbb 6ff0    	cmp.w	r11, r0, ror #27
     256: d107         	bne	0x268 <harness_main+0x1fc> @ imm = #0xe
     258: 2500         	movs	r5, #0x0
     25a: 46d8         	mov	r8, r11
     25c: 4670         	mov	r0, lr
     25e: 4611         	mov	r1, r2
     260: f04f 0c00    	mov.w	r12, #0x0
     264: 2300         	movs	r3, #0x0
     266: e02e         	b	0x2c6 <harness_main+0x25a> @ imm = #0x5c
     268: f04f 0c04    	mov.w	r12, #0x4
     26c: f5b1 7f7a    	cmp.w	r1, #0x3e8
     270: f04f 0006    	mov.w	r0, #0x6
     274: d8d0         	bhi	0x218 <harness_main+0x1ac> @ imm = #-0x60
     276: bf00         	nop
     278: f247 1380    	movw	r3, #0x7180
     27c: f2c8 138b    	movt	r3, #0x818b
     280: f240 1593    	movw	r5, #0x193
     284: 404b         	eors	r3, r1
     286: f2c0 1500    	movt	r5, #0x100
     28a: 436b         	muls	r3, r5, r3
     28c: ea4f 63f3    	ror.w	r3, r3, #0x1b
     290: 436b         	muls	r3, r5, r3
     292: f44f 747a    	mov.w	r4, #0x3e8
     296: ea84 63f3    	eor.w	r3, r4, r3, ror #27
     29a: 436b         	muls	r3, r5, r3
     29c: ea80 63f3    	eor.w	r3, r0, r3, ror #27
     2a0: 436b         	muls	r3, r5, r3
     2a2: 2410         	movs	r4, #0x10
     2a4: ea84 63f3    	eor.w	r3, r4, r3, ror #27
     2a8: 436b         	muls	r3, r5, r3
     2aa: ebb8 6ff3    	cmp.w	r8, r3, ror #27
     2ae: d107         	bne	0x2c0 <harness_main+0x254> @ imm = #0xe
     2b0: 2300         	movs	r3, #0x0
     2b2: 2501         	movs	r5, #0x1
     2b4: f04f 0e06    	mov.w	lr, #0x6
     2b8: 46c3         	mov	r11, r8
     2ba: 460a         	mov	r2, r1
     2bc: e002         	b	0x2c4 <harness_main+0x258> @ imm = #0x4
     2be: bf00         	nop
     2c0: 2304         	movs	r3, #0x4
     2c2: 2502         	movs	r5, #0x2
     2c4: 2401         	movs	r4, #0x1
     2c6: 6275         	str	r5, [r6, #0x24]
     2c8: f8c6 c01c    	str.w	r12, [r6, #0x1c]
     2cc: 6173         	str	r3, [r6, #0x14]
     2ce: 60f2         	str	r2, [r6, #0xc]
     2d0: 60b1         	str	r1, [r6, #0x8]
     2d2: 64b4         	str	r4, [r6, #0x48]
     2d4: f8c6 e018    	str.w	lr, [r6, #0x18]
     2d8: f8c6 b040    	str.w	r11, [r6, #0x40]
     2dc: 6334         	str	r4, [r6, #0x30]
     2de: 6230         	str	r0, [r6, #0x20]
     2e0: f8c6 8010    	str.w	r8, [r6, #0x10]
     2e4: 68f0         	ldr	r0, [r6, #0xc]
     2e6: 6370         	str	r0, [r6, #0x34]
     2e8: 2007         	movs	r0, #0x7
     2ea: 6530         	str	r0, [r6, #0x50]
     2ec: 6834         	ldr	r4, [r6]
     2ee: 6a75         	ldr	r5, [r6, #0x24]
     2f0: 69f2         	ldr	r2, [r6, #0x1c]
     2f2: f8d6 c014    	ldr.w	r12, [r6, #0x14]
     2f6: 68f1         	ldr	r1, [r6, #0xc]
     2f8: 68b3         	ldr	r3, [r6, #0x8]
     2fa: 3c0a         	subs	r4, #0xa
     2fc: 2c05         	cmp	r4, #0x5
     2fe: d81f         	bhi	0x340 <harness_main+0x2d4> @ imm = #0x3e
     300: e8df f004    	tbb	[pc, r4]
     304: 0a 10 04 1e  	.word	0x1e04100a
     308: 1e 16 00 bf  	.word	0xbf00161e
     30c: f085 0001    	eor	r0, r5, #0x1
     310: f082 0204    	eor	r2, r2, #0x4
     314: e6b6         	b	0x84 <harness_main+0x18> @ imm = #-0x294
     316: bf00         	nop
     318: f085 0001    	eor	r0, r5, #0x1
     31c: f082 0202    	eor	r2, r2, #0x2
     320: e6b0         	b	0x84 <harness_main+0x18> @ imm = #-0x2a0
     322: bf00         	nop
     324: f085 0001    	eor	r0, r5, #0x1
     328: f082 0203    	eor	r2, r2, #0x3
     32c: e6aa         	b	0x84 <harness_main+0x18> @ imm = #-0x2ac
     32e: bf00         	nop
     330: 2d02         	cmp	r5, #0x2
     332: bf08         	it	eq
     334: 2a02         	cmpeq	r2, #0x2
     336: d00d         	beq	0x354 <harness_main+0x2e8> @ imm = #0x1a
     338: f106 0028    	add.w	r0, r6, #0x28
     33c: e6b5         	b	0xaa <harness_main+0x3e> @ imm = #-0x296
     33e: bf00         	nop
     340: ea45 0002    	orr.w	r0, r5, r2
     344: 4553         	cmp	r3, r10
     346: f04f 0228    	mov.w	r2, #0x28
     34a: bf08         	it	eq
     34c: 2204         	moveq	r2, #0x4
     34e: 4551         	cmp	r1, r10
     350: e69f         	b	0x92 <harness_main+0x26> @ imm = #-0x2c2
     352: bf00         	nop
     354: f1bc 0f04    	cmp.w	r12, #0x4
     358: d1ee         	bne	0x338 <harness_main+0x2cc> @ imm = #-0x24
     35a: 6c70         	ldr	r0, [r6, #0x44]
     35c: 4281         	cmp	r1, r0
     35e: d1eb         	bne	0x338 <harness_main+0x2cc> @ imm = #-0x2a
     360: 1d30         	adds	r0, r6, #0x4
     362: e6a2         	b	0xaa <harness_main+0x3e> @ imm = #-0x2bc

00000364 <harness_injection_point_after_commit>:
     364: b580         	push	{r7, lr}
     366: 466f         	mov	r7, sp
     368: bf00         	nop
     36a: bd80         	pop	{r7, pc}

0000036c <harness_injection_point_after_mutation>:
     36c: b580         	push	{r7, lr}
     36e: 466f         	mov	r7, sp
     370: bf00         	nop
     372: bd80         	pop	{r7, pc}

00000374 <compiler_rt.arm.__aeabi_unwind_cpp_pr0>:
     374: b580         	push	{r7, lr}
     376: 466f         	mov	r7, sp
     378: bd80         	pop	{r7, pc}
     37a: d4d4         	bmi	0x326 <harness_main+0x2ba> @ imm = #-0x58
     37c: 9746         	str	r7, [sp, #0x118]
     37e: 8101         	strh	r1, [r0, #0x8]
     380: abb0         	add	r3, sp, #0x2c0
     382: 80f0         	strh	r0, [r6, #0x6]
     384: 0000         	movs	r0, r0
     386: 0000         	movs	r0, r0
