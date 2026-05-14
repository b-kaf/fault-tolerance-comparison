
zig-out/harness/checkpoint-harness-c-m4.elf:	file format elf32-littlearm

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
      68: 78 00 00 20  	.word	0x20000078
      6c: fe ca 05 c1  	.word	0xc105cafe
      70: bc 3e f2 35  	.word	0x35f23ebc

00000074 <harness_injection_point_after_mutation>:
      74: b580         	push	{r7, lr}
      76: 466f         	mov	r7, sp
      78: bf00         	nop
      7a: bd80         	pop	{r7, pc}
      7c: fe ca 05 c1  	.word	0xc105cafe
      80: bc 3e f2 35  	.word	0x35f23ebc

00000084 <harness_injection_point_after_commit>:
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
      9c: b099         	sub	sp, #0x64
      9e: f240 0900    	movw	r9, #0x0
      a2: f2c2 0900    	movt	r9, #0x2000
      a6: 2000         	movs	r0, #0x0
      a8: f240 0c04    	movw	r12, #0x4
      ac: f8c9 0000    	str.w	r0, [r9]
      b0: f2c2 0c00    	movt	r12, #0x2000
      b4: f8dc 0000    	ldr.w	r0, [r12]
      b8: a913         	add	r1, sp, #0x4c
      ba: f111 0f15    	cmn.w	r1, #0x15
      be: f200 831b    	bhi.w	0x6f8 <harness_main+0x664> @ imm = #0x636
      c2: f111 0f11    	cmn.w	r1, #0x11
      c6: f200 8317    	bhi.w	0x6f8 <harness_main+0x664> @ imm = #0x62e
      ca: f111 0f0d    	cmn.w	r1, #0xd
      ce: f200 8313    	bhi.w	0x6f8 <harness_main+0x664> @ imm = #0x626
      d2: f111 0f05    	cmn.w	r1, #0x5
      d6: f200 830f    	bhi.w	0x6f8 <harness_main+0x664> @ imm = #0x61e
      da: f111 0f09    	cmn.w	r1, #0x9
      de: f200 830b    	bhi.w	0x6f8 <harness_main+0x664> @ imm = #0x616
      e2: f111 0f05    	cmn.w	r1, #0x5
      e6: f04f 0200    	mov.w	r2, #0x0
      ea: f04f 0300    	mov.w	r3, #0x0
      ee: bf88         	it	hi
      f0: 2201         	movhi	r2, #0x1
      f2: f111 0f09    	cmn.w	r1, #0x9
      f6: bf88         	it	hi
      f8: 2301         	movhi	r3, #0x1
      fa: 431a         	orrs	r2, r3
      fc: 2300         	movs	r3, #0x0
      fe: f111 0f0d    	cmn.w	r1, #0xd
     102: bf88         	it	hi
     104: 2301         	movhi	r3, #0x1
     106: 431a         	orrs	r2, r3
     108: 2300         	movs	r3, #0x0
     10a: f111 0f11    	cmn.w	r1, #0x11
     10e: bf88         	it	hi
     110: 2301         	movhi	r3, #0x1
     112: 431a         	orrs	r2, r3
     114: 2300         	movs	r3, #0x0
     116: f111 0f15    	cmn.w	r1, #0x15
     11a: bf88         	it	hi
     11c: 2301         	movhi	r3, #0x1
     11e: 431a         	orrs	r2, r3
     120: 9202         	str	r2, [sp, #0x8]
     122: f111 0f05    	cmn.w	r1, #0x5
     126: f04f 0200    	mov.w	r2, #0x0
     12a: f04f 0300    	mov.w	r3, #0x0
     12e: bf88         	it	hi
     130: 2201         	movhi	r2, #0x1
     132: f111 0f09    	cmn.w	r1, #0x9
     136: bf88         	it	hi
     138: 2301         	movhi	r3, #0x1
     13a: 431a         	orrs	r2, r3
     13c: 2300         	movs	r3, #0x0
     13e: f111 0f0d    	cmn.w	r1, #0xd
     142: bf88         	it	hi
     144: 2301         	movhi	r3, #0x1
     146: 431a         	orrs	r2, r3
     148: 2300         	movs	r3, #0x0
     14a: f111 0f11    	cmn.w	r1, #0x11
     14e: bf88         	it	hi
     150: 2301         	movhi	r3, #0x1
     152: 431a         	orrs	r2, r3
     154: 2300         	movs	r3, #0x0
     156: f111 0f15    	cmn.w	r1, #0x15
     15a: bf88         	it	hi
     15c: 2301         	movhi	r3, #0x1
     15e: 431a         	orrs	r2, r3
     160: 9203         	str	r2, [sp, #0xc]
     162: f111 0f05    	cmn.w	r1, #0x5
     166: f04f 0200    	mov.w	r2, #0x0
     16a: f04f 0300    	mov.w	r3, #0x0
     16e: bf88         	it	hi
     170: 2201         	movhi	r2, #0x1
     172: f111 0f09    	cmn.w	r1, #0x9
     176: bf88         	it	hi
     178: 2301         	movhi	r3, #0x1
     17a: 431a         	orrs	r2, r3
     17c: 2300         	movs	r3, #0x0
     17e: f111 0f0d    	cmn.w	r1, #0xd
     182: bf88         	it	hi
     184: 2301         	movhi	r3, #0x1
     186: 431a         	orrs	r2, r3
     188: 2300         	movs	r3, #0x0
     18a: f111 0f11    	cmn.w	r1, #0x11
     18e: bf88         	it	hi
     190: 2301         	movhi	r3, #0x1
     192: 431a         	orrs	r2, r3
     194: 2300         	movs	r3, #0x0
     196: f111 0f15    	cmn.w	r1, #0x15
     19a: bf88         	it	hi
     19c: 2301         	movhi	r3, #0x1
     19e: 431a         	orrs	r2, r3
     1a0: 9201         	str	r2, [sp, #0x4]
     1a2: f111 0f05    	cmn.w	r1, #0x5
     1a6: f04f 0200    	mov.w	r2, #0x0
     1aa: f04f 0300    	mov.w	r3, #0x0
     1ae: bf88         	it	hi
     1b0: 2201         	movhi	r2, #0x1
     1b2: f111 0f09    	cmn.w	r1, #0x9
     1b6: bf88         	it	hi
     1b8: 2301         	movhi	r3, #0x1
     1ba: 431a         	orrs	r2, r3
     1bc: 2300         	movs	r3, #0x0
     1be: f111 0f0d    	cmn.w	r1, #0xd
     1c2: bf88         	it	hi
     1c4: 2301         	movhi	r3, #0x1
     1c6: 431a         	orrs	r2, r3
     1c8: f111 0f11    	cmn.w	r1, #0x11
     1cc: f04f 0300    	mov.w	r3, #0x0
     1d0: bf88         	it	hi
     1d2: 2301         	movhi	r3, #0x1
     1d4: f111 0f15    	cmn.w	r1, #0x15
     1d8: f04f 0100    	mov.w	r1, #0x0
     1dc: ea42 0203    	orr.w	r2, r2, r3
     1e0: bf88         	it	hi
     1e2: 2101         	movhi	r1, #0x1
     1e4: f240 0a24    	movw	r10, #0x24
     1e8: f240 0828    	movw	r8, #0x28
     1ec: f04f 0b00    	mov.w	r11, #0x0
     1f0: 4311         	orrs	r1, r2
     1f2: f2c2 0a00    	movt	r10, #0x2000
     1f6: f2c2 0800    	movt	r8, #0x2000
     1fa: 9100         	str	r1, [sp]
     1fc: e021         	b	0x242 <harness_main+0x1ae> @ imm = #0x42
     1fe: 9c04         	ldr	r4, [sp, #0x10]
     200: 4306         	orrs	r6, r0
     202: f240 0574    	movw	r5, #0x74
     206: f2c2 0500    	movt	r5, #0x2000
     20a: 42a3         	cmp	r3, r4
     20c: 4628         	mov	r0, r5
     20e: f240 0370    	movw	r3, #0x70
     212: f2c2 0300    	movt	r3, #0x2000
     216: bf08         	it	eq
     218: 4618         	moveq	r0, r3
     21a: 42a2         	cmp	r2, r4
     21c: bf18         	it	ne
     21e: 4628         	movne	r0, r5
     220: 2900         	cmp	r1, #0x0
     222: bf18         	it	ne
     224: 4628         	movne	r0, r5
     226: 2e00         	cmp	r6, #0x0
     228: bf18         	it	ne
     22a: 4628         	movne	r0, r5
     22c: 6801         	ldr	r1, [r0]
     22e: 3101         	adds	r1, #0x1
     230: 6001         	str	r1, [r0]
     232: f7ff ff27    	bl	0x84 <harness_injection_point_after_commit> @ imm = #-0x1b2
     236: f240 0c04    	movw	r12, #0x4
     23a: f2c2 0c00    	movt	r12, #0x2000
     23e: f8dc 0000    	ldr.w	r0, [r12]
     242: 1c41         	adds	r1, r0, #0x1
     244: 2225         	movs	r2, #0x25
     246: f247 3591    	movw	r5, #0x7391
     24a: 434a         	muls	r2, r1, r2
     24c: f6c5 559f    	movt	r5, #0x5d9f
     250: fba2 3605    	umull	r3, r6, r2, r5
     254: 2335         	movs	r3, #0x35
     256: 4358         	muls	r0, r3, r0
     258: f500 7084    	add.w	r0, r0, #0x108
     25c: fba0 3505    	umull	r3, r5, r0, r5
     260: 0a33         	lsrs	r3, r6, #0x8
     262: f44f 762f    	mov.w	r6, #0x2bc
     266: fb03 2216    	mls	r2, r3, r6, r2
     26a: 0a2b         	lsrs	r3, r5, #0x8
     26c: fb03 0016    	mls	r0, r3, r6, r0
     270: f8cc 1000    	str.w	r1, [r12]
     274: f240 0108    	movw	r1, #0x8
     278: f102 0464    	add.w	r4, r2, #0x64
     27c: f2c2 0100    	movt	r1, #0x2000
     280: f100 0364    	add.w	r3, r0, #0x64
     284: f247 1080    	movw	r0, #0x7180
     288: 600c         	str	r4, [r1]
     28a: f240 010c    	movw	r1, #0xc
     28e: f2c8 108b    	movt	r0, #0x818b
     292: f240 1293    	movw	r2, #0x193
     296: f2c2 0100    	movt	r1, #0x2000
     29a: 4060         	eors	r0, r4
     29c: f2c0 1200    	movt	r2, #0x100
     2a0: 9305         	str	r3, [sp, #0x14]
     2a2: 600b         	str	r3, [r1]
     2a4: f240 0110    	movw	r1, #0x10
     2a8: 4350         	muls	r0, r2, r0
     2aa: f2c2 0100    	movt	r1, #0x2000
     2ae: ea4f 60f0    	ror.w	r0, r0, #0x1b
     2b2: f8c1 b000    	str.w	r11, [r1]
     2b6: f240 0114    	movw	r1, #0x14
     2ba: 4350         	muls	r0, r2, r0
     2bc: f44f 7e7a    	mov.w	lr, #0x3e8
     2c0: f2c2 0100    	movt	r1, #0x2000
     2c4: ea8e 60f0    	eor.w	r0, lr, r0, ror #27
     2c8: f8c1 b000    	str.w	r11, [r1]
     2cc: f240 0118    	movw	r1, #0x18
     2d0: 4350         	muls	r0, r2, r0
     2d2: 2606         	movs	r6, #0x6
     2d4: f2c2 0100    	movt	r1, #0x2000
     2d8: ea86 60f0    	eor.w	r0, r6, r0, ror #27
     2dc: f8c1 b000    	str.w	r11, [r1]
     2e0: f240 011c    	movw	r1, #0x1c
     2e4: 4350         	muls	r0, r2, r0
     2e6: 2510         	movs	r5, #0x10
     2e8: f2c2 0100    	movt	r1, #0x2000
     2ec: ea85 60f0    	eor.w	r0, r5, r0, ror #27
     2f0: f8c1 b000    	str.w	r11, [r1]
     2f4: f240 0120    	movw	r1, #0x20
     2f8: 4350         	muls	r0, r2, r0
     2fa: f2c2 0100    	movt	r1, #0x2000
     2fe: ea4f 60f0    	ror.w	r0, r0, #0x1b
     302: f8c1 b000    	str.w	r11, [r1]
     306: 2101         	movs	r1, #0x1
     308: f8ca b000    	str.w	r11, [r10]
     30c: 9113         	str	r1, [sp, #0x4c]
     30e: aa0e         	add	r2, sp, #0x38
     310: e9cd 100c    	strd	r1, r0, [sp, #48]
     314: a906         	add	r1, sp, #0x18
     316: e9cd b411    	strd	r11, r4, [sp, #68]
     31a: e882 4060    	stm.w	r2, {r5, r6, lr}
     31e: 9404         	str	r4, [sp, #0x10]
     320: e9cd b40a    	strd	r11, r4, [sp, #40]
     324: e881 4061    	stm.w	r1, {r0, r5, r6, lr}
     328: 9813         	ldr	r0, [sp, #0x4c]
     32a: 2204         	movs	r2, #0x4
     32c: f8c8 0000    	str.w	r0, [r8]
     330: 9e12         	ldr	r6, [sp, #0x48]
     332: 2802         	cmp	r0, #0x2
     334: f8c8 6004    	str.w	r6, [r8, #0x4]
     338: 9911         	ldr	r1, [sp, #0x44]
     33a: f8c8 1008    	str.w	r1, [r8, #0x8]
     33e: f8dd b040    	ldr.w	r11, [sp, #0x40]
     342: f8c8 b00c    	str.w	r11, [r8, #0xc]
     346: f8dd e03c    	ldr.w	lr, [sp, #0x3c]
     34a: f8c8 e010    	str.w	lr, [r8, #0x10]
     34e: f8dd a038    	ldr.w	r10, [sp, #0x38]
     352: f8c8 a014    	str.w	r10, [r8, #0x14]
     356: f8dd c034    	ldr.w	r12, [sp, #0x34]
     35a: f8c8 c018    	str.w	r12, [r8, #0x18]
     35e: 9c0c         	ldr	r4, [sp, #0x30]
     360: f8c8 401c    	str.w	r4, [r8, #0x1c]
     364: 9c0b         	ldr	r4, [sp, #0x2c]
     366: f8c8 4020    	str.w	r4, [r8, #0x20]
     36a: 9c0a         	ldr	r4, [sp, #0x28]
     36c: f8c8 4024    	str.w	r4, [r8, #0x24]
     370: 9c09         	ldr	r4, [sp, #0x24]
     372: f8c8 4028    	str.w	r4, [r8, #0x28]
     376: 9c08         	ldr	r4, [sp, #0x20]
     378: f8c8 402c    	str.w	r4, [r8, #0x2c]
     37c: 9c07         	ldr	r4, [sp, #0x1c]
     37e: f8c8 4030    	str.w	r4, [r8, #0x30]
     382: 9c06         	ldr	r4, [sp, #0x18]
     384: f8c8 4034    	str.w	r4, [r8, #0x34]
     388: f8c9 2000    	str.w	r2, [r9]
     38c: bf98         	it	ls
     38e: 4559         	cmpls	r1, r11
     390: d952         	bls	0x438 <harness_main+0x3a4> @ imm = #0xa4
     392: 9a03         	ldr	r2, [sp, #0xc]
     394: 9b05         	ldr	r3, [sp, #0x14]
     396: 2a00         	cmp	r2, #0x0
     398: f8c8 3004    	str.w	r3, [r8, #0x4]
     39c: f040 81ac    	bne.w	0x6f8 <harness_main+0x664> @ imm = #0x358
     3a0: f649 52c5    	movw	r2, #0x9dc5
     3a4: f2c8 121c    	movt	r2, #0x811c
     3a8: 4050         	eors	r0, r2
     3aa: f240 1293    	movw	r2, #0x193
     3ae: f2c0 1200    	movt	r2, #0x100
     3b2: 4350         	muls	r0, r2, r0
     3b4: ea83 60f0    	eor.w	r0, r3, r0, ror #27
     3b8: 4350         	muls	r0, r2, r0
     3ba: ea81 60f0    	eor.w	r0, r1, r0, ror #27
     3be: 4350         	muls	r0, r2, r0
     3c0: ea8b 60f0    	eor.w	r0, r11, r0, ror #27
     3c4: 4350         	muls	r0, r2, r0
     3c6: ea8e 60f0    	eor.w	r0, lr, r0, ror #27
     3ca: 4350         	muls	r0, r2, r0
     3cc: ea8a 60f0    	eor.w	r0, r10, r0, ror #27
     3d0: 4350         	muls	r0, r2, r0
     3d2: ea4f 60f0    	ror.w	r0, r0, #0x1b
     3d6: f8c8 0018    	str.w	r0, [r8, #0x18]
     3da: f240 0060    	movw	r0, #0x60
     3de: f2c2 0000    	movt	r0, #0x2000
     3e2: 6003         	str	r3, [r0]
     3e4: f8d8 0020    	ldr.w	r0, [r8, #0x20]
     3e8: f240 016c    	movw	r1, #0x6c
     3ec: f2c2 0100    	movt	r1, #0x2000
     3f0: 6008         	str	r0, [r1]
     3f2: 2005         	movs	r0, #0x5
     3f4: f8c9 0000    	str.w	r0, [r9]
     3f8: f7ff fe3c    	bl	0x74 <harness_injection_point_after_mutation> @ imm = #-0x388
     3fc: f240 0064    	movw	r0, #0x64
     400: f2c2 0000    	movt	r0, #0x2000
     404: 6802         	ldr	r2, [r0]
     406: f240 0068    	movw	r0, #0x68
     40a: f2c2 0000    	movt	r0, #0x2000
     40e: 6800         	ldr	r0, [r0]
     410: f1a2 010a    	sub.w	r1, r2, #0xa
     414: f240 0a24    	movw	r10, #0x24
     418: 2905         	cmp	r1, #0x5
     41a: f2c2 0a00    	movt	r10, #0x2000
     41e: f04f 0b00    	mov.w	r11, #0x0
     422: f8ca 2000    	str.w	r2, [r10]
     426: d855         	bhi	0x4d4 <harness_main+0x440> @ imm = #0xaa
     428: e8df f001    	tbb	[pc, r1]
     42c: 03 49 40 46  	.word	0x46404903
     430: 3c 4c        	.short	0x4c3c
     432: f8c8 0004    	str.w	r0, [r8, #0x4]
     436: e04d         	b	0x4d4 <harness_main+0x440> @ imm = #0x9a
     438: 428e         	cmp	r6, r1
     43a: d3aa         	blo	0x392 <harness_main+0x2fe> @ imm = #-0xac
     43c: 455e         	cmp	r6, r11
     43e: d8a8         	bhi	0x392 <harness_main+0x2fe> @ imm = #-0xb0
     440: 45d6         	cmp	lr, r10
     442: d8a6         	bhi	0x392 <harness_main+0x2fe> @ imm = #-0xb4
     444: 9a02         	ldr	r2, [sp, #0x8]
     446: 2a00         	cmp	r2, #0x0
     448: f040 8156    	bne.w	0x6f8 <harness_main+0x664> @ imm = #0x2ac
     44c: f649 52c5    	movw	r2, #0x9dc5
     450: f2c8 121c    	movt	r2, #0x811c
     454: ea80 0402    	eor.w	r4, r0, r2
     458: f240 1293    	movw	r2, #0x193
     45c: f2c0 1200    	movt	r2, #0x100
     460: 4354         	muls	r4, r2, r4
     462: ea86 66f4    	eor.w	r6, r6, r4, ror #27
     466: 4356         	muls	r6, r2, r6
     468: ea81 66f6    	eor.w	r6, r1, r6, ror #27
     46c: 4356         	muls	r6, r2, r6
     46e: ea8b 66f6    	eor.w	r6, r11, r6, ror #27
     472: 4356         	muls	r6, r2, r6
     474: ea8e 66f6    	eor.w	r6, lr, r6, ror #27
     478: 4356         	muls	r6, r2, r6
     47a: ea8a 66f6    	eor.w	r6, r10, r6, ror #27
     47e: 4356         	muls	r6, r2, r6
     480: ebbc 6ff6    	cmp.w	r12, r6, ror #27
     484: f47f af85    	bne.w	0x392 <harness_main+0x2fe> @ imm = #-0xf6
     488: 4644         	mov	r4, r8
     48a: 464a         	mov	r2, r9
     48c: e8b4 0248    	ldm.w	r4!, {r3, r6, r9}
     490: f108 0c1c    	add.w	r12, r8, #0x1c
     494: e8ac 0248    	stm.w	r12!, {r3, r6, r9}
     498: 4691         	mov	r9, r2
     49a: e894 006c    	ldm.w	r4, {r2, r3, r5, r6}
     49e: e88c 006c    	stm.w	r12, {r2, r3, r5, r6}
     4a2: e776         	b	0x392 <harness_main+0x2fe> @ imm = #-0x114
     4a4: f8d8 1034    	ldr.w	r1, [r8, #0x34]
     4a8: 4048         	eors	r0, r1
     4aa: e011         	b	0x4d0 <harness_main+0x43c> @ imm = #0x22
     4ac: f8d8 1018    	ldr.w	r1, [r8, #0x18]
     4b0: 4048         	eors	r0, r1
     4b2: f8c8 0018    	str.w	r0, [r8, #0x18]
     4b6: e00d         	b	0x4d4 <harness_main+0x440> @ imm = #0x1a
     4b8: f8c8 0020    	str.w	r0, [r8, #0x20]
     4bc: e00a         	b	0x4d4 <harness_main+0x440> @ imm = #0x14
     4be: f8c8 0010    	str.w	r0, [r8, #0x10]
     4c2: e007         	b	0x4d4 <harness_main+0x440> @ imm = #0xe
     4c4: f8d8 1034    	ldr.w	r1, [r8, #0x34]
     4c8: f8c8 0004    	str.w	r0, [r8, #0x4]
     4cc: f081 0010    	eor	r0, r1, #0x10
     4d0: f8c8 0034    	str.w	r0, [r8, #0x34]
     4d4: f240 0064    	movw	r0, #0x64
     4d8: f2c2 0000    	movt	r0, #0x2000
     4dc: f8c0 b000    	str.w	r11, [r0]
     4e0: e9d8 3100    	ldrd	r3, r1, [r8]
     4e4: f240 0260    	movw	r2, #0x60
     4e8: f2c2 0200    	movt	r2, #0x2000
     4ec: f8d8 0020    	ldr.w	r0, [r8, #0x20]
     4f0: 6011         	str	r1, [r2]
     4f2: f240 026c    	movw	r2, #0x6c
     4f6: f2c2 0200    	movt	r2, #0x2000
     4fa: 6010         	str	r0, [r2]
     4fc: 2206         	movs	r2, #0x6
     4fe: 2b02         	cmp	r3, #0x2
     500: f8c9 2000    	str.w	r2, [r9]
     504: d846         	bhi	0x594 <harness_main+0x500> @ imm = #0x8c
     506: e9d8 6202    	ldrd	r6, r2, [r8, #8]
     50a: 4296         	cmp	r6, r2
     50c: d902         	bls	0x514 <harness_main+0x480> @ imm = #0x4
     50e: 2205         	movs	r2, #0x5
     510: e040         	b	0x594 <harness_main+0x500> @ imm = #0x80
     512: bf00         	nop
     514: 42b1         	cmp	r1, r6
     516: d201         	bhs	0x51c <harness_main+0x488> @ imm = #0x2
     518: 2201         	movs	r2, #0x1
     51a: e03b         	b	0x594 <harness_main+0x500> @ imm = #0x76
     51c: 4291         	cmp	r1, r2
     51e: d901         	bls	0x524 <harness_main+0x490> @ imm = #0x2
     520: 2202         	movs	r2, #0x2
     522: e037         	b	0x594 <harness_main+0x500> @ imm = #0x6e
     524: e9d8 4e04    	ldrd	r4, lr, [r8, #16]
     528: 4574         	cmp	r4, lr
     52a: d901         	bls	0x530 <harness_main+0x49c> @ imm = #0x2
     52c: 2203         	movs	r2, #0x3
     52e: e031         	b	0x594 <harness_main+0x500> @ imm = #0x62
     530: 9d01         	ldr	r5, [sp, #0x4]
     532: 2d00         	cmp	r5, #0x0
     534: f040 80e0    	bne.w	0x6f8 <harness_main+0x664> @ imm = #0x1c0
     538: f649 55c5    	movw	r5, #0x9dc5
     53c: f2c8 151c    	movt	r5, #0x811c
     540: 406b         	eors	r3, r5
     542: f240 1593    	movw	r5, #0x193
     546: f2c0 1500    	movt	r5, #0x100
     54a: 436b         	muls	r3, r5, r3
     54c: ea81 63f3    	eor.w	r3, r1, r3, ror #27
     550: 436b         	muls	r3, r5, r3
     552: ea86 63f3    	eor.w	r3, r6, r3, ror #27
     556: 436b         	muls	r3, r5, r3
     558: ea82 62f3    	eor.w	r2, r2, r3, ror #27
     55c: 436a         	muls	r2, r5, r2
     55e: ea84 62f2    	eor.w	r2, r4, r2, ror #27
     562: 436a         	muls	r2, r5, r2
     564: f8d8 c018    	ldr.w	r12, [r8, #0x18]
     568: ea8e 62f2    	eor.w	r2, lr, r2, ror #27
     56c: 436a         	muls	r2, r5, r2
     56e: ebbc 6ff2    	cmp.w	r12, r2, ror #27
     572: d10d         	bne	0x590 <harness_main+0x4fc> @ imm = #0x1a
     574: 4642         	mov	r2, r8
     576: ca68         	ldm	r2!, {r3, r5, r6}
     578: f108 001c    	add.w	r0, r8, #0x1c
     57c: c068         	stm	r0!, {r3, r5, r6}
     57e: e892 0078    	ldm.w	r2, {r3, r4, r5, r6}
     582: 2200         	movs	r2, #0x0
     584: c078         	stm	r0!, {r3, r4, r5, r6}
     586: f8d8 0020    	ldr.w	r0, [r8, #0x20]
     58a: 2500         	movs	r5, #0x0
     58c: 2300         	movs	r3, #0x0
     58e: e057         	b	0x640 <harness_main+0x5ac> @ imm = #0xae
     590: 2204         	movs	r2, #0x4
     592: bf00         	nop
     594: f8d8 601c    	ldr.w	r6, [r8, #0x1c]
     598: 2e02         	cmp	r6, #0x2
     59a: d903         	bls	0x5a4 <harness_main+0x510> @ imm = #0x6
     59c: 2306         	movs	r3, #0x6
     59e: 2502         	movs	r5, #0x2
     5a0: e04e         	b	0x640 <harness_main+0x5ac> @ imm = #0x9c
     5a2: bf00         	nop
     5a4: e9d8 5309    	ldrd	r5, r3, [r8, #36]
     5a8: 429d         	cmp	r5, r3
     5aa: d903         	bls	0x5b4 <harness_main+0x520> @ imm = #0x6
     5ac: 2305         	movs	r3, #0x5
     5ae: 2502         	movs	r5, #0x2
     5b0: e046         	b	0x640 <harness_main+0x5ac> @ imm = #0x8c
     5b2: bf00         	nop
     5b4: 42a8         	cmp	r0, r5
     5b6: d202         	bhs	0x5be <harness_main+0x52a> @ imm = #0x4
     5b8: 2301         	movs	r3, #0x1
     5ba: 2502         	movs	r5, #0x2
     5bc: e040         	b	0x640 <harness_main+0x5ac> @ imm = #0x80
     5be: 4298         	cmp	r0, r3
     5c0: d902         	bls	0x5c8 <harness_main+0x534> @ imm = #0x4
     5c2: 2502         	movs	r5, #0x2
     5c4: 2302         	movs	r3, #0x2
     5c6: e03b         	b	0x640 <harness_main+0x5ac> @ imm = #0x76
     5c8: e9d8 ac0b    	ldrd	r10, r12, [r8, #44]
     5cc: 45e2         	cmp	r10, r12
     5ce: d901         	bls	0x5d4 <harness_main+0x540> @ imm = #0x2
     5d0: 2303         	movs	r3, #0x3
     5d2: e030         	b	0x636 <harness_main+0x5a2> @ imm = #0x60
     5d4: 9c00         	ldr	r4, [sp]
     5d6: 2c00         	cmp	r4, #0x0
     5d8: f040 808e    	bne.w	0x6f8 <harness_main+0x664> @ imm = #0x11c
     5dc: f649 54c5    	movw	r4, #0x9dc5
     5e0: f2c8 141c    	movt	r4, #0x811c
     5e4: 4066         	eors	r6, r4
     5e6: f240 1493    	movw	r4, #0x193
     5ea: f2c0 1400    	movt	r4, #0x100
     5ee: 4366         	muls	r6, r4, r6
     5f0: ea80 66f6    	eor.w	r6, r0, r6, ror #27
     5f4: 4366         	muls	r6, r4, r6
     5f6: ea85 65f6    	eor.w	r5, r5, r6, ror #27
     5fa: 4365         	muls	r5, r4, r5
     5fc: ea83 63f5    	eor.w	r3, r3, r5, ror #27
     600: 4363         	muls	r3, r4, r3
     602: ea8a 63f3    	eor.w	r3, r10, r3, ror #27
     606: 4363         	muls	r3, r4, r3
     608: f8d8 e034    	ldr.w	lr, [r8, #0x34]
     60c: ea8c 63f3    	eor.w	r3, r12, r3, ror #27
     610: 4363         	muls	r3, r4, r3
     612: ebbe 6ff3    	cmp.w	lr, r3, ror #27
     616: d10d         	bne	0x634 <harness_main+0x5a0> @ imm = #0x1a
     618: f108 0c1c    	add.w	r12, r8, #0x1c
     61c: e8bc 0070    	ldm.w	r12!, {r4, r5, r6}
     620: 4643         	mov	r3, r8
     622: c370         	stm	r3!, {r4, r5, r6}
     624: e89c 0072    	ldm.w	r12, {r1, r4, r5, r6}
     628: c372         	stm	r3!, {r1, r4, r5, r6}
     62a: f8d8 1004    	ldr.w	r1, [r8, #0x4]
     62e: 2300         	movs	r3, #0x0
     630: 2501         	movs	r5, #0x1
     632: e001         	b	0x638 <harness_main+0x5a4> @ imm = #0x2
     634: 2304         	movs	r3, #0x4
     636: 2502         	movs	r5, #0x2
     638: f240 0a24    	movw	r10, #0x24
     63c: f2c2 0a00    	movt	r10, #0x2000
     640: f240 0618    	movw	r6, #0x18
     644: f240 041c    	movw	r4, #0x1c
     648: f2c2 0600    	movt	r6, #0x2000
     64c: f2c2 0400    	movt	r4, #0x2000
     650: 6035         	str	r5, [r6]
     652: 6022         	str	r2, [r4]
     654: f240 0220    	movw	r2, #0x20
     658: f2c2 0200    	movt	r2, #0x2000
     65c: 6013         	str	r3, [r2]
     65e: f240 0360    	movw	r3, #0x60
     662: f240 0c6c    	movw	r12, #0x6c
     666: f2c2 0300    	movt	r3, #0x2000
     66a: f2c2 0c00    	movt	r12, #0x2000
     66e: 6019         	str	r1, [r3]
     670: f8cc 0000    	str.w	r0, [r12]
     674: 6818         	ldr	r0, [r3]
     676: f240 0110    	movw	r1, #0x10
     67a: f2c2 0100    	movt	r1, #0x2000
     67e: 6008         	str	r0, [r1]
     680: 2007         	movs	r0, #0x7
     682: f8c9 0000    	str.w	r0, [r9]
     686: f8da 5000    	ldr.w	r5, [r10]
     68a: 6836         	ldr	r6, [r6]
     68c: 6820         	ldr	r0, [r4]
     68e: 6811         	ldr	r1, [r2]
     690: 681a         	ldr	r2, [r3]
     692: f8dc 3000    	ldr.w	r3, [r12]
     696: 3d0a         	subs	r5, #0xa
     698: 2d05         	cmp	r5, #0x5
     69a: d81c         	bhi	0x6d6 <harness_main+0x642> @ imm = #0x38
     69c: e8df f005    	tbb	[pc, r5]
     6a0: 08 0d 03 1b  	.word	0x1b030d08
     6a4: 1b 12        	.short	0x121b
     6a6: f086 0601    	eor	r6, r6, #0x1
     6aa: f080 0004    	eor	r0, r0, #0x4
     6ae: e5a6         	b	0x1fe <harness_main+0x16a> @ imm = #-0x4b4
     6b0: f086 0601    	eor	r6, r6, #0x1
     6b4: f080 0002    	eor	r0, r0, #0x2
     6b8: e5a1         	b	0x1fe <harness_main+0x16a> @ imm = #-0x4be
     6ba: f086 0601    	eor	r6, r6, #0x1
     6be: f080 0003    	eor	r0, r0, #0x3
     6c2: e59c         	b	0x1fe <harness_main+0x16a> @ imm = #-0x4c8
     6c4: 2e02         	cmp	r6, #0x2
     6c6: bf08         	it	eq
     6c8: 2802         	cmpeq	r0, #0x2
     6ca: d006         	beq	0x6da <harness_main+0x646> @ imm = #0xc
     6cc: f240 0074    	movw	r0, #0x74
     6d0: f2c2 0000    	movt	r0, #0x2000
     6d4: e5aa         	b	0x22c <harness_main+0x198> @ imm = #-0x4ac
     6d6: 9c05         	ldr	r4, [sp, #0x14]
     6d8: e592         	b	0x200 <harness_main+0x16c> @ imm = #-0x4dc
     6da: 2904         	cmp	r1, #0x4
     6dc: d1f6         	bne	0x6cc <harness_main+0x638> @ imm = #-0x14
     6de: f240 0068    	movw	r0, #0x68
     6e2: f2c2 0000    	movt	r0, #0x2000
     6e6: 6800         	ldr	r0, [r0]
     6e8: 4282         	cmp	r2, r0
     6ea: f240 0070    	movw	r0, #0x70
     6ee: f2c2 0000    	movt	r0, #0x2000
     6f2: f43f ad9b    	beq.w	0x22c <harness_main+0x198> @ imm = #-0x4ca
     6f6: e7e9         	b	0x6cc <harness_main+0x638> @ imm = #-0x2e
     6f8: defe         	trap
     6fa: d4d4         	bmi	0x6a6 <harness_main+0x612> @ imm = #-0x58

000006fc <compiler_rt.arm.__aeabi_unwind_cpp_pr0>:
     6fc: b580         	push	{r7, lr}
     6fe: 466f         	mov	r7, sp
     700: bd80         	pop	{r7, pc}
     702: d4d4         	bmi	0x6ae <harness_main+0x61a> @ imm = #-0x58
     704: 9746         	str	r7, [sp, #0x118]
     706: 8101         	strh	r1, [r0, #0x8]
     708: abb0         	add	r3, sp, #0x2c0
     70a: 80f0         	strh	r0, [r6, #0x6]
     70c: 0000         	movs	r0, r0
     70e: 0000         	movs	r0, r0
