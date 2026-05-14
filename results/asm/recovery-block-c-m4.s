
zig-out/harness/recovery-block-harness-c-m4.elf:	file format elf32-littlearm

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
      68: 80 00 00 20  	.word	0x20000080
      6c: fe ca 05 c1  	.word	0xc105cafe
      70: bc 3e f2 35  	.word	0x35f23ebc

00000074 <harness_injection_point_before_recovery>:
      74: b580         	push	{r7, lr}
      76: 466f         	mov	r7, sp
      78: bf00         	nop
      7a: bd80         	pop	{r7, pc}
      7c: fe ca 05 c1  	.word	0xc105cafe
      80: bc 3e f2 35  	.word	0x35f23ebc

00000084 <harness_injection_point_after_recovery>:
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
      9c: b0a3         	sub	sp, #0x8c
      9e: f240 0100    	movw	r1, #0x0
      a2: f2c2 0100    	movt	r1, #0x2000
      a6: 2000         	movs	r0, #0x0
      a8: f240 0b04    	movw	r11, #0x4
      ac: 6008         	str	r0, [r1]
      ae: f2c2 0b00    	movt	r11, #0x2000
      b2: f8db 0000    	ldr.w	r0, [r11]
      b6: a91d         	add	r1, sp, #0x74
      b8: f111 0f15    	cmn.w	r1, #0x15
      bc: f200 8537    	bhi.w	0xb2e <harness_main+0xa9a> @ imm = #0xa6e
      c0: f111 0f11    	cmn.w	r1, #0x11
      c4: f200 8533    	bhi.w	0xb2e <harness_main+0xa9a> @ imm = #0xa66
      c8: f111 0f0d    	cmn.w	r1, #0xd
      cc: f200 852f    	bhi.w	0xb2e <harness_main+0xa9a> @ imm = #0xa5e
      d0: f111 0f05    	cmn.w	r1, #0x5
      d4: f200 852b    	bhi.w	0xb2e <harness_main+0xa9a> @ imm = #0xa56
      d8: f111 0f09    	cmn.w	r1, #0x9
      dc: f200 8527    	bhi.w	0xb2e <harness_main+0xa9a> @ imm = #0xa4e
      e0: f111 0f05    	cmn.w	r1, #0x5
      e4: f04f 0200    	mov.w	r2, #0x0
      e8: f04f 0300    	mov.w	r3, #0x0
      ec: bf88         	it	hi
      ee: 2201         	movhi	r2, #0x1
      f0: f111 0f09    	cmn.w	r1, #0x9
      f4: bf88         	it	hi
      f6: 2301         	movhi	r3, #0x1
      f8: 431a         	orrs	r2, r3
      fa: 2300         	movs	r3, #0x0
      fc: f111 0f0d    	cmn.w	r1, #0xd
     100: bf88         	it	hi
     102: 2301         	movhi	r3, #0x1
     104: 431a         	orrs	r2, r3
     106: 2300         	movs	r3, #0x0
     108: f111 0f11    	cmn.w	r1, #0x11
     10c: bf88         	it	hi
     10e: 2301         	movhi	r3, #0x1
     110: 431a         	orrs	r2, r3
     112: 2300         	movs	r3, #0x0
     114: f111 0f15    	cmn.w	r1, #0x15
     118: bf88         	it	hi
     11a: 2301         	movhi	r3, #0x1
     11c: 431a         	orrs	r2, r3
     11e: 920c         	str	r2, [sp, #0x30]
     120: f640 3239    	movw	r2, #0xb39
     124: f2c0 0200    	movt	r2, #0x0
     128: f022 0201    	bic	r2, r2, #0x1
     12c: 920b         	str	r2, [sp, #0x2c]
     12e: f640 42bd    	movw	r2, #0xcbd
     132: f2c0 0200    	movt	r2, #0x0
     136: f022 0201    	bic	r2, r2, #0x1
     13a: 920a         	str	r2, [sp, #0x28]
     13c: f111 0f05    	cmn.w	r1, #0x5
     140: f04f 0200    	mov.w	r2, #0x0
     144: f04f 0300    	mov.w	r3, #0x0
     148: bf88         	it	hi
     14a: 2201         	movhi	r2, #0x1
     14c: f111 0f09    	cmn.w	r1, #0x9
     150: bf88         	it	hi
     152: 2301         	movhi	r3, #0x1
     154: 431a         	orrs	r2, r3
     156: 2300         	movs	r3, #0x0
     158: f111 0f0d    	cmn.w	r1, #0xd
     15c: bf88         	it	hi
     15e: 2301         	movhi	r3, #0x1
     160: 431a         	orrs	r2, r3
     162: 2300         	movs	r3, #0x0
     164: f111 0f11    	cmn.w	r1, #0x11
     168: bf88         	it	hi
     16a: 2301         	movhi	r3, #0x1
     16c: 431a         	orrs	r2, r3
     16e: 2300         	movs	r3, #0x0
     170: f111 0f15    	cmn.w	r1, #0x15
     174: bf88         	it	hi
     176: 2301         	movhi	r3, #0x1
     178: 431a         	orrs	r2, r3
     17a: 9209         	str	r2, [sp, #0x24]
     17c: f111 0f05    	cmn.w	r1, #0x5
     180: f04f 0200    	mov.w	r2, #0x0
     184: f04f 0300    	mov.w	r3, #0x0
     188: bf88         	it	hi
     18a: 2201         	movhi	r2, #0x1
     18c: f111 0f09    	cmn.w	r1, #0x9
     190: bf88         	it	hi
     192: 2301         	movhi	r3, #0x1
     194: 431a         	orrs	r2, r3
     196: 2300         	movs	r3, #0x0
     198: f111 0f0d    	cmn.w	r1, #0xd
     19c: bf88         	it	hi
     19e: 2301         	movhi	r3, #0x1
     1a0: 431a         	orrs	r2, r3
     1a2: 2300         	movs	r3, #0x0
     1a4: f111 0f11    	cmn.w	r1, #0x11
     1a8: bf88         	it	hi
     1aa: 2301         	movhi	r3, #0x1
     1ac: 431a         	orrs	r2, r3
     1ae: 2300         	movs	r3, #0x0
     1b0: f111 0f15    	cmn.w	r1, #0x15
     1b4: bf88         	it	hi
     1b6: 2301         	movhi	r3, #0x1
     1b8: 431a         	orrs	r2, r3
     1ba: 9205         	str	r2, [sp, #0x14]
     1bc: f111 0f05    	cmn.w	r1, #0x5
     1c0: f04f 0200    	mov.w	r2, #0x0
     1c4: f04f 0300    	mov.w	r3, #0x0
     1c8: bf88         	it	hi
     1ca: 2201         	movhi	r2, #0x1
     1cc: f111 0f09    	cmn.w	r1, #0x9
     1d0: bf88         	it	hi
     1d2: 2301         	movhi	r3, #0x1
     1d4: 431a         	orrs	r2, r3
     1d6: 2300         	movs	r3, #0x0
     1d8: f111 0f0d    	cmn.w	r1, #0xd
     1dc: bf88         	it	hi
     1de: 2301         	movhi	r3, #0x1
     1e0: 431a         	orrs	r2, r3
     1e2: 2300         	movs	r3, #0x0
     1e4: f111 0f11    	cmn.w	r1, #0x11
     1e8: bf88         	it	hi
     1ea: 2301         	movhi	r3, #0x1
     1ec: 431a         	orrs	r2, r3
     1ee: 2300         	movs	r3, #0x0
     1f0: f111 0f15    	cmn.w	r1, #0x15
     1f4: bf88         	it	hi
     1f6: 2301         	movhi	r3, #0x1
     1f8: 431a         	orrs	r2, r3
     1fa: 9208         	str	r2, [sp, #0x20]
     1fc: f111 0f05    	cmn.w	r1, #0x5
     200: f04f 0200    	mov.w	r2, #0x0
     204: f04f 0300    	mov.w	r3, #0x0
     208: bf88         	it	hi
     20a: 2201         	movhi	r2, #0x1
     20c: f111 0f09    	cmn.w	r1, #0x9
     210: bf88         	it	hi
     212: 2301         	movhi	r3, #0x1
     214: 431a         	orrs	r2, r3
     216: 2300         	movs	r3, #0x0
     218: f111 0f0d    	cmn.w	r1, #0xd
     21c: bf88         	it	hi
     21e: 2301         	movhi	r3, #0x1
     220: 431a         	orrs	r2, r3
     222: 2300         	movs	r3, #0x0
     224: f111 0f11    	cmn.w	r1, #0x11
     228: bf88         	it	hi
     22a: 2301         	movhi	r3, #0x1
     22c: 431a         	orrs	r2, r3
     22e: 2300         	movs	r3, #0x0
     230: f111 0f15    	cmn.w	r1, #0x15
     234: bf88         	it	hi
     236: 2301         	movhi	r3, #0x1
     238: 431a         	orrs	r2, r3
     23a: 9202         	str	r2, [sp, #0x8]
     23c: f111 0f05    	cmn.w	r1, #0x5
     240: f04f 0200    	mov.w	r2, #0x0
     244: f04f 0300    	mov.w	r3, #0x0
     248: bf88         	it	hi
     24a: 2201         	movhi	r2, #0x1
     24c: f111 0f09    	cmn.w	r1, #0x9
     250: bf88         	it	hi
     252: 2301         	movhi	r3, #0x1
     254: 431a         	orrs	r2, r3
     256: 2300         	movs	r3, #0x0
     258: f111 0f0d    	cmn.w	r1, #0xd
     25c: bf88         	it	hi
     25e: 2301         	movhi	r3, #0x1
     260: 431a         	orrs	r2, r3
     262: 2300         	movs	r3, #0x0
     264: f111 0f11    	cmn.w	r1, #0x11
     268: bf88         	it	hi
     26a: 2301         	movhi	r3, #0x1
     26c: 431a         	orrs	r2, r3
     26e: 2300         	movs	r3, #0x0
     270: f111 0f15    	cmn.w	r1, #0x15
     274: bf88         	it	hi
     276: 2301         	movhi	r3, #0x1
     278: 431a         	orrs	r2, r3
     27a: 9200         	str	r2, [sp]
     27c: f111 0f05    	cmn.w	r1, #0x5
     280: f04f 0200    	mov.w	r2, #0x0
     284: f04f 0300    	mov.w	r3, #0x0
     288: bf88         	it	hi
     28a: 2201         	movhi	r2, #0x1
     28c: f111 0f09    	cmn.w	r1, #0x9
     290: bf88         	it	hi
     292: 2301         	movhi	r3, #0x1
     294: 431a         	orrs	r2, r3
     296: 2300         	movs	r3, #0x0
     298: f111 0f0d    	cmn.w	r1, #0xd
     29c: bf88         	it	hi
     29e: 2301         	movhi	r3, #0x1
     2a0: 431a         	orrs	r2, r3
     2a2: 2300         	movs	r3, #0x0
     2a4: f111 0f11    	cmn.w	r1, #0x11
     2a8: bf88         	it	hi
     2aa: 2301         	movhi	r3, #0x1
     2ac: 431a         	orrs	r2, r3
     2ae: f640 535d    	movw	r3, #0xd5d
     2b2: f2c0 0300    	movt	r3, #0x0
     2b6: f023 0301    	bic	r3, r3, #0x1
     2ba: f111 0f15    	cmn.w	r1, #0x15
     2be: f04f 0100    	mov.w	r1, #0x0
     2c2: 9307         	str	r3, [sp, #0x1c]
     2c4: bf88         	it	hi
     2c6: 2101         	movhi	r1, #0x1
     2c8: 4311         	orrs	r1, r2
     2ca: 9101         	str	r1, [sp, #0x4]
     2cc: f241 0195    	movw	r1, #0x1095
     2d0: f2c0 0100    	movt	r1, #0x0
     2d4: f240 0930    	movw	r9, #0x30
     2d8: f021 0101    	bic	r1, r1, #0x1
     2dc: f2c2 0900    	movt	r9, #0x2000
     2e0: 9106         	str	r1, [sp, #0x18]
     2e2: e013         	b	0x30c <harness_main+0x278> @ imm = #0x26
     2e4: bf18         	it	ne
     2e6: 4618         	movne	r0, r3
     2e8: f1be 0f00    	cmp.w	lr, #0x0
     2ec: bf18         	it	ne
     2ee: 4618         	movne	r0, r3
     2f0: f1bc 0f02    	cmp.w	r12, #0x2
     2f4: bf18         	it	ne
     2f6: 4618         	movne	r0, r3
     2f8: 2900         	cmp	r1, #0x0
     2fa: bf18         	it	ne
     2fc: 4618         	movne	r0, r3
     2fe: 6801         	ldr	r1, [r0]
     300: 3101         	adds	r1, #0x1
     302: 6001         	str	r1, [r0]
     304: f7ff febe    	bl	0x84 <harness_injection_point_after_recovery> @ imm = #-0x284
     308: f8db 0000    	ldr.w	r0, [r11]
     30c: 3001         	adds	r0, #0x1
     30e: 211d         	movs	r1, #0x1d
     310: f247 3691    	movw	r6, #0x7391
     314: 4341         	muls	r1, r0, r1
     316: f6c5 569f    	movt	r6, #0x5d9f
     31a: fba1 2306    	umull	r2, r3, r1, r6
     31e: fba0 2606    	umull	r2, r6, r0, r6
     322: 0a1a         	lsrs	r2, r3, #0x8
     324: 0a33         	lsrs	r3, r6, #0x8
     326: f44f 762f    	mov.w	r6, #0x2bc
     32a: fb03 0316    	mls	r3, r3, r6, r0
     32e: fb02 1116    	mls	r1, r2, r6, r1
     332: 2225         	movs	r2, #0x25
     334: 435a         	muls	r2, r3, r2
     336: 3211         	adds	r2, #0x11
     338: b293         	uxth	r3, r2
     33a: f64b 353f    	movw	r5, #0xbb3f
     33e: 436b         	muls	r3, r5, r3
     340: 0e5b         	lsrs	r3, r3, #0x19
     342: fb03 2216    	mls	r2, r3, r6, r2
     346: f101 0a64    	add.w	r10, r1, #0x64
     34a: f102 0164    	add.w	r1, r2, #0x64
     34e: b28d         	uxth	r5, r1
     350: f247 1180    	movw	r1, #0x7180
     354: f2c8 118b    	movt	r1, #0x818b
     358: f240 1293    	movw	r2, #0x193
     35c: ea81 010a    	eor.w	r1, r1, r10
     360: f2c0 1200    	movt	r2, #0x100
     364: 4351         	muls	r1, r2, r1
     366: ea4f 61f1    	ror.w	r1, r1, #0x1b
     36a: 4351         	muls	r1, r2, r1
     36c: f44f 737a    	mov.w	r3, #0x3e8
     370: ea83 61f1    	eor.w	r1, r3, r1, ror #27
     374: 2600         	movs	r6, #0x0
     376: 4351         	muls	r1, r2, r1
     378: 901b         	str	r0, [sp, #0x6c]
     37a: 961c         	str	r6, [sp, #0x70]
     37c: f8cb 0000    	str.w	r0, [r11]
     380: f04f 0b06    	mov.w	r11, #0x6
     384: ea8b 60f1    	eor.w	r0, r11, r1, ror #27
     388: 4350         	muls	r0, r2, r0
     38a: 2110         	movs	r1, #0x10
     38c: ea81 60f0    	eor.w	r0, r1, r0, ror #27
     390: 4350         	muls	r0, r2, r0
     392: f240 0208    	movw	r2, #0x8
     396: f2c2 0200    	movt	r2, #0x2000
     39a: f8c2 a000    	str.w	r10, [r2]
     39e: f240 020c    	movw	r2, #0xc
     3a2: f2c2 0200    	movt	r2, #0x2000
     3a6: 950d         	str	r5, [sp, #0x34]
     3a8: 6015         	str	r5, [r2]
     3aa: f240 0210    	movw	r2, #0x10
     3ae: f2c2 0200    	movt	r2, #0x2000
     3b2: 6016         	str	r6, [r2]
     3b4: f240 0214    	movw	r2, #0x14
     3b8: f2c2 0200    	movt	r2, #0x2000
     3bc: 6016         	str	r6, [r2]
     3be: f240 0218    	movw	r2, #0x18
     3c2: f2c2 0200    	movt	r2, #0x2000
     3c6: 6016         	str	r6, [r2]
     3c8: f240 021c    	movw	r2, #0x1c
     3cc: f2c2 0200    	movt	r2, #0x2000
     3d0: 6016         	str	r6, [r2]
     3d2: f240 0220    	movw	r2, #0x20
     3d6: f2c2 0200    	movt	r2, #0x2000
     3da: 6016         	str	r6, [r2]
     3dc: f240 0224    	movw	r2, #0x24
     3e0: f2c2 0200    	movt	r2, #0x2000
     3e4: 6016         	str	r6, [r2]
     3e6: f240 0228    	movw	r2, #0x28
     3ea: f240 042c    	movw	r4, #0x2c
     3ee: ea4f 60f0    	ror.w	r0, r0, #0x1b
     3f2: f2c2 0200    	movt	r2, #0x2000
     3f6: f2c2 0400    	movt	r4, #0x2000
     3fa: 6016         	str	r6, [r2]
     3fc: 6026         	str	r6, [r4]
     3fe: 9015         	str	r0, [sp, #0x54]
     400: 900e         	str	r0, [sp, #0x38]
     402: 2001         	movs	r0, #0x1
     404: 901d         	str	r0, [sp, #0x74]
     406: aa18         	add	r2, sp, #0x60
     408: 9014         	str	r0, [sp, #0x50]
     40a: a811         	add	r0, sp, #0x44
     40c: e882 0448    	stm.w	r2, {r3, r6, r10}
     410: e9cd 1b16    	strd	r1, r11, [sp, #88]
     414: e880 0448    	stm.w	r0, {r3, r6, r10}
     418: e9cd 1b0f    	strd	r1, r11, [sp, #60]
     41c: 981d         	ldr	r0, [sp, #0x74]
     41e: f8c9 0000    	str.w	r0, [r9]
     422: 981a         	ldr	r0, [sp, #0x68]
     424: f8c9 0004    	str.w	r0, [r9, #0x4]
     428: 9919         	ldr	r1, [sp, #0x64]
     42a: f8c9 1008    	str.w	r1, [r9, #0x8]
     42e: 9918         	ldr	r1, [sp, #0x60]
     430: f8c9 100c    	str.w	r1, [r9, #0xc]
     434: 9917         	ldr	r1, [sp, #0x5c]
     436: f8c9 1010    	str.w	r1, [r9, #0x10]
     43a: 9916         	ldr	r1, [sp, #0x58]
     43c: f8c9 1014    	str.w	r1, [r9, #0x14]
     440: 9915         	ldr	r1, [sp, #0x54]
     442: f8c9 1018    	str.w	r1, [r9, #0x18]
     446: 9914         	ldr	r1, [sp, #0x50]
     448: f8c9 101c    	str.w	r1, [r9, #0x1c]
     44c: 9913         	ldr	r1, [sp, #0x4c]
     44e: f8c9 1020    	str.w	r1, [r9, #0x20]
     452: 9a12         	ldr	r2, [sp, #0x48]
     454: f8c9 2024    	str.w	r2, [r9, #0x24]
     458: 9a11         	ldr	r2, [sp, #0x44]
     45a: f8c9 2028    	str.w	r2, [r9, #0x28]
     45e: 9a10         	ldr	r2, [sp, #0x40]
     460: f8c9 202c    	str.w	r2, [r9, #0x2c]
     464: 9a0f         	ldr	r2, [sp, #0x3c]
     466: f8c9 2030    	str.w	r2, [r9, #0x30]
     46a: 9a0e         	ldr	r2, [sp, #0x38]
     46c: f8c9 2034    	str.w	r2, [r9, #0x34]
     470: f240 026c    	movw	r2, #0x6c
     474: f2c2 0200    	movt	r2, #0x2000
     478: 6010         	str	r0, [r2]
     47a: f240 0074    	movw	r0, #0x74
     47e: f2c2 0000    	movt	r0, #0x2000
     482: 6001         	str	r1, [r0]
     484: f240 0000    	movw	r0, #0x0
     488: f2c2 0000    	movt	r0, #0x2000
     48c: 2108         	movs	r1, #0x8
     48e: 6001         	str	r1, [r0]
     490: f7ff fdf0    	bl	0x74 <harness_injection_point_before_recovery> @ imm = #-0x420
     494: f240 0068    	movw	r0, #0x68
     498: f2c2 0000    	movt	r0, #0x2000
     49c: 6800         	ldr	r0, [r0]
     49e: 6020         	str	r0, [r4]
     4a0: e9d9 2e00    	ldrd	r2, lr, [r9]
     4a4: 2a02         	cmp	r2, #0x2
     4a6: d901         	bls	0x4ac <harness_main+0x418> @ imm = #0x2
     4a8: 2203         	movs	r2, #0x3
     4aa: e013         	b	0x4d4 <harness_main+0x440> @ imm = #0x26
     4ac: e9d9 3102    	ldrd	r3, r1, [r9, #8]
     4b0: 428b         	cmp	r3, r1
     4b2: d903         	bls	0x4bc <harness_main+0x428> @ imm = #0x6
     4b4: 2203         	movs	r2, #0x3
     4b6: f04f 0b05    	mov.w	r11, #0x5
     4ba: e00b         	b	0x4d4 <harness_main+0x440> @ imm = #0x16
     4bc: 459e         	cmp	lr, r3
     4be: d203         	bhs	0x4c8 <harness_main+0x434> @ imm = #0x6
     4c0: 2203         	movs	r2, #0x3
     4c2: f04f 0b01    	mov.w	r11, #0x1
     4c6: e005         	b	0x4d4 <harness_main+0x440> @ imm = #0xa
     4c8: 458e         	cmp	lr, r1
     4ca: f240 80ef    	bls.w	0x6ac <harness_main+0x618> @ imm = #0x1de
     4ce: 2203         	movs	r2, #0x3
     4d0: f04f 0b02    	mov.w	r11, #0x2
     4d4: 2100         	movs	r1, #0x0
     4d6: 2000         	movs	r0, #0x0
     4d8: f04f 0800    	mov.w	r8, #0x0
     4dc: f240 0c18    	movw	r12, #0x18
     4e0: f240 0614    	movw	r6, #0x14
     4e4: f2c2 0c00    	movt	r12, #0x2000
     4e8: f2c2 0600    	movt	r6, #0x2000
     4ec: f8cc 2000    	str.w	r2, [r12]
     4f0: 6032         	str	r2, [r6]
     4f2: f240 021c    	movw	r2, #0x1c
     4f6: f240 0520    	movw	r5, #0x20
     4fa: f2c2 0200    	movt	r2, #0x2000
     4fe: f2c2 0500    	movt	r5, #0x2000
     502: f8c2 b000    	str.w	r11, [r2]
     506: f8c5 8000    	str.w	r8, [r5]
     50a: f240 0824    	movw	r8, #0x24
     50e: f240 0b28    	movw	r11, #0x28
     512: f240 036c    	movw	r3, #0x6c
     516: f2c2 0800    	movt	r8, #0x2000
     51a: f2c2 0b00    	movt	r11, #0x2000
     51e: f2c2 0300    	movt	r3, #0x2000
     522: f8c8 0000    	str.w	r0, [r8]
     526: f8cb 1000    	str.w	r1, [r11]
     52a: f8c3 e000    	str.w	lr, [r3]
     52e: f8d9 0020    	ldr.w	r0, [r9, #0x20]
     532: f240 0474    	movw	r4, #0x74
     536: f2c2 0400    	movt	r4, #0x2000
     53a: 6020         	str	r0, [r4]
     53c: 6818         	ldr	r0, [r3]
     53e: f240 0110    	movw	r1, #0x10
     542: f2c2 0100    	movt	r1, #0x2000
     546: 6008         	str	r0, [r1]
     548: f240 0168    	movw	r1, #0x68
     54c: 2000         	movs	r0, #0x0
     54e: f2c2 0100    	movt	r1, #0x2000
     552: 6008         	str	r0, [r1]
     554: f240 0000    	movw	r0, #0x0
     558: f2c2 0000    	movt	r0, #0x2000
     55c: 210b         	movs	r1, #0xb
     55e: 6001         	str	r1, [r0]
     560: f240 002c    	movw	r0, #0x2c
     564: f2c2 0000    	movt	r0, #0x2000
     568: 6801         	ldr	r1, [r0]
     56a: f8dc 6000    	ldr.w	r6, [r12]
     56e: 6810         	ldr	r0, [r2]
     570: f8d5 c000    	ldr.w	r12, [r5]
     574: f8d8 e000    	ldr.w	lr, [r8]
     578: f8db 8000    	ldr.w	r8, [r11]
     57c: 681d         	ldr	r5, [r3]
     57e: 6824         	ldr	r4, [r4]
     580: 3914         	subs	r1, #0x14
     582: 2903         	cmp	r1, #0x3
     584: d859         	bhi	0x63a <harness_main+0x5a6> @ imm = #0xb2
     586: f240 0b04    	movw	r11, #0x4
     58a: f2c2 0b00    	movt	r11, #0x2000
     58e: e8df f001    	tbb	[pc, r1]
     592: 17 36 02 2d  	.word	0x2d023617
     596: f240 037c    	movw	r3, #0x7c
     59a: f086 0102    	eor	r1, r6, #0x2
     59e: f2c2 0300    	movt	r3, #0x2000
     5a2: 4301         	orrs	r1, r0
     5a4: 4618         	mov	r0, r3
     5a6: f240 0278    	movw	r2, #0x78
     5aa: 4554         	cmp	r4, r10
     5ac: f2c2 0200    	movt	r2, #0x2000
     5b0: bf08         	it	eq
     5b2: 4610         	moveq	r0, r2
     5b4: 4555         	cmp	r5, r10
     5b6: bf18         	it	ne
     5b8: 4618         	movne	r0, r3
     5ba: f1b8 0f04    	cmp.w	r8, #0x4
     5be: e691         	b	0x2e4 <harness_main+0x250> @ imm = #-0x2de
     5c0: f240 037c    	movw	r3, #0x7c
     5c4: f086 0101    	eor	r1, r6, #0x1
     5c8: 9e0d         	ldr	r6, [sp, #0x34]
     5ca: f2c2 0300    	movt	r3, #0x2000
     5ce: 4301         	orrs	r1, r0
     5d0: 4618         	mov	r0, r3
     5d2: f240 0278    	movw	r2, #0x78
     5d6: 42b4         	cmp	r4, r6
     5d8: f2c2 0200    	movt	r2, #0x2000
     5dc: bf08         	it	eq
     5de: 4610         	moveq	r0, r2
     5e0: 42b5         	cmp	r5, r6
     5e2: bf18         	it	ne
     5e4: 4618         	movne	r0, r3
     5e6: f1b8 0f00    	cmp.w	r8, #0x0
     5ea: e67b         	b	0x2e4 <harness_main+0x250> @ imm = #-0x30a
     5ec: 2e04         	cmp	r6, #0x4
     5ee: bf08         	it	eq
     5f0: 2800         	cmpeq	r0, #0x0
     5f2: d045         	beq	0x680 <harness_main+0x5ec> @ imm = #0x8a
     5f4: f240 007c    	movw	r0, #0x7c
     5f8: f2c2 0000    	movt	r0, #0x2000
     5fc: e67f         	b	0x2fe <harness_main+0x26a> @ imm = #-0x302
     5fe: f240 037c    	movw	r3, #0x7c
     602: f086 0101    	eor	r1, r6, #0x1
     606: 9e0d         	ldr	r6, [sp, #0x34]
     608: f2c2 0300    	movt	r3, #0x2000
     60c: 4301         	orrs	r1, r0
     60e: 4618         	mov	r0, r3
     610: f240 0278    	movw	r2, #0x78
     614: 42b4         	cmp	r4, r6
     616: f2c2 0200    	movt	r2, #0x2000
     61a: bf08         	it	eq
     61c: 4610         	moveq	r0, r2
     61e: 42b5         	cmp	r5, r6
     620: bf18         	it	ne
     622: 4618         	movne	r0, r3
     624: f1b8 0f00    	cmp.w	r8, #0x0
     628: bf18         	it	ne
     62a: 4618         	movne	r0, r3
     62c: f1be 0f00    	cmp.w	lr, #0x0
     630: bf18         	it	ne
     632: 4618         	movne	r0, r3
     634: f1bc 0f04    	cmp.w	r12, #0x4
     638: e65c         	b	0x2f4 <harness_main+0x260> @ imm = #-0x348
     63a: f240 037c    	movw	r3, #0x7c
     63e: ea46 0100    	orr.w	r1, r6, r0
     642: 9e0d         	ldr	r6, [sp, #0x34]
     644: f2c2 0300    	movt	r3, #0x2000
     648: 4618         	mov	r0, r3
     64a: f240 0278    	movw	r2, #0x78
     64e: 42b4         	cmp	r4, r6
     650: f2c2 0200    	movt	r2, #0x2000
     654: bf08         	it	eq
     656: 4610         	moveq	r0, r2
     658: 42b5         	cmp	r5, r6
     65a: bf18         	it	ne
     65c: 4618         	movne	r0, r3
     65e: f1b8 0f00    	cmp.w	r8, #0x0
     662: bf18         	it	ne
     664: 4618         	movne	r0, r3
     666: f1be 0f00    	cmp.w	lr, #0x0
     66a: bf18         	it	ne
     66c: 4618         	movne	r0, r3
     66e: f240 0b04    	movw	r11, #0x4
     672: f1bc 0f00    	cmp.w	r12, #0x0
     676: bf18         	it	ne
     678: 4618         	movne	r0, r3
     67a: f2c2 0b00    	movt	r11, #0x2000
     67e: e63b         	b	0x2f8 <harness_main+0x264> @ imm = #-0x38a
     680: f1bc 0f02    	cmp.w	r12, #0x2
     684: d1b6         	bne	0x5f4 <harness_main+0x560> @ imm = #-0x94
     686: f1be 0f04    	cmp.w	lr, #0x4
     68a: d1b3         	bne	0x5f4 <harness_main+0x560> @ imm = #-0x9a
     68c: f1b8 0f00    	cmp.w	r8, #0x0
     690: d1b0         	bne	0x5f4 <harness_main+0x560> @ imm = #-0xa0
     692: f240 0070    	movw	r0, #0x70
     696: f2c2 0000    	movt	r0, #0x2000
     69a: 6800         	ldr	r0, [r0]
     69c: 4285         	cmp	r5, r0
     69e: f240 0078    	movw	r0, #0x78
     6a2: f2c2 0000    	movt	r0, #0x2000
     6a6: f43f ae2a    	beq.w	0x2fe <harness_main+0x26a> @ imm = #-0x3ac
     6aa: e7a3         	b	0x5f4 <harness_main+0x560> @ imm = #-0xba
     6ac: e9d9 5604    	ldrd	r5, r6, [r9, #16]
     6b0: 42b5         	cmp	r5, r6
     6b2: d907         	bls	0x6c4 <harness_main+0x630> @ imm = #0xe
     6b4: f04f 0b03    	mov.w	r11, #0x3
     6b8: 2100         	movs	r1, #0x0
     6ba: 2000         	movs	r0, #0x0
     6bc: f04f 0800    	mov.w	r8, #0x0
     6c0: 2203         	movs	r2, #0x3
     6c2: e70b         	b	0x4dc <harness_main+0x448> @ imm = #-0x1ea
     6c4: 9c0c         	ldr	r4, [sp, #0x30]
     6c6: 2c00         	cmp	r4, #0x0
     6c8: f040 8231    	bne.w	0xb2e <harness_main+0xa9a> @ imm = #0x462
     6cc: f649 54c5    	movw	r4, #0x9dc5
     6d0: f2c8 141c    	movt	r4, #0x811c
     6d4: 4062         	eors	r2, r4
     6d6: f240 1493    	movw	r4, #0x193
     6da: f2c0 1400    	movt	r4, #0x100
     6de: 4362         	muls	r2, r4, r2
     6e0: ea8e 62f2    	eor.w	r2, lr, r2, ror #27
     6e4: 4362         	muls	r2, r4, r2
     6e6: ea83 62f2    	eor.w	r2, r3, r2, ror #27
     6ea: 4362         	muls	r2, r4, r2
     6ec: ea81 61f2    	eor.w	r1, r1, r2, ror #27
     6f0: 4361         	muls	r1, r4, r1
     6f2: ea85 61f1    	eor.w	r1, r5, r1, ror #27
     6f6: 4361         	muls	r1, r4, r1
     6f8: f8d9 c018    	ldr.w	r12, [r9, #0x18]
     6fc: ea86 61f1    	eor.w	r1, r6, r1, ror #27
     700: 4361         	muls	r1, r4, r1
     702: ebbc 6ff1    	cmp.w	r12, r1, ror #27
     706: d14c         	bne	0x7a2 <harness_main+0x70e> @ imm = #0x98
     708: 4648         	mov	r0, r9
     70a: f109 0b1c    	add.w	r11, r9, #0x1c
     70e: c84c         	ldm	r0!, {r2, r3, r6}
     710: 4659         	mov	r1, r11
     712: c14c         	stm	r1!, {r2, r3, r6}
     714: e890 006c    	ldm.w	r0, {r2, r3, r5, r6}
     718: c16c         	stm	r1!, {r2, r3, r5, r6}
     71a: 980b         	ldr	r0, [sp, #0x2c]
     71c: f64c 21fe    	movw	r1, #0xcafe
     720: f850 0c08    	ldr	r0, [r0, #-8]
     724: f2cc 1105    	movt	r1, #0xc105
     728: 4288         	cmp	r0, r1
     72a: d109         	bne	0x740 <harness_main+0x6ac> @ imm = #0x12
     72c: 980b         	ldr	r0, [sp, #0x2c]
     72e: f241 3165    	movw	r1, #0x1365
     732: f850 0c04    	ldr	r0, [r0, #-4]
     736: f2c5 51ef    	movt	r1, #0x55ef
     73a: 4288         	cmp	r0, r1
     73c: f040 81f7    	bne.w	0xb2e <harness_main+0xa9a> @ imm = #0x3ee
     740: 4648         	mov	r0, r9
     742: a91b         	add	r1, sp, #0x6c
     744: f000 f9f8    	bl	0xb38 <recovery_block_sample_primary> @ imm = #0x3f0
     748: 980a         	ldr	r0, [sp, #0x28]
     74a: f64c 21fe    	movw	r1, #0xcafe
     74e: f850 0c08    	ldr	r0, [r0, #-8]
     752: f2cc 1105    	movt	r1, #0xc105
     756: 4288         	cmp	r0, r1
     758: d109         	bne	0x76e <harness_main+0x6da> @ imm = #0x12
     75a: 980a         	ldr	r0, [sp, #0x28]
     75c: f64f 0142    	movw	r1, #0xf842
     760: f850 0c04    	ldr	r0, [r0, #-4]
     764: f6c5 1142    	movt	r1, #0x5942
     768: 4288         	cmp	r0, r1
     76a: f040 81e0    	bne.w	0xb2e <harness_main+0xa9a> @ imm = #0x3c0
     76e: f240 0000    	movw	r0, #0x0
     772: f2c2 0000    	movt	r0, #0x2000
     776: 2109         	movs	r1, #0x9
     778: 6001         	str	r1, [r0]
     77a: f240 0068    	movw	r0, #0x68
     77e: f2c2 0000    	movt	r0, #0x2000
     782: 6800         	ldr	r0, [r0]
     784: 3814         	subs	r0, #0x14
     786: 2803         	cmp	r0, #0x3
     788: d827         	bhi	0x7da <harness_main+0x746> @ imm = #0x4e
     78a: e8df f000    	tbb	[pc, r0]
     78e: 02 0e 02 19  	.word	0x19020e02
     792: f240 0070    	movw	r0, #0x70
     796: f2c2 0000    	movt	r0, #0x2000
     79a: 6800         	ldr	r0, [r0]
     79c: f8c9 0004    	str.w	r0, [r9, #0x4]
     7a0: e01b         	b	0x7da <harness_main+0x746> @ imm = #0x36
     7a2: 2203         	movs	r2, #0x3
     7a4: f04f 0b04    	mov.w	r11, #0x4
     7a8: e694         	b	0x4d4 <harness_main+0x440> @ imm = #-0x2d8
     7aa: f240 0070    	movw	r0, #0x70
     7ae: f2c2 0000    	movt	r0, #0x2000
     7b2: 6800         	ldr	r0, [r0]
     7b4: f8d9 1018    	ldr.w	r1, [r9, #0x18]
     7b8: 4048         	eors	r0, r1
     7ba: f8c9 0018    	str.w	r0, [r9, #0x18]
     7be: e00c         	b	0x7da <harness_main+0x746> @ imm = #0x18
     7c0: f240 0070    	movw	r0, #0x70
     7c4: f2c2 0000    	movt	r0, #0x2000
     7c8: 6800         	ldr	r0, [r0]
     7ca: f8d9 1034    	ldr.w	r1, [r9, #0x34]
     7ce: f8c9 0004    	str.w	r0, [r9, #0x4]
     7d2: f081 0010    	eor	r0, r1, #0x10
     7d6: f8c9 0034    	str.w	r0, [r9, #0x34]
     7da: e9d9 2e00    	ldrd	r2, lr, [r9]
     7de: f240 006c    	movw	r0, #0x6c
     7e2: f2c2 0000    	movt	r0, #0x2000
     7e6: f8d9 c020    	ldr.w	r12, [r9, #0x20]
     7ea: f8c0 e000    	str.w	lr, [r0]
     7ee: f240 0074    	movw	r0, #0x74
     7f2: 2a02         	cmp	r2, #0x2
     7f4: f2c2 0000    	movt	r0, #0x2000
     7f8: f8c0 c000    	str.w	r12, [r0]
     7fc: d902         	bls	0x804 <harness_main+0x770> @ imm = #0x4
     7fe: f04f 0806    	mov.w	r8, #0x6
     802: e04f         	b	0x8a4 <harness_main+0x810> @ imm = #0x9e
     804: e9d9 5302    	ldrd	r5, r3, [r9, #8]
     808: 429d         	cmp	r5, r3
     80a: d902         	bls	0x812 <harness_main+0x77e> @ imm = #0x4
     80c: f04f 0805    	mov.w	r8, #0x5
     810: e048         	b	0x8a4 <harness_main+0x810> @ imm = #0x90
     812: 45ae         	cmp	lr, r5
     814: d202         	bhs	0x81c <harness_main+0x788> @ imm = #0x4
     816: f04f 0801    	mov.w	r8, #0x1
     81a: e043         	b	0x8a4 <harness_main+0x810> @ imm = #0x86
     81c: 459e         	cmp	lr, r3
     81e: d902         	bls	0x826 <harness_main+0x792> @ imm = #0x4
     820: f04f 0802    	mov.w	r8, #0x2
     824: e03e         	b	0x8a4 <harness_main+0x810> @ imm = #0x7c
     826: e9d9 6104    	ldrd	r6, r1, [r9, #16]
     82a: 428e         	cmp	r6, r1
     82c: d902         	bls	0x834 <harness_main+0x7a0> @ imm = #0x4
     82e: f04f 0803    	mov.w	r8, #0x3
     832: e037         	b	0x8a4 <harness_main+0x810> @ imm = #0x6e
     834: 9c09         	ldr	r4, [sp, #0x24]
     836: 2c00         	cmp	r4, #0x0
     838: f040 8179    	bne.w	0xb2e <harness_main+0xa9a> @ imm = #0x2f2
     83c: f649 54c5    	movw	r4, #0x9dc5
     840: f2c8 141c    	movt	r4, #0x811c
     844: 4062         	eors	r2, r4
     846: f240 1493    	movw	r4, #0x193
     84a: f2c0 1400    	movt	r4, #0x100
     84e: 4362         	muls	r2, r4, r2
     850: ea8e 62f2    	eor.w	r2, lr, r2, ror #27
     854: 4362         	muls	r2, r4, r2
     856: ea85 62f2    	eor.w	r2, r5, r2, ror #27
     85a: 4362         	muls	r2, r4, r2
     85c: ea83 62f2    	eor.w	r2, r3, r2, ror #27
     860: 4362         	muls	r2, r4, r2
     862: ea86 62f2    	eor.w	r2, r6, r2, ror #27
     866: 4362         	muls	r2, r4, r2
     868: f8d9 0018    	ldr.w	r0, [r9, #0x18]
     86c: ea81 61f2    	eor.w	r1, r1, r2, ror #27
     870: 4361         	muls	r1, r4, r1
     872: ebb0 6ff1    	cmp.w	r0, r1, ror #27
     876: d113         	bne	0x8a0 <harness_main+0x80c> @ imm = #0x26
     878: 9905         	ldr	r1, [sp, #0x14]
     87a: 2900         	cmp	r1, #0x0
     87c: f040 8157    	bne.w	0xb2e <harness_main+0xa9a> @ imm = #0x2ae
     880: 4649         	mov	r1, r9
     882: c94c         	ldm	r1!, {r2, r3, r6}
     884: 2000         	movs	r0, #0x0
     886: e8ab 004c    	stm.w	r11!, {r2, r3, r6}
     88a: e891 006c    	ldm.w	r1, {r2, r3, r5, r6}
     88e: 2100         	movs	r1, #0x0
     890: e88b 006c    	stm.w	r11, {r2, r3, r5, r6}
     894: f04f 0800    	mov.w	r8, #0x0
     898: f04f 0b00    	mov.w	r11, #0x0
     89c: 2200         	movs	r2, #0x0
     89e: e61d         	b	0x4dc <harness_main+0x448> @ imm = #-0x3c6
     8a0: f04f 0804    	mov.w	r8, #0x4
     8a4: f8d9 301c    	ldr.w	r3, [r9, #0x1c]
     8a8: 2b02         	cmp	r3, #0x2
     8aa: d902         	bls	0x8b2 <harness_main+0x81e> @ imm = #0x4
     8ac: 2204         	movs	r2, #0x4
     8ae: 2006         	movs	r0, #0x6
     8b0: e017         	b	0x8e2 <harness_main+0x84e> @ imm = #0x2e
     8b2: e9d9 1209    	ldrd	r1, r2, [r9, #36]
     8b6: 4291         	cmp	r1, r2
     8b8: d902         	bls	0x8c0 <harness_main+0x82c> @ imm = #0x4
     8ba: 2204         	movs	r2, #0x4
     8bc: 2005         	movs	r0, #0x5
     8be: e010         	b	0x8e2 <harness_main+0x84e> @ imm = #0x20
     8c0: 458c         	cmp	r12, r1
     8c2: d202         	bhs	0x8ca <harness_main+0x836> @ imm = #0x4
     8c4: 2204         	movs	r2, #0x4
     8c6: 2001         	movs	r0, #0x1
     8c8: e00b         	b	0x8e2 <harness_main+0x84e> @ imm = #0x16
     8ca: 4594         	cmp	r12, r2
     8cc: d902         	bls	0x8d4 <harness_main+0x840> @ imm = #0x4
     8ce: 2204         	movs	r2, #0x4
     8d0: 2002         	movs	r0, #0x2
     8d2: e006         	b	0x8e2 <harness_main+0x84e> @ imm = #0xc
     8d4: 465d         	mov	r5, r11
     8d6: e9d9 4b0b    	ldrd	r4, r11, [r9, #44]
     8da: 455c         	cmp	r4, r11
     8dc: d905         	bls	0x8ea <harness_main+0x856> @ imm = #0xa
     8de: 2204         	movs	r2, #0x4
     8e0: 2003         	movs	r0, #0x3
     8e2: 2100         	movs	r1, #0x0
     8e4: f04f 0b00    	mov.w	r11, #0x0
     8e8: e5f8         	b	0x4dc <harness_main+0x448> @ imm = #-0x410
     8ea: 9e08         	ldr	r6, [sp, #0x20]
     8ec: 2e00         	cmp	r6, #0x0
     8ee: f040 811e    	bne.w	0xb2e <harness_main+0xa9a> @ imm = #0x23c
     8f2: f649 56c5    	movw	r6, #0x9dc5
     8f6: f2c8 161c    	movt	r6, #0x811c
     8fa: 4073         	eors	r3, r6
     8fc: f240 1693    	movw	r6, #0x193
     900: f2c0 1600    	movt	r6, #0x100
     904: 4373         	muls	r3, r6, r3
     906: ea8c 63f3    	eor.w	r3, r12, r3, ror #27
     90a: 4373         	muls	r3, r6, r3
     90c: ea81 61f3    	eor.w	r1, r1, r3, ror #27
     910: 4371         	muls	r1, r6, r1
     912: ea82 61f1    	eor.w	r1, r2, r1, ror #27
     916: 4371         	muls	r1, r6, r1
     918: ea84 61f1    	eor.w	r1, r4, r1, ror #27
     91c: 4371         	muls	r1, r6, r1
     91e: f8d9 0034    	ldr.w	r0, [r9, #0x34]
     922: ea8b 61f1    	eor.w	r1, r11, r1, ror #27
     926: 4371         	muls	r1, r6, r1
     928: ebb0 6ff1    	cmp.w	r0, r1, ror #27
     92c: d157         	bne	0x9de <harness_main+0x94a> @ imm = #0xae
     92e: 4629         	mov	r1, r5
     930: c94c         	ldm	r1!, {r2, r3, r6}
     932: 4648         	mov	r0, r9
     934: c04c         	stm	r0!, {r2, r3, r6}
     936: e891 005c    	ldm.w	r1, {r2, r3, r4, r6}
     93a: f64c 21fe    	movw	r1, #0xcafe
     93e: c05c         	stm	r0!, {r2, r3, r4, r6}
     940: 9807         	ldr	r0, [sp, #0x1c]
     942: f2cc 1105    	movt	r1, #0xc105
     946: f850 0c08    	ldr	r0, [r0, #-8]
     94a: 4288         	cmp	r0, r1
     94c: d109         	bne	0x962 <harness_main+0x8ce> @ imm = #0x12
     94e: 9807         	ldr	r0, [sp, #0x1c]
     950: f241 3165    	movw	r1, #0x1365
     954: f850 0c04    	ldr	r0, [r0, #-4]
     958: f2c5 51ef    	movt	r1, #0x55ef
     95c: 4288         	cmp	r0, r1
     95e: f040 80e6    	bne.w	0xb2e <harness_main+0xa9a> @ imm = #0x1cc
     962: 4648         	mov	r0, r9
     964: a91b         	add	r1, sp, #0x6c
     966: f000 f9f9    	bl	0xd5c <recovery_block_sample_alternate> @ imm = #0x3f2
     96a: 9806         	ldr	r0, [sp, #0x18]
     96c: f64c 21fe    	movw	r1, #0xcafe
     970: f850 0c08    	ldr	r0, [r0, #-8]
     974: f2cc 1105    	movt	r1, #0xc105
     978: 4288         	cmp	r0, r1
     97a: d109         	bne	0x990 <harness_main+0x8fc> @ imm = #0x12
     97c: 9806         	ldr	r0, [sp, #0x18]
     97e: f64f 0142    	movw	r1, #0xf842
     982: f850 0c04    	ldr	r0, [r0, #-4]
     986: f6c5 1142    	movt	r1, #0x5942
     98a: 4288         	cmp	r0, r1
     98c: f040 80cf    	bne.w	0xb2e <harness_main+0xa9a> @ imm = #0x19e
     990: f240 0000    	movw	r0, #0x0
     994: f2c2 0000    	movt	r0, #0x2000
     998: 210a         	movs	r1, #0xa
     99a: 6001         	str	r1, [r0]
     99c: f240 0068    	movw	r0, #0x68
     9a0: f2c2 0000    	movt	r0, #0x2000
     9a4: 6800         	ldr	r0, [r0]
     9a6: 2816         	cmp	r0, #0x16
     9a8: d105         	bne	0x9b6 <harness_main+0x922> @ imm = #0xa
     9aa: f8d9 0018    	ldr.w	r0, [r9, #0x18]
     9ae: f080 0010    	eor	r0, r0, #0x10
     9b2: f8c9 0018    	str.w	r0, [r9, #0x18]
     9b6: e9d9 1e00    	ldrd	r1, lr, [r9]
     9ba: f240 006c    	movw	r0, #0x6c
     9be: f2c2 0000    	movt	r0, #0x2000
     9c2: f8d9 c020    	ldr.w	r12, [r9, #0x20]
     9c6: f8c0 e000    	str.w	lr, [r0]
     9ca: f240 0074    	movw	r0, #0x74
     9ce: 2902         	cmp	r1, #0x2
     9d0: f2c2 0000    	movt	r0, #0x2000
     9d4: f8c0 c000    	str.w	r12, [r0]
     9d8: d907         	bls	0x9ea <harness_main+0x956> @ imm = #0xe
     9da: 2106         	movs	r1, #0x6
     9dc: e048         	b	0xa70 <harness_main+0x9dc> @ imm = #0x90
     9de: 2004         	movs	r0, #0x4
     9e0: 2100         	movs	r1, #0x0
     9e2: f04f 0b00    	mov.w	r11, #0x0
     9e6: 2204         	movs	r2, #0x4
     9e8: e578         	b	0x4dc <harness_main+0x448> @ imm = #-0x510
     9ea: e9d9 2302    	ldrd	r2, r3, [r9, #8]
     9ee: 429a         	cmp	r2, r3
     9f0: d901         	bls	0x9f6 <harness_main+0x962> @ imm = #0x2
     9f2: 2105         	movs	r1, #0x5
     9f4: e03c         	b	0xa70 <harness_main+0x9dc> @ imm = #0x78
     9f6: 4596         	cmp	lr, r2
     9f8: d201         	bhs	0x9fe <harness_main+0x96a> @ imm = #0x2
     9fa: 2101         	movs	r1, #0x1
     9fc: e038         	b	0xa70 <harness_main+0x9dc> @ imm = #0x70
     9fe: 459e         	cmp	lr, r3
     a00: d901         	bls	0xa06 <harness_main+0x972> @ imm = #0x2
     a02: 2102         	movs	r1, #0x2
     a04: e034         	b	0xa70 <harness_main+0x9dc> @ imm = #0x68
     a06: e9d9 4b04    	ldrd	r4, r11, [r9, #16]
     a0a: 455c         	cmp	r4, r11
     a0c: d901         	bls	0xa12 <harness_main+0x97e> @ imm = #0x2
     a0e: 2103         	movs	r1, #0x3
     a10: e02e         	b	0xa70 <harness_main+0x9dc> @ imm = #0x5c
     a12: 9e02         	ldr	r6, [sp, #0x8]
     a14: 2e00         	cmp	r6, #0x0
     a16: f040 808a    	bne.w	0xb2e <harness_main+0xa9a> @ imm = #0x114
     a1a: f649 56c5    	movw	r6, #0x9dc5
     a1e: f2c8 161c    	movt	r6, #0x811c
     a22: 4071         	eors	r1, r6
     a24: f240 1693    	movw	r6, #0x193
     a28: f2c0 1600    	movt	r6, #0x100
     a2c: 4371         	muls	r1, r6, r1
     a2e: ea8e 61f1    	eor.w	r1, lr, r1, ror #27
     a32: 4371         	muls	r1, r6, r1
     a34: ea82 61f1    	eor.w	r1, r2, r1, ror #27
     a38: 4371         	muls	r1, r6, r1
     a3a: ea83 61f1    	eor.w	r1, r3, r1, ror #27
     a3e: 4371         	muls	r1, r6, r1
     a40: ea84 61f1    	eor.w	r1, r4, r1, ror #27
     a44: 4371         	muls	r1, r6, r1
     a46: f8d9 0018    	ldr.w	r0, [r9, #0x18]
     a4a: ea8b 61f1    	eor.w	r1, r11, r1, ror #27
     a4e: 4371         	muls	r1, r6, r1
     a50: ebb0 6ff1    	cmp.w	r0, r1, ror #27
     a54: d10b         	bne	0xa6e <harness_main+0x9da> @ imm = #0x16
     a56: 9900         	ldr	r1, [sp]
     a58: 2900         	cmp	r1, #0x0
     a5a: d168         	bne	0xb2e <harness_main+0xa9a> @ imm = #0xd0
     a5c: 4649         	mov	r1, r9
     a5e: c94c         	ldm	r1!, {r2, r3, r6}
     a60: c54c         	stm	r5!, {r2, r3, r6}
     a62: e891 005c    	ldm.w	r1, {r2, r3, r4, r6}
     a66: 2100         	movs	r1, #0x0
     a68: c55c         	stm	r5!, {r2, r3, r4, r6}
     a6a: 2201         	movs	r2, #0x1
     a6c: e058         	b	0xb20 <harness_main+0xa8c> @ imm = #0xb0
     a6e: 2104         	movs	r1, #0x4
     a70: f8d9 201c    	ldr.w	r2, [r9, #0x1c]
     a74: 2a02         	cmp	r2, #0x2
     a76: d904         	bls	0xa82 <harness_main+0x9ee> @ imm = #0x8
     a78: 2204         	movs	r2, #0x4
     a7a: f04f 0b00    	mov.w	r11, #0x0
     a7e: 2006         	movs	r0, #0x6
     a80: e52c         	b	0x4dc <harness_main+0x448> @ imm = #-0x5a8
     a82: e9d9 3009    	ldrd	r3, r0, [r9, #36]
     a86: 4283         	cmp	r3, r0
     a88: d904         	bls	0xa94 <harness_main+0xa00> @ imm = #0x8
     a8a: 2204         	movs	r2, #0x4
     a8c: f04f 0b00    	mov.w	r11, #0x0
     a90: 2005         	movs	r0, #0x5
     a92: e523         	b	0x4dc <harness_main+0x448> @ imm = #-0x5ba
     a94: 459c         	cmp	r12, r3
     a96: d204         	bhs	0xaa2 <harness_main+0xa0e> @ imm = #0x8
     a98: 2204         	movs	r2, #0x4
     a9a: f04f 0b00    	mov.w	r11, #0x0
     a9e: 2001         	movs	r0, #0x1
     aa0: e51c         	b	0x4dc <harness_main+0x448> @ imm = #-0x5c8
     aa2: 4584         	cmp	r12, r0
     aa4: d904         	bls	0xab0 <harness_main+0xa1c> @ imm = #0x8
     aa6: 2204         	movs	r2, #0x4
     aa8: f04f 0b00    	mov.w	r11, #0x0
     aac: 2002         	movs	r0, #0x2
     aae: e515         	b	0x4dc <harness_main+0x448> @ imm = #-0x5d6
     ab0: e9d9 b60b    	ldrd	r11, r6, [r9, #44]
     ab4: 45b3         	cmp	r11, r6
     ab6: d904         	bls	0xac2 <harness_main+0xa2e> @ imm = #0x8
     ab8: 2204         	movs	r2, #0x4
     aba: f04f 0b00    	mov.w	r11, #0x0
     abe: 2003         	movs	r0, #0x3
     ac0: e50c         	b	0x4dc <harness_main+0x448> @ imm = #-0x5e8
     ac2: 9c01         	ldr	r4, [sp, #0x4]
     ac4: bb9c         	cbnz	r4, 0xb2e <harness_main+0xa9a> @ imm = #0x66
     ac6: f8d9 4034    	ldr.w	r4, [r9, #0x34]
     aca: e9cd 6403    	strd	r6, r4, [sp, #12]
     ace: 465e         	mov	r6, r11
     ad0: f649 5bc5    	movw	r11, #0x9dc5
     ad4: f2c8 1b1c    	movt	r11, #0x811c
     ad8: f240 1493    	movw	r4, #0x193
     adc: ea82 020b    	eor.w	r2, r2, r11
     ae0: f2c0 1400    	movt	r4, #0x100
     ae4: 4362         	muls	r2, r4, r2
     ae6: ea8c 62f2    	eor.w	r2, r12, r2, ror #27
     aea: 4362         	muls	r2, r4, r2
     aec: ea83 62f2    	eor.w	r2, r3, r2, ror #27
     af0: 4362         	muls	r2, r4, r2
     af2: ea80 62f2    	eor.w	r2, r0, r2, ror #27
     af6: 4362         	muls	r2, r4, r2
     af8: ea86 62f2    	eor.w	r2, r6, r2, ror #27
     afc: 9803         	ldr	r0, [sp, #0xc]
     afe: 4362         	muls	r2, r4, r2
     b00: ea80 62f2    	eor.w	r2, r0, r2, ror #27
     b04: 9804         	ldr	r0, [sp, #0x10]
     b06: 4362         	muls	r2, r4, r2
     b08: ebb0 6ff2    	cmp.w	r0, r2, ror #27
     b0c: d10a         	bne	0xb24 <harness_main+0xa90> @ imm = #0x14
     b0e: cd4c         	ldm	r5!, {r2, r3, r6}
     b10: 4648         	mov	r0, r9
     b12: c04c         	stm	r0!, {r2, r3, r6}
     b14: e895 005c    	ldm.w	r5, {r2, r3, r4, r6}
     b18: c05c         	stm	r0!, {r2, r3, r4, r6}
     b1a: f8d9 e004    	ldr.w	lr, [r9, #0x4]
     b1e: 2202         	movs	r2, #0x2
     b20: 2000         	movs	r0, #0x0
     b22: e6df         	b	0x8e4 <harness_main+0x850> @ imm = #-0x242
     b24: f04f 0b00    	mov.w	r11, #0x0
     b28: 2004         	movs	r0, #0x4
     b2a: 2204         	movs	r2, #0x4
     b2c: e4d6         	b	0x4dc <harness_main+0x448> @ imm = #-0x654
     b2e: defe         	trap
     b30: fe ca 05 c1  	.word	0xc105cafe
     b34: 65 13 ef 55  	.word	0x55ef1365

00000b38 <recovery_block_sample_primary>:
     b38: b5f0         	push	{r4, r5, r6, r7, lr}
     b3a: af03         	add	r7, sp, #0xc
     b3c: e92d 0f00    	push.w	{r8, r9, r10, r11}
     b40: b087         	sub	sp, #0x1c
     b42: 2900         	cmp	r1, #0x0
     b44: f000 80b4    	beq.w	0xcb0 <recovery_block_sample_primary+0x178> @ imm = #0x168
     b48: f011 0203    	ands	r2, r1, #0x3
     b4c: f040 80b0    	bne.w	0xcb0 <recovery_block_sample_primary+0x178> @ imm = #0x160
     b50: 680a         	ldr	r2, [r1]
     b52: f247 3391    	movw	r3, #0x7391
     b56: f6c5 539f    	movt	r3, #0x5d9f
     b5a: 2800         	cmp	r0, #0x0
     b5c: fba2 6303    	umull	r6, r3, r2, r3
     b60: f000 80a6    	beq.w	0xcb0 <recovery_block_sample_primary+0x178> @ imm = #0x14c
     b64: f010 0603    	ands	r6, r0, #0x3
     b68: f040 80a2    	bne.w	0xcb0 <recovery_block_sample_primary+0x178> @ imm = #0x144
     b6c: 0a1b         	lsrs	r3, r3, #0x8
     b6e: f44f 762f    	mov.w	r6, #0x2bc
     b72: fb03 2216    	mls	r2, r3, r6, r2
     b76: 2325         	movs	r3, #0x25
     b78: 435a         	muls	r2, r3, r2
     b7a: 3211         	adds	r2, #0x11
     b7c: b293         	uxth	r3, r2
     b7e: f64b 353f    	movw	r5, #0xbb3f
     b82: 436b         	muls	r3, r5, r3
     b84: 0e5b         	lsrs	r3, r3, #0x19
     b86: fb03 2216    	mls	r2, r3, r6, r2
     b8a: f10d 0904    	add.w	r9, sp, #0x4
     b8e: f119 0f05    	cmn.w	r9, #0x5
     b92: f04f 0600    	mov.w	r6, #0x0
     b96: f102 0264    	add.w	r2, r2, #0x64
     b9a: bf88         	it	hi
     b9c: 2601         	movhi	r6, #0x1
     b9e: f119 0f09    	cmn.w	r9, #0x9
     ba2: f04f 0300    	mov.w	r3, #0x0
     ba6: b295         	uxth	r5, r2
     ba8: bf88         	it	hi
     baa: 2301         	movhi	r3, #0x1
     bac: f119 0f0d    	cmn.w	r9, #0xd
     bb0: f04f 0200    	mov.w	r2, #0x0
     bb4: f04f 0400    	mov.w	r4, #0x0
     bb8: bf88         	it	hi
     bba: 2201         	movhi	r2, #0x1
     bbc: f119 0f11    	cmn.w	r9, #0x11
     bc0: bf88         	it	hi
     bc2: 2401         	movhi	r4, #0x1
     bc4: f119 0f15    	cmn.w	r9, #0x15
     bc8: 6045         	str	r5, [r0, #0x4]
     bca: d871         	bhi	0xcb0 <recovery_block_sample_primary+0x178> @ imm = #0xe2
     bcc: 2c00         	cmp	r4, #0x0
     bce: d16f         	bne	0xcb0 <recovery_block_sample_primary+0x178> @ imm = #0xde
     bd0: 2a00         	cmp	r2, #0x0
     bd2: d16d         	bne	0xcb0 <recovery_block_sample_primary+0x178> @ imm = #0xda
     bd4: 2e00         	cmp	r6, #0x0
     bd6: d16b         	bne	0xcb0 <recovery_block_sample_primary+0x178> @ imm = #0xd6
     bd8: 2b00         	cmp	r3, #0x0
     bda: d169         	bne	0xcb0 <recovery_block_sample_primary+0x178> @ imm = #0xd2
     bdc: 6802         	ldr	r2, [r0]
     bde: f649 54c5    	movw	r4, #0x9dc5
     be2: f240 1393    	movw	r3, #0x193
     be6: f2c8 141c    	movt	r4, #0x811c
     bea: f2c0 1300    	movt	r3, #0x100
     bee: 4062         	eors	r2, r4
     bf0: f100 0e08    	add.w	lr, r0, #0x8
     bf4: fb02 fa03    	mul	r10, r2, r3
     bf8: e89e 4900    	ldm.w	lr, {r8, r11, lr}
     bfc: ea85 62fa    	eor.w	r2, r5, r10, ror #27
     c00: 435a         	muls	r2, r3, r2
     c02: ea88 62f2    	eor.w	r2, r8, r2, ror #27
     c06: 435a         	muls	r2, r3, r2
     c08: ea8b 62f2    	eor.w	r2, r11, r2, ror #27
     c0c: 435a         	muls	r2, r3, r2
     c0e: f8d0 c014    	ldr.w	r12, [r0, #0x14]
     c12: ea8e 62f2    	eor.w	r2, lr, r2, ror #27
     c16: 435a         	muls	r2, r3, r2
     c18: ea8c 62f2    	eor.w	r2, r12, r2, ror #27
     c1c: 435a         	muls	r2, r3, r2
     c1e: ea4f 65f2    	ror.w	r5, r2, #0x1b
     c22: 6185         	str	r5, [r0, #0x18]
     c24: 6849         	ldr	r1, [r1, #0x4]
     c26: 07ca         	lsls	r2, r1, #0x1f
     c28: d039         	beq	0xc9e <recovery_block_sample_primary+0x166> @ imm = #0x72
     c2a: f10b 0201    	add.w	r2, r11, #0x1
     c2e: f119 0f05    	cmn.w	r9, #0x5
     c32: f04f 0600    	mov.w	r6, #0x0
     c36: 9200         	str	r2, [sp]
     c38: bf88         	it	hi
     c3a: 2601         	movhi	r6, #0x1
     c3c: f119 0f09    	cmn.w	r9, #0x9
     c40: f04f 0500    	mov.w	r5, #0x0
     c44: bf88         	it	hi
     c46: 2501         	movhi	r5, #0x1
     c48: f119 0f0d    	cmn.w	r9, #0xd
     c4c: f04f 0200    	mov.w	r2, #0x0
     c50: f04f 0400    	mov.w	r4, #0x0
     c54: bf88         	it	hi
     c56: 2201         	movhi	r2, #0x1
     c58: f119 0f11    	cmn.w	r9, #0x11
     c5c: bf88         	it	hi
     c5e: 2401         	movhi	r4, #0x1
     c60: f119 0f15    	cmn.w	r9, #0x15
     c64: f8dd 9000    	ldr.w	r9, [sp]
     c68: f8c0 9004    	str.w	r9, [r0, #0x4]
     c6c: d820         	bhi	0xcb0 <recovery_block_sample_primary+0x178> @ imm = #0x40
     c6e: b9fc         	cbnz	r4, 0xcb0 <recovery_block_sample_primary+0x178> @ imm = #0x3e
     c70: b9f2         	cbnz	r2, 0xcb0 <recovery_block_sample_primary+0x178> @ imm = #0x3c
     c72: b9ee         	cbnz	r6, 0xcb0 <recovery_block_sample_primary+0x178> @ imm = #0x3a
     c74: b9e5         	cbnz	r5, 0xcb0 <recovery_block_sample_primary+0x178> @ imm = #0x38
     c76: ea4f 62fa    	ror.w	r2, r10, #0x1b
     c7a: ea82 0209    	eor.w	r2, r2, r9
     c7e: 435a         	muls	r2, r3, r2
     c80: ea88 62f2    	eor.w	r2, r8, r2, ror #27
     c84: 435a         	muls	r2, r3, r2
     c86: ea8b 62f2    	eor.w	r2, r11, r2, ror #27
     c8a: 435a         	muls	r2, r3, r2
     c8c: ea8e 62f2    	eor.w	r2, lr, r2, ror #27
     c90: 435a         	muls	r2, r3, r2
     c92: ea8c 62f2    	eor.w	r2, r12, r2, ror #27
     c96: 435a         	muls	r2, r3, r2
     c98: ea4f 65f2    	ror.w	r5, r2, #0x1b
     c9c: 6185         	str	r5, [r0, #0x18]
     c9e: 0789         	lsls	r1, r1, #0x1e
     ca0: bf44         	itt	mi
     ca2: f085 0110    	eormi	r1, r5, #0x10
     ca6: 6181         	strmi	r1, [r0, #0x18]
     ca8: b007         	add	sp, #0x1c
     caa: e8bd 0f00    	pop.w	{r8, r9, r10, r11}
     cae: bdf0         	pop	{r4, r5, r6, r7, pc}
     cb0: defe         	trap
     cb2: bf00         	nop
     cb4: fe ca 05 c1  	.word	0xc105cafe
     cb8: 42 f8 42 59  	.word	0x5942f842

00000cbc <apply_after_primary_fault>:
     cbc: b580         	push	{r7, lr}
     cbe: 466f         	mov	r7, sp
     cc0: f240 0100    	movw	r1, #0x0
     cc4: f2c2 0100    	movt	r1, #0x2000
     cc8: 2209         	movs	r2, #0x9
     cca: 600a         	str	r2, [r1]
     ccc: f240 0168    	movw	r1, #0x68
     cd0: f2c2 0100    	movt	r1, #0x2000
     cd4: 6809         	ldr	r1, [r1]
     cd6: 3914         	subs	r1, #0x14
     cd8: 2903         	cmp	r1, #0x3
     cda: d829         	bhi	0xd30 <apply_after_primary_fault+0x74> @ imm = #0x52
     cdc: e8df f001    	tbb	[pc, r1]
     ce0: 02 0d 02 1a  	.word	0x1a020d02
     ce4: f240 0170    	movw	r1, #0x70
     ce8: f2c2 0100    	movt	r1, #0x2000
     cec: 6809         	ldr	r1, [r1]
     cee: b380         	cbz	r0, 0xd52 <apply_after_primary_fault+0x96> @ imm = #0x60
     cf0: f010 0203    	ands	r2, r0, #0x3
     cf4: d12d         	bne	0xd52 <apply_after_primary_fault+0x96> @ imm = #0x5a
     cf6: 6041         	str	r1, [r0, #0x4]
     cf8: e01a         	b	0xd30 <apply_after_primary_fault+0x74> @ imm = #0x34
     cfa: f240 0170    	movw	r1, #0x70
     cfe: f2c2 0100    	movt	r1, #0x2000
     d02: 6809         	ldr	r1, [r1]
     d04: b328         	cbz	r0, 0xd52 <apply_after_primary_fault+0x96> @ imm = #0x4a
     d06: f010 0203    	ands	r2, r0, #0x3
     d0a: d122         	bne	0xd52 <apply_after_primary_fault+0x96> @ imm = #0x44
     d0c: 6982         	ldr	r2, [r0, #0x18]
     d0e: 4051         	eors	r1, r2
     d10: 6181         	str	r1, [r0, #0x18]
     d12: e00d         	b	0xd30 <apply_after_primary_fault+0x74> @ imm = #0x1a
     d14: f240 0170    	movw	r1, #0x70
     d18: f2c2 0100    	movt	r1, #0x2000
     d1c: 6809         	ldr	r1, [r1]
     d1e: b1c0         	cbz	r0, 0xd52 <apply_after_primary_fault+0x96> @ imm = #0x30
     d20: f010 0203    	ands	r2, r0, #0x3
     d24: d115         	bne	0xd52 <apply_after_primary_fault+0x96> @ imm = #0x2a
     d26: 6b42         	ldr	r2, [r0, #0x34]
     d28: 6041         	str	r1, [r0, #0x4]
     d2a: f082 0110    	eor	r1, r2, #0x10
     d2e: 6341         	str	r1, [r0, #0x34]
     d30: f240 0030    	movw	r0, #0x30
     d34: f2c2 0000    	movt	r0, #0x2000
     d38: f240 016c    	movw	r1, #0x6c
     d3c: 6842         	ldr	r2, [r0, #0x4]
     d3e: f2c2 0100    	movt	r1, #0x2000
     d42: 6a00         	ldr	r0, [r0, #0x20]
     d44: 600a         	str	r2, [r1]
     d46: f240 0174    	movw	r1, #0x74
     d4a: f2c2 0100    	movt	r1, #0x2000
     d4e: 6008         	str	r0, [r1]
     d50: bd80         	pop	{r7, pc}
     d52: defe         	trap
     d54: fe ca 05 c1  	.word	0xc105cafe
     d58: 65 13 ef 55  	.word	0x55ef1365

00000d5c <recovery_block_sample_alternate>:
     d5c: b5f0         	push	{r4, r5, r6, r7, lr}
     d5e: af03         	add	r7, sp, #0xc
     d60: e92d 0f00    	push.w	{r8, r9, r10, r11}
     d64: b087         	sub	sp, #0x1c
     d66: 2900         	cmp	r1, #0x0
     d68: f000 818f    	beq.w	0x108a <recovery_block_sample_alternate+0x32e> @ imm = #0x31e
     d6c: f011 0203    	ands	r2, r1, #0x3
     d70: f040 818b    	bne.w	0x108a <recovery_block_sample_alternate+0x32e> @ imm = #0x316
     d74: 680b         	ldr	r3, [r1]
     d76: f247 3c91    	movw	r12, #0x7391
     d7a: f6c5 5c9f    	movt	r12, #0x5d9f
     d7e: fba3 260c    	umull	r2, r6, r3, r12
     d82: 0a36         	lsrs	r6, r6, #0x8
     d84: f44f 722f    	mov.w	r2, #0x2bc
     d88: fb06 3312    	mls	r3, r6, r2, r3
     d8c: f240 26ab    	movw	r6, #0x2ab
     d90: 42b3         	cmp	r3, r6
     d92: f64f 5655    	movw	r6, #0xfd55
     d96: f6cf 76ff    	movt	r6, #0xffff
     d9a: bf38         	it	lo
     d9c: 2611         	movlo	r6, #0x11
     d9e: eb06 0443    	add.w	r4, r6, r3, lsl #1
     da2: f64f 5e44    	movw	lr, #0xfd44
     da6: f5b4 7f2f    	cmp.w	r4, #0x2bc
     daa: bf28         	it	hs
     dac: 4474         	addhs	r4, lr
     dae: 18e5         	adds	r5, r4, r3
     db0: b2ae         	uxth	r6, r5
     db2: f64b 383f    	movw	r8, #0xbb3f
     db6: fb06 f608    	mul	r6, r6, r8
     dba: 0e76         	lsrs	r6, r6, #0x19
     dbc: fb06 5512    	mls	r5, r6, r2, r5
     dc0: fa13 f585    	uxtah	r5, r3, r5
     dc4: f5b5 762f    	subs.w	r6, r5, #0x2bc
     dc8: bf38         	it	lo
     dca: 462e         	movlo	r6, r5
     dcc: 18f5         	adds	r5, r6, r3
     dce: fba5 640c    	umull	r6, r4, r5, r12
     dd2: 0a24         	lsrs	r4, r4, #0x8
     dd4: fb04 5412    	mls	r4, r4, r2, r5
     dd8: 441c         	add	r4, r3
     dda: f5b4 7f2f    	cmp.w	r4, #0x2bc
     dde: bf28         	it	hs
     de0: 4474         	addhs	r4, lr
     de2: 441c         	add	r4, r3
     de4: b2a5         	uxth	r5, r4
     de6: fb05 f508    	mul	r5, r5, r8
     dea: 0e6d         	lsrs	r5, r5, #0x19
     dec: fb05 4412    	mls	r4, r5, r2, r4
     df0: fa13 f484    	uxtah	r4, r3, r4
     df4: f5b4 752f    	subs.w	r5, r4, #0x2bc
     df8: bf38         	it	lo
     dfa: 4625         	movlo	r5, r4
     dfc: 18ec         	adds	r4, r5, r3
     dfe: fba4 560c    	umull	r5, r6, r4, r12
     e02: 0a35         	lsrs	r5, r6, #0x8
     e04: fb05 4412    	mls	r4, r5, r2, r4
     e08: 441c         	add	r4, r3
     e0a: f5b4 7f2f    	cmp.w	r4, #0x2bc
     e0e: bf28         	it	hs
     e10: 4474         	addhs	r4, lr
     e12: 441c         	add	r4, r3
     e14: b2a5         	uxth	r5, r4
     e16: fb05 f508    	mul	r5, r5, r8
     e1a: 0e6d         	lsrs	r5, r5, #0x19
     e1c: fb05 4412    	mls	r4, r5, r2, r4
     e20: fa13 f484    	uxtah	r4, r3, r4
     e24: f5b4 752f    	subs.w	r5, r4, #0x2bc
     e28: bf38         	it	lo
     e2a: 4625         	movlo	r5, r4
     e2c: 18ec         	adds	r4, r5, r3
     e2e: fba4 560c    	umull	r5, r6, r4, r12
     e32: 0a35         	lsrs	r5, r6, #0x8
     e34: fb05 4412    	mls	r4, r5, r2, r4
     e38: 441c         	add	r4, r3
     e3a: f5b4 7f2f    	cmp.w	r4, #0x2bc
     e3e: bf28         	it	hs
     e40: 4474         	addhs	r4, lr
     e42: 441c         	add	r4, r3
     e44: b2a5         	uxth	r5, r4
     e46: fb05 f508    	mul	r5, r5, r8
     e4a: 0e6d         	lsrs	r5, r5, #0x19
     e4c: fb05 4412    	mls	r4, r5, r2, r4
     e50: fa13 f484    	uxtah	r4, r3, r4
     e54: f5b4 752f    	subs.w	r5, r4, #0x2bc
     e58: bf38         	it	lo
     e5a: 4625         	movlo	r5, r4
     e5c: 18ec         	adds	r4, r5, r3
     e5e: fba4 560c    	umull	r5, r6, r4, r12
     e62: 0a35         	lsrs	r5, r6, #0x8
     e64: fb05 4412    	mls	r4, r5, r2, r4
     e68: 441c         	add	r4, r3
     e6a: f5b4 7f2f    	cmp.w	r4, #0x2bc
     e6e: bf28         	it	hs
     e70: 4474         	addhs	r4, lr
     e72: 441c         	add	r4, r3
     e74: b2a5         	uxth	r5, r4
     e76: fb05 f508    	mul	r5, r5, r8
     e7a: 0e6d         	lsrs	r5, r5, #0x19
     e7c: fb05 4412    	mls	r4, r5, r2, r4
     e80: fa13 f484    	uxtah	r4, r3, r4
     e84: f5b4 752f    	subs.w	r5, r4, #0x2bc
     e88: bf38         	it	lo
     e8a: 4625         	movlo	r5, r4
     e8c: 18ec         	adds	r4, r5, r3
     e8e: fba4 560c    	umull	r5, r6, r4, r12
     e92: 0a35         	lsrs	r5, r6, #0x8
     e94: fb05 4412    	mls	r4, r5, r2, r4
     e98: 441c         	add	r4, r3
     e9a: f5b4 7f2f    	cmp.w	r4, #0x2bc
     e9e: bf28         	it	hs
     ea0: 4474         	addhs	r4, lr
     ea2: 441c         	add	r4, r3
     ea4: b2a5         	uxth	r5, r4
     ea6: fb05 f508    	mul	r5, r5, r8
     eaa: 0e6d         	lsrs	r5, r5, #0x19
     eac: fb05 4412    	mls	r4, r5, r2, r4
     eb0: fa13 f484    	uxtah	r4, r3, r4
     eb4: f5b4 752f    	subs.w	r5, r4, #0x2bc
     eb8: bf38         	it	lo
     eba: 4625         	movlo	r5, r4
     ebc: 18ec         	adds	r4, r5, r3
     ebe: fba4 560c    	umull	r5, r6, r4, r12
     ec2: 0a35         	lsrs	r5, r6, #0x8
     ec4: fb05 4412    	mls	r4, r5, r2, r4
     ec8: 441c         	add	r4, r3
     eca: f5b4 7f2f    	cmp.w	r4, #0x2bc
     ece: bf28         	it	hs
     ed0: 4474         	addhs	r4, lr
     ed2: 441c         	add	r4, r3
     ed4: b2a5         	uxth	r5, r4
     ed6: fb05 f508    	mul	r5, r5, r8
     eda: 0e6d         	lsrs	r5, r5, #0x19
     edc: fb05 4412    	mls	r4, r5, r2, r4
     ee0: fa13 f484    	uxtah	r4, r3, r4
     ee4: f5b4 752f    	subs.w	r5, r4, #0x2bc
     ee8: bf38         	it	lo
     eea: 4625         	movlo	r5, r4
     eec: 18ec         	adds	r4, r5, r3
     eee: fba4 560c    	umull	r5, r6, r4, r12
     ef2: 0a35         	lsrs	r5, r6, #0x8
     ef4: fb05 4412    	mls	r4, r5, r2, r4
     ef8: 441c         	add	r4, r3
     efa: f5b4 7f2f    	cmp.w	r4, #0x2bc
     efe: bf28         	it	hs
     f00: 4474         	addhs	r4, lr
     f02: 441c         	add	r4, r3
     f04: b2a5         	uxth	r5, r4
     f06: fb05 f508    	mul	r5, r5, r8
     f0a: 0e6d         	lsrs	r5, r5, #0x19
     f0c: fb05 4412    	mls	r4, r5, r2, r4
     f10: fa13 f484    	uxtah	r4, r3, r4
     f14: f5b4 752f    	subs.w	r5, r4, #0x2bc
     f18: bf38         	it	lo
     f1a: 4625         	movlo	r5, r4
     f1c: 18ec         	adds	r4, r5, r3
     f1e: fba4 560c    	umull	r5, r6, r4, r12
     f22: 0a35         	lsrs	r5, r6, #0x8
     f24: fb05 4412    	mls	r4, r5, r2, r4
     f28: 441c         	add	r4, r3
     f2a: f5b4 7f2f    	cmp.w	r4, #0x2bc
     f2e: bf28         	it	hs
     f30: 4474         	addhs	r4, lr
     f32: 18e6         	adds	r6, r4, r3
     f34: b2b5         	uxth	r5, r6
     f36: fb05 f508    	mul	r5, r5, r8
     f3a: 0e6d         	lsrs	r5, r5, #0x19
     f3c: fb05 6612    	mls	r6, r5, r2, r6
     f40: fa13 f686    	uxtah	r6, r3, r6
     f44: f5b6 752f    	subs.w	r5, r6, #0x2bc
     f48: bf38         	it	lo
     f4a: 4635         	movlo	r5, r6
     f4c: 442b         	add	r3, r5
     f4e: 2800         	cmp	r0, #0x0
     f50: fba3 560c    	umull	r5, r6, r3, r12
     f54: f000 8099    	beq.w	0x108a <recovery_block_sample_alternate+0x32e> @ imm = #0x132
     f58: f010 0503    	ands	r5, r0, #0x3
     f5c: f040 8095    	bne.w	0x108a <recovery_block_sample_alternate+0x32e> @ imm = #0x12a
     f60: 0a36         	lsrs	r6, r6, #0x8
     f62: f10d 0904    	add.w	r9, sp, #0x4
     f66: fb06 3212    	mls	r2, r6, r2, r3
     f6a: f119 0f05    	cmn.w	r9, #0x5
     f6e: f04f 0600    	mov.w	r6, #0x0
     f72: bf88         	it	hi
     f74: 2601         	movhi	r6, #0x1
     f76: f119 0f09    	cmn.w	r9, #0x9
     f7a: f04f 0300    	mov.w	r3, #0x0
     f7e: f102 0564    	add.w	r5, r2, #0x64
     f82: bf88         	it	hi
     f84: 2301         	movhi	r3, #0x1
     f86: f119 0f0d    	cmn.w	r9, #0xd
     f8a: f04f 0200    	mov.w	r2, #0x0
     f8e: f04f 0400    	mov.w	r4, #0x0
     f92: bf88         	it	hi
     f94: 2201         	movhi	r2, #0x1
     f96: f119 0f11    	cmn.w	r9, #0x11
     f9a: bf88         	it	hi
     f9c: 2401         	movhi	r4, #0x1
     f9e: f119 0f15    	cmn.w	r9, #0x15
     fa2: 6045         	str	r5, [r0, #0x4]
     fa4: d871         	bhi	0x108a <recovery_block_sample_alternate+0x32e> @ imm = #0xe2
     fa6: 2c00         	cmp	r4, #0x0
     fa8: d16f         	bne	0x108a <recovery_block_sample_alternate+0x32e> @ imm = #0xde
     faa: 2a00         	cmp	r2, #0x0
     fac: d16d         	bne	0x108a <recovery_block_sample_alternate+0x32e> @ imm = #0xda
     fae: 2e00         	cmp	r6, #0x0
     fb0: d16b         	bne	0x108a <recovery_block_sample_alternate+0x32e> @ imm = #0xd6
     fb2: 2b00         	cmp	r3, #0x0
     fb4: d169         	bne	0x108a <recovery_block_sample_alternate+0x32e> @ imm = #0xd2
     fb6: 6802         	ldr	r2, [r0]
     fb8: f649 53c5    	movw	r3, #0x9dc5
     fbc: f240 1493    	movw	r4, #0x193
     fc0: f2c8 131c    	movt	r3, #0x811c
     fc4: f2c0 1400    	movt	r4, #0x100
     fc8: 405a         	eors	r2, r3
     fca: f100 0e08    	add.w	lr, r0, #0x8
     fce: fb02 fa04    	mul	r10, r2, r4
     fd2: e89e 4900    	ldm.w	lr, {r8, r11, lr}
     fd6: ea85 62fa    	eor.w	r2, r5, r10, ror #27
     fda: 4362         	muls	r2, r4, r2
     fdc: ea88 62f2    	eor.w	r2, r8, r2, ror #27
     fe0: 4362         	muls	r2, r4, r2
     fe2: ea8b 62f2    	eor.w	r2, r11, r2, ror #27
     fe6: 4362         	muls	r2, r4, r2
     fe8: f8d0 c014    	ldr.w	r12, [r0, #0x14]
     fec: ea8e 62f2    	eor.w	r2, lr, r2, ror #27
     ff0: 4362         	muls	r2, r4, r2
     ff2: ea8c 62f2    	eor.w	r2, r12, r2, ror #27
     ff6: 4362         	muls	r2, r4, r2
     ff8: ea4f 65f2    	ror.w	r5, r2, #0x1b
     ffc: 6185         	str	r5, [r0, #0x18]
     ffe: 6849         	ldr	r1, [r1, #0x4]
    1000: 074a         	lsls	r2, r1, #0x1d
    1002: d539         	bpl	0x1078 <recovery_block_sample_alternate+0x31c> @ imm = #0x72
    1004: f10b 0201    	add.w	r2, r11, #0x1
    1008: f119 0f05    	cmn.w	r9, #0x5
    100c: f04f 0600    	mov.w	r6, #0x0
    1010: 9200         	str	r2, [sp]
    1012: bf88         	it	hi
    1014: 2601         	movhi	r6, #0x1
    1016: f119 0f09    	cmn.w	r9, #0x9
    101a: f04f 0500    	mov.w	r5, #0x0
    101e: bf88         	it	hi
    1020: 2501         	movhi	r5, #0x1
    1022: f119 0f0d    	cmn.w	r9, #0xd
    1026: f04f 0200    	mov.w	r2, #0x0
    102a: f04f 0300    	mov.w	r3, #0x0
    102e: bf88         	it	hi
    1030: 2201         	movhi	r2, #0x1
    1032: f119 0f11    	cmn.w	r9, #0x11
    1036: bf88         	it	hi
    1038: 2301         	movhi	r3, #0x1
    103a: f119 0f15    	cmn.w	r9, #0x15
    103e: f8dd 9000    	ldr.w	r9, [sp]
    1042: f8c0 9004    	str.w	r9, [r0, #0x4]
    1046: d820         	bhi	0x108a <recovery_block_sample_alternate+0x32e> @ imm = #0x40
    1048: b9fb         	cbnz	r3, 0x108a <recovery_block_sample_alternate+0x32e> @ imm = #0x3e
    104a: b9f2         	cbnz	r2, 0x108a <recovery_block_sample_alternate+0x32e> @ imm = #0x3c
    104c: b9ee         	cbnz	r6, 0x108a <recovery_block_sample_alternate+0x32e> @ imm = #0x3a
    104e: b9e5         	cbnz	r5, 0x108a <recovery_block_sample_alternate+0x32e> @ imm = #0x38
    1050: ea4f 62fa    	ror.w	r2, r10, #0x1b
    1054: ea82 0209    	eor.w	r2, r2, r9
    1058: 4362         	muls	r2, r4, r2
    105a: ea88 62f2    	eor.w	r2, r8, r2, ror #27
    105e: 4362         	muls	r2, r4, r2
    1060: ea8b 62f2    	eor.w	r2, r11, r2, ror #27
    1064: 4362         	muls	r2, r4, r2
    1066: ea8e 62f2    	eor.w	r2, lr, r2, ror #27
    106a: 4362         	muls	r2, r4, r2
    106c: ea8c 62f2    	eor.w	r2, r12, r2, ror #27
    1070: 4362         	muls	r2, r4, r2
    1072: ea4f 65f2    	ror.w	r5, r2, #0x1b
    1076: 6185         	str	r5, [r0, #0x18]
    1078: 0709         	lsls	r1, r1, #0x1c
    107a: bf44         	itt	mi
    107c: f085 0110    	eormi	r1, r5, #0x10
    1080: 6181         	strmi	r1, [r0, #0x18]
    1082: b007         	add	sp, #0x1c
    1084: e8bd 0f00    	pop.w	{r8, r9, r10, r11}
    1088: bdf0         	pop	{r4, r5, r6, r7, pc}
    108a: defe         	trap
    108c: fe ca 05 c1  	.word	0xc105cafe
    1090: 42 f8 42 59  	.word	0x5942f842

00001094 <apply_after_alternate_fault>:
    1094: b580         	push	{r7, lr}
    1096: 466f         	mov	r7, sp
    1098: f240 0100    	movw	r1, #0x0
    109c: f2c2 0100    	movt	r1, #0x2000
    10a0: 220a         	movs	r2, #0xa
    10a2: 600a         	str	r2, [r1]
    10a4: f240 0168    	movw	r1, #0x68
    10a8: f2c2 0100    	movt	r1, #0x2000
    10ac: 6809         	ldr	r1, [r1]
    10ae: 2916         	cmp	r1, #0x16
    10b0: d107         	bne	0x10c2 <apply_after_alternate_fault+0x2e> @ imm = #0xe
    10b2: b1b8         	cbz	r0, 0x10e4 <apply_after_alternate_fault+0x50> @ imm = #0x2e
    10b4: f010 0103    	ands	r1, r0, #0x3
    10b8: d114         	bne	0x10e4 <apply_after_alternate_fault+0x50> @ imm = #0x28
    10ba: 6981         	ldr	r1, [r0, #0x18]
    10bc: f081 0110    	eor	r1, r1, #0x10
    10c0: 6181         	str	r1, [r0, #0x18]
    10c2: f240 0030    	movw	r0, #0x30
    10c6: f2c2 0000    	movt	r0, #0x2000
    10ca: f240 016c    	movw	r1, #0x6c
    10ce: 6842         	ldr	r2, [r0, #0x4]
    10d0: f2c2 0100    	movt	r1, #0x2000
    10d4: 6a00         	ldr	r0, [r0, #0x20]
    10d6: 600a         	str	r2, [r1]
    10d8: f240 0174    	movw	r1, #0x74
    10dc: f2c2 0100    	movt	r1, #0x2000
    10e0: 6008         	str	r0, [r1]
    10e2: bd80         	pop	{r7, pc}
    10e4: defe         	trap
    10e6: d4d4         	bmi	0x1092 <recovery_block_sample_alternate+0x336> @ imm = #-0x58

000010e8 <compiler_rt.arm.__aeabi_unwind_cpp_pr0>:
    10e8: b580         	push	{r7, lr}
    10ea: 466f         	mov	r7, sp
    10ec: bd80         	pop	{r7, pc}
    10ee: d4d4         	bmi	0x109a <apply_after_alternate_fault+0x6> @ imm = #-0x58
    10f0: 9746         	str	r7, [sp, #0x118]
    10f2: 8101         	strh	r1, [r0, #0x8]
    10f4: abb0         	add	r3, sp, #0x2c0
    10f6: 80f0         	strh	r0, [r6, #0x6]
    10f8: 0000         	movs	r0, r0
    10fa: 0000         	movs	r0, r0
    10fc: 9746         	str	r7, [sp, #0x118]
    10fe: 8101         	strh	r1, [r0, #0x8]
    1100: abb0         	add	r3, sp, #0x2c0
    1102: 80f0         	strh	r0, [r6, #0x6]
    1104: 0000         	movs	r0, r0
    1106: 0000         	movs	r0, r0
    1108: 9746         	str	r7, [sp, #0x118]
    110a: 8101         	strh	r1, [r0, #0x8]
    110c: abb0         	add	r3, sp, #0x2c0
    110e: 80f0         	strh	r0, [r6, #0x6]
    1110: 0000         	movs	r0, r0
    1112: 0000         	movs	r0, r0
