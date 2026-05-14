
zig-out/harness/recovery-block-harness-zig-m4.elf:	file format elf32-littlearm

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
      54: f000 f80a    	bl	0x6c <recovery_block_harness.harness_main> @ imm = #0x14
      58: e7fe         	b	0x58 <_start+0x18>      @ imm = #-0x4

0000005a <Default_Handler>:
      5a: f7ff bffe    	b.w	0x5a <Default_Handler>  @ imm = #-0x4
      5e: 0000         	movs	r0, r0
      60: 00 00 40 20  	.word	0x20400000
      64: 00 00 00 20  	.word	0x20000000
      68: 60 00 00 20  	.word	0x20000060

0000006c <recovery_block_harness.harness_main>:
      6c: b5f0         	push	{r4, r5, r6, r7, lr}
      6e: af03         	add	r7, sp, #0xc
      70: e92d 0f00    	push.w	{r8, r9, r10, r11}
      74: b083         	sub	sp, #0xc
      76: f240 0600    	movw	r6, #0x0
      7a: f2c2 0600    	movt	r6, #0x2000
      7e: 2000         	movs	r0, #0x0
      80: 65b0         	str	r0, [r6, #0x58]
      82: e011         	b	0xa8 <recovery_block_harness.harness_main+0x3c> @ imm = #0x22
      84: f1be 0f00    	cmp.w	lr, #0x0
      88: bf18         	it	ne
      8a: 4610         	movne	r0, r2
      8c: 4329         	orrs	r1, r5
      8e: f1bc 0f02    	cmp.w	r12, #0x2
      92: bf18         	it	ne
      94: 4610         	movne	r0, r2
      96: 2900         	cmp	r1, #0x0
      98: bf18         	it	ne
      9a: 4610         	movne	r0, r2
      9c: 4430         	add	r0, r6
      9e: 6801         	ldr	r1, [r0]
      a0: 3101         	adds	r1, #0x1
      a2: 6001         	str	r1, [r0]
      a4: f000 faa6    	bl	0x5f4 <recovery_block_harness.harness_injection_point_after_recovery> @ imm = #0x54c
      a8: 6df0         	ldr	r0, [r6, #0x5c]
      aa: 211d         	movs	r1, #0x1d
      ac: 3001         	adds	r0, #0x1
      ae: f247 3591    	movw	r5, #0x7391
      b2: 4341         	muls	r1, r0, r1
      b4: f6c5 559f    	movt	r5, #0x5d9f
      b8: fba1 2305    	umull	r2, r3, r1, r5
      bc: fba0 2505    	umull	r2, r5, r0, r5
      c0: 0a1a         	lsrs	r2, r3, #0x8
      c2: 0a2b         	lsrs	r3, r5, #0x8
      c4: f44f 752f    	mov.w	r5, #0x2bc
      c8: fb03 0b15    	mls	r11, r3, r5, r0
      cc: fb02 1115    	mls	r1, r2, r5, r1
      d0: 2225         	movs	r2, #0x25
      d2: fb0b f202    	mul	r2, r11, r2
      d6: 3211         	adds	r2, #0x11
      d8: b293         	uxth	r3, r2
      da: f64b 343f    	movw	r4, #0xbb3f
      de: 4363         	muls	r3, r4, r3
      e0: 0e5b         	lsrs	r3, r3, #0x19
      e2: f247 1480    	movw	r4, #0x7180
      e6: fb03 2215    	mls	r2, r3, r5, r2
      ea: f101 0364    	add.w	r3, r1, #0x64
      ee: f2c8 148b    	movt	r4, #0x818b
      f2: f240 1893    	movw	r8, #0x193
      f6: 65f0         	str	r0, [r6, #0x5c]
      f8: ea83 0004    	eor.w	r0, r3, r4
      fc: f2c0 1800    	movt	r8, #0x100
     100: fb00 f008    	mul	r0, r0, r8
     104: f102 0164    	add.w	r1, r2, #0x64
     108: ea4f 60f0    	ror.w	r0, r0, #0x1b
     10c: fa1f f981    	uxth.w	r9, r1
     110: fb00 f008    	mul	r0, r0, r8
     114: f44f 717a    	mov.w	r1, #0x3e8
     118: ea81 60f0    	eor.w	r0, r1, r0, ror #27
     11c: fb00 f008    	mul	r0, r0, r8
     120: 2506         	movs	r5, #0x6
     122: ea85 60f0    	eor.w	r0, r5, r0, ror #27
     126: fb00 f008    	mul	r0, r0, r8
     12a: 2110         	movs	r1, #0x10
     12c: ea81 60f0    	eor.w	r0, r1, r0, ror #27
     130: fb00 f008    	mul	r0, r0, r8
     134: ea4f 61f0    	ror.w	r1, r0, #0x1b
     138: 2000         	movs	r0, #0x0
     13a: 6433         	str	r3, [r6, #0x40]
     13c: f8c6 9044    	str.w	r9, [r6, #0x44]
     140: 63f0         	str	r0, [r6, #0x3c]
     142: 63b0         	str	r0, [r6, #0x38]
     144: 6330         	str	r0, [r6, #0x30]
     146: 62b0         	str	r0, [r6, #0x28]
     148: 6270         	str	r0, [r6, #0x24]
     14a: 61f0         	str	r0, [r6, #0x1c]
     14c: 6170         	str	r0, [r6, #0x14]
     14e: 6530         	str	r0, [r6, #0x50]
     150: 2001         	movs	r0, #0x1
     152: 60f3         	str	r3, [r6, #0xc]
     154: 9301         	str	r3, [sp, #0x4]
     156: 60b3         	str	r3, [r6, #0x8]
     158: 6230         	str	r0, [r6, #0x20]
     15a: 64b5         	str	r5, [r6, #0x48]
     15c: 6371         	str	r1, [r6, #0x34]
     15e: 62f0         	str	r0, [r6, #0x2c]
     160: 2008         	movs	r0, #0x8
     162: 6035         	str	r5, [r6]
     164: 468a         	mov	r10, r1
     166: 61b1         	str	r1, [r6, #0x18]
     168: 65b0         	str	r0, [r6, #0x58]
     16a: f000 fa47    	bl	0x5fc <recovery_block_harness.harness_injection_point_before_recovery> @ imm = #0x48e
     16e: 6d70         	ldr	r0, [r6, #0x54]
     170: f44f 717a    	mov.w	r1, #0x3e8
     174: 6530         	str	r0, [r6, #0x50]
     176: ea89 0004    	eor.w	r0, r9, r4
     17a: fb00 f008    	mul	r0, r0, r8
     17e: ea4f 60f0    	ror.w	r0, r0, #0x1b
     182: fb00 f008    	mul	r0, r0, r8
     186: ea81 60f0    	eor.w	r0, r1, r0, ror #27
     18a: fb00 f008    	mul	r0, r0, r8
     18e: ea85 60f0    	eor.w	r0, r5, r0, ror #27
     192: fb00 f008    	mul	r0, r0, r8
     196: 2110         	movs	r1, #0x10
     198: ea81 60f0    	eor.w	r0, r1, r0, ror #27
     19c: 2109         	movs	r1, #0x9
     19e: f8cd 9008    	str.w	r9, [sp, #0x8]
     1a2: 65b1         	str	r1, [r6, #0x58]
     1a4: 6d71         	ldr	r1, [r6, #0x54]
     1a6: fb00 f208    	mul	r2, r0, r8
     1aa: f1a1 0014    	sub.w	r0, r1, #0x14
     1ae: f44f 7e7a    	mov.w	lr, #0x3e8
     1b2: f04f 0c10    	mov.w	r12, #0x10
     1b6: 2803         	cmp	r0, #0x3
     1b8: ea4f 61f2    	ror.w	r1, r2, #0x1b
     1bc: d808         	bhi	0x1d0 <recovery_block_harness.harness_main+0x164> @ imm = #0x10
     1be: e8df f000    	tbb	[pc, r0]
     1c2: 03 05 03 0b  	.word	0x0b030503
     1c6: 00 bf        	.short	0xbf00
     1c8: 6cf0         	ldr	r0, [r6, #0x4c]
     1ca: e002         	b	0x1d2 <recovery_block_harness.harness_main+0x166> @ imm = #0x4
     1cc: 6cf0         	ldr	r0, [r6, #0x4c]
     1ce: 4041         	eors	r1, r0
     1d0: 9802         	ldr	r0, [sp, #0x8]
     1d2: 46d0         	mov	r8, r10
     1d4: 4653         	mov	r3, r10
     1d6: e003         	b	0x1e0 <recovery_block_harness.harness_main+0x174> @ imm = #0x6
     1d8: 6cf0         	ldr	r0, [r6, #0x4c]
     1da: 46d0         	mov	r8, r10
     1dc: f08a 0310    	eor	r3, r10, #0x10
     1e0: f8dd 9004    	ldr.w	r9, [sp, #0x4]
     1e4: 2201         	movs	r2, #0x1
     1e6: f5b0 7f7a    	cmp.w	r0, #0x3e8
     1ea: 60f0         	str	r0, [r6, #0xc]
     1ec: f8c6 9008    	str.w	r9, [r6, #0x8]
     1f0: 6232         	str	r2, [r6, #0x20]
     1f2: 64b5         	str	r5, [r6, #0x48]
     1f4: 6371         	str	r1, [r6, #0x34]
     1f6: 62f2         	str	r2, [r6, #0x2c]
     1f8: 6035         	str	r5, [r6]
     1fa: 61b3         	str	r3, [r6, #0x18]
     1fc: f240 812a    	bls.w	0x454 <recovery_block_harness.harness_main+0x3e8> @ imm = #0x254
     200: f04f 0a02    	mov.w	r10, #0x2
     204: f04f 0c06    	mov.w	r12, #0x6
     208: 4598         	cmp	r8, r3
     20a: f040 814e    	bne.w	0x4aa <recovery_block_harness.harness_main+0x43e> @ imm = #0x29c
     20e: f240 20ab    	movw	r0, #0x2ab
     212: 4583         	cmp	r11, r0
     214: f64f 5055    	movw	r0, #0xfd55
     218: f6cf 70ff    	movt	r0, #0xffff
     21c: bf38         	it	lo
     21e: 2011         	movlo	r0, #0x11
     220: f247 3391    	movw	r3, #0x7391
     224: eb00 004b    	add.w	r0, r0, r11, lsl #1
     228: f6c5 539f    	movt	r3, #0x5d9f
     22c: fba0 1203    	umull	r1, r2, r0, r3
     230: 0a11         	lsrs	r1, r2, #0x8
     232: f44f 752f    	mov.w	r5, #0x2bc
     236: fb01 0015    	mls	r0, r1, r5, r0
     23a: 2406         	movs	r4, #0x6
     23c: 4458         	add	r0, r11
     23e: f5b0 712f    	subs.w	r1, r0, #0x2bc
     242: bf38         	it	lo
     244: 4601         	movlo	r1, r0
     246: eb01 000b    	add.w	r0, r1, r11
     24a: fba0 1203    	umull	r1, r2, r0, r3
     24e: 0a11         	lsrs	r1, r2, #0x8
     250: fb01 0015    	mls	r0, r1, r5, r0
     254: 46a4         	mov	r12, r4
     256: 4458         	add	r0, r11
     258: f5b0 712f    	subs.w	r1, r0, #0x2bc
     25c: bf38         	it	lo
     25e: 4601         	movlo	r1, r0
     260: eb01 000b    	add.w	r0, r1, r11
     264: fba0 1203    	umull	r1, r2, r0, r3
     268: 0a11         	lsrs	r1, r2, #0x8
     26a: fb01 0015    	mls	r0, r1, r5, r0
     26e: 4458         	add	r0, r11
     270: f5b0 712f    	subs.w	r1, r0, #0x2bc
     274: bf38         	it	lo
     276: 4601         	movlo	r1, r0
     278: eb01 000b    	add.w	r0, r1, r11
     27c: fba0 1203    	umull	r1, r2, r0, r3
     280: 0a11         	lsrs	r1, r2, #0x8
     282: fb01 0015    	mls	r0, r1, r5, r0
     286: 4458         	add	r0, r11
     288: f5b0 712f    	subs.w	r1, r0, #0x2bc
     28c: bf38         	it	lo
     28e: 4601         	movlo	r1, r0
     290: eb01 000b    	add.w	r0, r1, r11
     294: fba0 1203    	umull	r1, r2, r0, r3
     298: 0a11         	lsrs	r1, r2, #0x8
     29a: fb01 0015    	mls	r0, r1, r5, r0
     29e: 4458         	add	r0, r11
     2a0: f5b0 712f    	subs.w	r1, r0, #0x2bc
     2a4: bf38         	it	lo
     2a6: 4601         	movlo	r1, r0
     2a8: eb01 000b    	add.w	r0, r1, r11
     2ac: fba0 1203    	umull	r1, r2, r0, r3
     2b0: 0a11         	lsrs	r1, r2, #0x8
     2b2: fb01 0015    	mls	r0, r1, r5, r0
     2b6: 4458         	add	r0, r11
     2b8: f5b0 712f    	subs.w	r1, r0, #0x2bc
     2bc: bf38         	it	lo
     2be: 4601         	movlo	r1, r0
     2c0: eb01 000b    	add.w	r0, r1, r11
     2c4: fba0 1203    	umull	r1, r2, r0, r3
     2c8: 0a11         	lsrs	r1, r2, #0x8
     2ca: fb01 0015    	mls	r0, r1, r5, r0
     2ce: 4458         	add	r0, r11
     2d0: f5b0 712f    	subs.w	r1, r0, #0x2bc
     2d4: bf38         	it	lo
     2d6: 4601         	movlo	r1, r0
     2d8: eb01 000b    	add.w	r0, r1, r11
     2dc: fba0 1203    	umull	r1, r2, r0, r3
     2e0: 0a11         	lsrs	r1, r2, #0x8
     2e2: fb01 0015    	mls	r0, r1, r5, r0
     2e6: 4458         	add	r0, r11
     2e8: f5b0 712f    	subs.w	r1, r0, #0x2bc
     2ec: bf38         	it	lo
     2ee: 4601         	movlo	r1, r0
     2f0: eb01 000b    	add.w	r0, r1, r11
     2f4: fba0 1203    	umull	r1, r2, r0, r3
     2f8: 0a11         	lsrs	r1, r2, #0x8
     2fa: fb01 0015    	mls	r0, r1, r5, r0
     2fe: 4458         	add	r0, r11
     300: f5b0 712f    	subs.w	r1, r0, #0x2bc
     304: bf38         	it	lo
     306: 4601         	movlo	r1, r0
     308: eb01 000b    	add.w	r0, r1, r11
     30c: fba0 1203    	umull	r1, r2, r0, r3
     310: 0a11         	lsrs	r1, r2, #0x8
     312: fb01 0015    	mls	r0, r1, r5, r0
     316: 4458         	add	r0, r11
     318: f5b0 712f    	subs.w	r1, r0, #0x2bc
     31c: bf38         	it	lo
     31e: 4601         	movlo	r1, r0
     320: eb01 000b    	add.w	r0, r1, r11
     324: fba0 1203    	umull	r1, r2, r0, r3
     328: 0a11         	lsrs	r1, r2, #0x8
     32a: fb01 0015    	mls	r0, r1, r5, r0
     32e: 4458         	add	r0, r11
     330: f5b0 712f    	subs.w	r1, r0, #0x2bc
     334: bf38         	it	lo
     336: 4601         	movlo	r1, r0
     338: eb01 000b    	add.w	r0, r1, r11
     33c: fba0 1203    	umull	r1, r2, r0, r3
     340: 0a11         	lsrs	r1, r2, #0x8
     342: fb01 0015    	mls	r0, r1, r5, r0
     346: 4458         	add	r0, r11
     348: f5b0 712f    	subs.w	r1, r0, #0x2bc
     34c: bf38         	it	lo
     34e: 4601         	movlo	r1, r0
     350: eb01 000b    	add.w	r0, r1, r11
     354: fba0 1203    	umull	r1, r2, r0, r3
     358: 0a11         	lsrs	r1, r2, #0x8
     35a: fb01 0015    	mls	r0, r1, r5, r0
     35e: 4458         	add	r0, r11
     360: f5b0 712f    	subs.w	r1, r0, #0x2bc
     364: bf38         	it	lo
     366: 4601         	movlo	r1, r0
     368: eb01 000b    	add.w	r0, r1, r11
     36c: fba0 1203    	umull	r1, r2, r0, r3
     370: 0a11         	lsrs	r1, r2, #0x8
     372: fb01 0015    	mls	r0, r1, r5, r0
     376: 4458         	add	r0, r11
     378: f5b0 712f    	subs.w	r1, r0, #0x2bc
     37c: bf38         	it	lo
     37e: 4601         	movlo	r1, r0
     380: eb01 000b    	add.w	r0, r1, r11
     384: fba0 1203    	umull	r1, r2, r0, r3
     388: 0a11         	lsrs	r1, r2, #0x8
     38a: fb01 0015    	mls	r0, r1, r5, r0
     38e: 4458         	add	r0, r11
     390: f5b0 712f    	subs.w	r1, r0, #0x2bc
     394: bf38         	it	lo
     396: 4601         	movlo	r1, r0
     398: eb01 000b    	add.w	r0, r1, r11
     39c: fba0 1203    	umull	r1, r2, r0, r3
     3a0: 0a11         	lsrs	r1, r2, #0x8
     3a2: fb01 0015    	mls	r0, r1, r5, r0
     3a6: 4458         	add	r0, r11
     3a8: f5b0 712f    	subs.w	r1, r0, #0x2bc
     3ac: bf38         	it	lo
     3ae: 4601         	movlo	r1, r0
     3b0: eb01 000b    	add.w	r0, r1, r11
     3b4: fba0 1203    	umull	r1, r2, r0, r3
     3b8: 0a11         	lsrs	r1, r2, #0x8
     3ba: fb01 0015    	mls	r0, r1, r5, r0
     3be: 4458         	add	r0, r11
     3c0: f5b0 712f    	subs.w	r1, r0, #0x2bc
     3c4: bf38         	it	lo
     3c6: 4601         	movlo	r1, r0
     3c8: eb01 000b    	add.w	r0, r1, r11
     3cc: fba0 1203    	umull	r1, r2, r0, r3
     3d0: 0a11         	lsrs	r1, r2, #0x8
     3d2: fb01 0015    	mls	r0, r1, r5, r0
     3d6: f240 1293    	movw	r2, #0x193
     3da: 4458         	add	r0, r11
     3dc: f5b0 712f    	subs.w	r1, r0, #0x2bc
     3e0: bf38         	it	lo
     3e2: 4601         	movlo	r1, r0
     3e4: f101 0064    	add.w	r0, r1, #0x64
     3e8: f247 1180    	movw	r1, #0x7180
     3ec: f2c8 118b    	movt	r1, #0x818b
     3f0: 4041         	eors	r1, r0
     3f2: f2c0 1200    	movt	r2, #0x100
     3f6: 4351         	muls	r1, r2, r1
     3f8: ea4f 61f1    	ror.w	r1, r1, #0x1b
     3fc: 4351         	muls	r1, r2, r1
     3fe: ea8e 61f1    	eor.w	r1, lr, r1, ror #27
     402: 4351         	muls	r1, r2, r1
     404: ea84 61f1    	eor.w	r1, r4, r1, ror #27
     408: 4351         	muls	r1, r2, r1
     40a: 2510         	movs	r5, #0x10
     40c: ea85 61f1    	eor.w	r1, r5, r1, ror #27
     410: 434a         	muls	r2, r1, r2
     412: 210a         	movs	r1, #0xa
     414: 65b1         	str	r1, [r6, #0x58]
     416: 6d73         	ldr	r3, [r6, #0x54]
     418: ea4f 61f2    	ror.w	r1, r2, #0x1b
     41c: 2b16         	cmp	r3, #0x16
     41e: 460b         	mov	r3, r1
     420: bf08         	it	eq
     422: ea85 63f2    	eoreq.w	r3, r5, r2, ror #27
     426: f04f 0501    	mov.w	r5, #0x1
     42a: 60f0         	str	r0, [r6, #0xc]
     42c: f8c6 9008    	str.w	r9, [r6, #0x8]
     430: 6235         	str	r5, [r6, #0x20]
     432: 64b4         	str	r4, [r6, #0x48]
     434: 6373         	str	r3, [r6, #0x34]
     436: 62f5         	str	r5, [r6, #0x2c]
     438: 6034         	str	r4, [r6]
     43a: f8c6 8018    	str.w	r8, [r6, #0x18]
     43e: d13b         	bne	0x4b8 <recovery_block_harness.harness_main+0x44c> @ imm = #0x76
     440: 2502         	movs	r5, #0x2
     442: 2400         	movs	r4, #0x0
     444: f04f 0e04    	mov.w	lr, #0x4
     448: 4641         	mov	r1, r8
     44a: 4648         	mov	r0, r9
     44c: 4643         	mov	r3, r8
     44e: 464a         	mov	r2, r9
     450: e038         	b	0x4c4 <recovery_block_harness.harness_main+0x458> @ imm = #0x70
     452: bf00         	nop
     454: f247 1280    	movw	r2, #0x7180
     458: f2c8 128b    	movt	r2, #0x818b
     45c: f240 1493    	movw	r4, #0x193
     460: 4042         	eors	r2, r0
     462: f2c0 1400    	movt	r4, #0x100
     466: 4362         	muls	r2, r4, r2
     468: ea4f 62f2    	ror.w	r2, r2, #0x1b
     46c: 4362         	muls	r2, r4, r2
     46e: ea8e 62f2    	eor.w	r2, lr, r2, ror #27
     472: 4362         	muls	r2, r4, r2
     474: ea85 62f2    	eor.w	r2, r5, r2, ror #27
     478: 4362         	muls	r2, r4, r2
     47a: ea8c 62f2    	eor.w	r2, r12, r2, ror #27
     47e: 4362         	muls	r2, r4, r2
     480: ebb1 6ff2    	cmp.w	r1, r2, ror #27
     484: d10a         	bne	0x49c <recovery_block_harness.harness_main+0x430> @ imm = #0x14
     486: f04f 0c06    	mov.w	r12, #0x6
     48a: f04f 0e00    	mov.w	lr, #0x0
     48e: 2400         	movs	r4, #0x0
     490: f04f 0a00    	mov.w	r10, #0x0
     494: 460b         	mov	r3, r1
     496: 4602         	mov	r2, r0
     498: 2500         	movs	r5, #0x0
     49a: e013         	b	0x4c4 <recovery_block_harness.harness_main+0x458> @ imm = #0x26
     49c: f04f 0a04    	mov.w	r10, #0x4
     4a0: f04f 0c06    	mov.w	r12, #0x6
     4a4: 4598         	cmp	r8, r3
     4a6: f43f aeb2    	beq.w	0x20e <recovery_block_harness.harness_main+0x1a2> @ imm = #-0x29c
     4aa: 2404         	movs	r4, #0x4
     4ac: f04f 0e00    	mov.w	lr, #0x0
     4b0: 464a         	mov	r2, r9
     4b2: 2504         	movs	r5, #0x4
     4b4: e006         	b	0x4c4 <recovery_block_harness.harness_main+0x458> @ imm = #0xc
     4b6: bf00         	nop
     4b8: f04f 0e00    	mov.w	lr, #0x0
     4bc: 2400         	movs	r4, #0x0
     4be: 460b         	mov	r3, r1
     4c0: 4602         	mov	r2, r0
     4c2: bf00         	nop
     4c4: 6335         	str	r5, [r6, #0x30]
     4c6: 63b5         	str	r5, [r6, #0x38]
     4c8: 2500         	movs	r5, #0x0
     4ca: 62b5         	str	r5, [r6, #0x28]
     4cc: f8c6 a024    	str.w	r10, [r6, #0x24]
     4d0: 61f4         	str	r4, [r6, #0x1c]
     4d2: f8c6 e014    	str.w	lr, [r6, #0x14]
     4d6: 60f0         	str	r0, [r6, #0xc]
     4d8: 2001         	movs	r0, #0x1
     4da: 60b2         	str	r2, [r6, #0x8]
     4dc: 6230         	str	r0, [r6, #0x20]
     4de: f8c6 c048    	str.w	r12, [r6, #0x48]
     4e2: 6371         	str	r1, [r6, #0x34]
     4e4: 62f0         	str	r0, [r6, #0x2c]
     4e6: f8c6 c000    	str.w	r12, [r6]
     4ea: 61b3         	str	r3, [r6, #0x18]
     4ec: 68f0         	ldr	r0, [r6, #0xc]
     4ee: 63f0         	str	r0, [r6, #0x3c]
     4f0: 200b         	movs	r0, #0xb
     4f2: 6575         	str	r5, [r6, #0x54]
     4f4: 65b0         	str	r0, [r6, #0x58]
     4f6: 6d31         	ldr	r1, [r6, #0x50]
     4f8: 6b34         	ldr	r4, [r6, #0x30]
     4fa: 6ab5         	ldr	r5, [r6, #0x28]
     4fc: f8d6 c024    	ldr.w	r12, [r6, #0x24]
     500: f8d6 e01c    	ldr.w	lr, [r6, #0x1c]
     504: f8d6 8014    	ldr.w	r8, [r6, #0x14]
     508: 68f3         	ldr	r3, [r6, #0xc]
     50a: 68b0         	ldr	r0, [r6, #0x8]
     50c: 3914         	subs	r1, #0x14
     50e: 2903         	cmp	r1, #0x3
     510: d84a         	bhi	0x5a8 <recovery_block_harness.harness_main+0x53c> @ imm = #0x94
     512: e8df f001    	tbb	[pc, r1]
     516: 15 2f 03 27  	.word	0x27032f15
     51a: 00 bf        	.short	0xbf00
     51c: 4548         	cmp	r0, r9
     51e: f04f 0010    	mov.w	r0, #0x10
     522: bf08         	it	eq
     524: 2004         	moveq	r0, #0x4
     526: 454b         	cmp	r3, r9
     528: f04f 0210    	mov.w	r2, #0x10
     52c: bf18         	it	ne
     52e: 4610         	movne	r0, r2
     530: f1b8 0f04    	cmp.w	r8, #0x4
     534: bf18         	it	ne
     536: 4610         	movne	r0, r2
     538: f084 0102    	eor	r1, r4, #0x2
     53c: e5a2         	b	0x84 <recovery_block_harness.harness_main+0x18> @ imm = #-0x4bc
     53e: bf00         	nop
     540: 9a02         	ldr	r2, [sp, #0x8]
     542: f084 0101    	eor	r1, r4, #0x1
     546: 4290         	cmp	r0, r2
     548: f04f 0010    	mov.w	r0, #0x10
     54c: bf08         	it	eq
     54e: 2004         	moveq	r0, #0x4
     550: 4293         	cmp	r3, r2
     552: f04f 0210    	mov.w	r2, #0x10
     556: bf18         	it	ne
     558: 4610         	movne	r0, r2
     55a: f1b8 0f00    	cmp.w	r8, #0x0
     55e: bf18         	it	ne
     560: 4610         	movne	r0, r2
     562: e58f         	b	0x84 <recovery_block_harness.harness_main+0x18> @ imm = #-0x4e2
     564: 2c04         	cmp	r4, #0x4
     566: bf08         	it	eq
     568: 2d00         	cmpeq	r5, #0x0
     56a: d035         	beq	0x5d8 <recovery_block_harness.harness_main+0x56c> @ imm = #0x6a
     56c: f106 0010    	add.w	r0, r6, #0x10
     570: e595         	b	0x9e <recovery_block_harness.harness_main+0x32> @ imm = #-0x4d6
     572: bf00         	nop
     574: 9a02         	ldr	r2, [sp, #0x8]
     576: f084 0101    	eor	r1, r4, #0x1
     57a: 4290         	cmp	r0, r2
     57c: f04f 0010    	mov.w	r0, #0x10
     580: bf08         	it	eq
     582: 2004         	moveq	r0, #0x4
     584: 4293         	cmp	r3, r2
     586: f04f 0210    	mov.w	r2, #0x10
     58a: bf18         	it	ne
     58c: 4610         	movne	r0, r2
     58e: f1b8 0f00    	cmp.w	r8, #0x0
     592: bf18         	it	ne
     594: 4610         	movne	r0, r2
     596: f1be 0f00    	cmp.w	lr, #0x0
     59a: bf18         	it	ne
     59c: 4610         	movne	r0, r2
     59e: 4329         	orrs	r1, r5
     5a0: f1bc 0f04    	cmp.w	r12, #0x4
     5a4: e575         	b	0x92 <recovery_block_harness.harness_main+0x26> @ imm = #-0x516
     5a6: bf00         	nop
     5a8: 9a02         	ldr	r2, [sp, #0x8]
     5aa: ea44 0105    	orr.w	r1, r4, r5
     5ae: 4290         	cmp	r0, r2
     5b0: f04f 0010    	mov.w	r0, #0x10
     5b4: bf08         	it	eq
     5b6: 2004         	moveq	r0, #0x4
     5b8: 4293         	cmp	r3, r2
     5ba: f04f 0210    	mov.w	r2, #0x10
     5be: bf18         	it	ne
     5c0: 4610         	movne	r0, r2
     5c2: f1b8 0f00    	cmp.w	r8, #0x0
     5c6: bf18         	it	ne
     5c8: 4610         	movne	r0, r2
     5ca: f1be 0f00    	cmp.w	lr, #0x0
     5ce: bf18         	it	ne
     5d0: 4610         	movne	r0, r2
     5d2: f1bc 0f00    	cmp.w	r12, #0x0
     5d6: e55c         	b	0x92 <recovery_block_harness.harness_main+0x26> @ imm = #-0x548
     5d8: f1bc 0f02    	cmp.w	r12, #0x2
     5dc: d1c6         	bne	0x56c <recovery_block_harness.harness_main+0x500> @ imm = #-0x74
     5de: f1be 0f04    	cmp.w	lr, #0x4
     5e2: d1c3         	bne	0x56c <recovery_block_harness.harness_main+0x500> @ imm = #-0x7a
     5e4: f1b8 0f00    	cmp.w	r8, #0x0
     5e8: d1c0         	bne	0x56c <recovery_block_harness.harness_main+0x500> @ imm = #-0x80
     5ea: 6cf0         	ldr	r0, [r6, #0x4c]
     5ec: 4283         	cmp	r3, r0
     5ee: d1bd         	bne	0x56c <recovery_block_harness.harness_main+0x500> @ imm = #-0x86
     5f0: 1d30         	adds	r0, r6, #0x4
     5f2: e554         	b	0x9e <recovery_block_harness.harness_main+0x32> @ imm = #-0x558

000005f4 <recovery_block_harness.harness_injection_point_after_recovery>:
     5f4: b580         	push	{r7, lr}
     5f6: 466f         	mov	r7, sp
     5f8: bf00         	nop
     5fa: bd80         	pop	{r7, pc}

000005fc <recovery_block_harness.harness_injection_point_before_recovery>:
     5fc: b580         	push	{r7, lr}
     5fe: 466f         	mov	r7, sp
     600: bf00         	nop
     602: bd80         	pop	{r7, pc}

00000604 <compiler_rt.arm.__aeabi_unwind_cpp_pr0>:
     604: b580         	push	{r7, lr}
     606: 466f         	mov	r7, sp
     608: bd80         	pop	{r7, pc}
     60a: d4d4         	bmi	0x5b6 <recovery_block_harness.harness_main+0x54a> @ imm = #-0x58
     60c: 9746         	str	r7, [sp, #0x118]
     60e: 8101         	strh	r1, [r0, #0x8]
     610: abb0         	add	r3, sp, #0x2c0
     612: 80f0         	strh	r0, [r6, #0x6]
     614: 0000         	movs	r0, r0
     616: 0000         	movs	r0, r0
