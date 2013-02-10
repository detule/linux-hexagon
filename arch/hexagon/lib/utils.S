/* libgcc routines for the HEXAGON.
   Copyright (C) 1998, 1999 Free Software Foundation, Inc.

This file is part of GCC.

GCC is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation; either version 2, or (at your option) any
later version.

In addition to the permissions in the GNU General Public License, the
Free Software Foundation gives you unlimited permission to link the
compiled version of this file into combinations with other programs,
and to distribute those combinations without any restriction coming
from the use of this file.  (The General Public License restrictions
do apply in other respects; for example, they cover modification of
the file, and distribution when not linked into a combine
executable.)

This file is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; see the file COPYING.  If not, write to
the Free Software Foundation, 59 Temple Place - Suite 330,
Boston, MA 02111-1307, USA.  */

	.macro FUNC_START name
	.text
	.p2align 5
	.globl __hexagon_\name
	.type  __hexagon_\name, @function
__hexagon_\name:
	.endm

	.macro FUNC_END name
	.size  __hexagon_\name, . - __hexagon_\name
	.endm

	.macro FALLTHROUGH_TAIL_CALL name0 name1
	.size  __hexagon_\name0, . - __hexagon_\name0
	.globl __hexagon_\name1
	.type  __hexagon_\name1, @function
__hexagon_\name1:
	.endm

FUNC_START udivmodsi4
	{
		r2 = cl0(r0)
		r3 = cl0(r1)
		r5:4 = combine(#1,#0)
		p0 = cmp.gtu(r1,r0)
	}
	{
		r6 = sub(r3,r2)
		r4 = r1
		r1:0 = combine(r0,r4)
		if (p0) jumpr r31
	}
	{
		r3:2 = vlslw(r5:4,r6)
		loop0(1f,r6)
		p0 = cmp.eq(r6,#0)
		if (p0.new) r4 = #0
	}
	.falign
1:
	{
		p0 = cmp.gtu(r2,r1)
		if (!p0.new) r1 = sub(r1,r2)
		if (!p0.new) r0 = add(r0,r3)
		r3:2 = vlsrw(r3:2,#1)
	}:endloop0
	{
		p0 = cmp.gtu(r2,r1)
		if (!p0.new) r1 = sub(r1,r4)
		if (!p0.new) r0 = add(r0,r3)
		jumpr r31
	}
FUNC_END udivmodsi4


FUNC_START udivsi3
	{
		r2 = cl0(r0)
		r3 = cl0(r1)
		r5:4 = combine(#1,#0)
		p0 = cmp.gtu(r1,r0)
	}
	{
		r6 = sub(r3,r2)
		r4 = r1
		r1:0 = combine(r0,r4)
		if (p0) jumpr r31
	}
	{
		r3:2 = vlslw(r5:4,r6)
		loop0(1f,r6)
	}
	.falign
1:
	{
		p0 = cmp.gtu(r2,r1)
		if (!p0.new) r1 = sub(r1,r2)
		if (!p0.new) r0 = add(r0,r3)
		r3:2 = vlsrw(r3:2,#1)
	}:endloop0
	{
		p0 = cmp.gtu(r2,r1)
		if (!p0.new) r0 = add(r0,r3)
		jumpr r31
	}
FUNC_END udivsi3


FUNC_START umodsi3
	{
		r2 = cl0(r0)
		r3 = cl0(r1)
		p0 = cmp.gtu(r1,r0)
	}
	{
		r2 = sub(r3,r2)
		if (p0) jumpr r31
	}
	{
		loop0(1f,r2)
		p1 = cmp.eq(r2,#0)
		r2 = lsl(r1,r2)
	}
	.falign
1:
	{
		p0 = cmp.gtu(r2,r0)
		if (!p0.new) r0 = sub(r0,r2)
		r2 = lsr(r2,#1)
		if (p1) r1 = #0
	}:endloop0
	{
		p0 = cmp.gtu(r2,r0)
		if (!p0.new) r0 = sub(r0,r1)
		jumpr r31
	}
FUNC_END umodsi3


FUNC_START divsi3
	{
		p0 = cmp.ge(r0,#0)
		p1 = cmp.ge(r1,#0)
		r1 = abs(r0)
		r2 = abs(r1)
	}
	{
		r3 = cl0(r1)
		r4 = cl0(r2)
		r5 = sub(r1,r2)
		p2 = cmp.gtu(r2,r1)
	}
	{
		r0 = #0
		if (p2) jumpr r31
		p1 = xor(p0,p1)
		p0 = cmp.gtu(r2,r5)
	}
	{
		r0 = mux(p1,#-1,#1)
		if (p0) jumpr r31
		r4 = sub(r4,r3)
		r3 = #1
	}
	{
		r0 = #0
		r3:2 = vlslw(r3:2,r4)
		loop0(1f,r4)
	}
	.falign
1:
	{
		p0 = cmp.gtu(r2,r1)
		if (!p0.new) r1 = sub(r1,r2)
		if (!p0.new) r0 = add(r0,r3)
		r3:2 = vlsrw(r3:2,#1)
	}:endloop0
	{
		p0 = cmp.gtu(r2,r1)
		if (!p0.new) r0 = add(r0,r3)
		if (!p1) jumpr r31
	}
	{
		r0 = neg(r0)
		jumpr r31
	}
FUNC_END divsi3


FUNC_START modsi3
	{
		p2 = cmp.ge(r0,#0)
		r2 = abs(r0)
		r1 = abs(r1)
	}
	{
		r3 = cl0(r2)
		r4 = cl0(r1)
		p0 = cmp.gtu(r1,r2)
	}
	{
		r3 = sub(r4,r3)
		if (p0) jumpr r31
	}
	{
		p1 = cmp.eq(r3,#0)
		loop0(1f,r3)
		r0 = r2
		r2 = lsl(r1,r3)
	}
	.falign
1:
	{
		p0 = cmp.gtu(r2,r0)
		if (!p0.new) r0 = sub(r0,r2)
		r2 = lsr(r2,#1)
		if (p1) r1 = #0
	}:endloop0
	{
		p0 = cmp.gtu(r2,r0)
		if (!p0.new) r0 = sub(r0,r1)
		if (p2) jumpr r31
	}
	{
		r0 = neg(r0)
		jumpr r31
	}
FUNC_END modsi3


FUNC_START udivmoddi4
	{
		r6 = cl0(r1:0)              // count leading 0's of dividend (numerator)
		r7 = cl0(r3:2)              // count leading 0's of divisor (denominator)
		r5:4 = r3:2                 // divisor moved into working registers
		r3:2 = r1:0                 // dividend is the initial remainder, r3:2 contains remainder
	}
	{
		r10 = sub(r7,r6)            // left shift count for bit & divisor
		r1:0 = #0                   // initialize quotient to 0
		r15:14 = #1                 // initialize bit to 1
	}
	{
		r11 = add(r10,#1)           // loop count is 1 more than shift count
		r13:12 = lsl(r5:4,r10)      // shift divisor msb into same bit position as dividend msb
		r15:14 = lsl(r15:14,r10)    // shift the bit left by same amount as divisor
	}
	{
		p0 = cmp.gtu(r5:4,r3:2)     // check if divisor > dividend
		loop0(1f,r11)               // register loop

	}
		if (p0) jumpr r31           // if divisor > dividend, we're done, so return

	.falign
1:
	{
		p0 = cmp.gtu(r13:12,r3:2)   // set predicate reg if shifted divisor > current remainder
	}
	{
		r7:6 = sub(r3:2, r13:12)    // subtract shifted divisor from current remainder
		r9:8 = add(r1:0, r15:14)    // save current quotient to temp (r9:8)
	}
	{
		r1:0 = vmux(p0, r1:0, r9:8) // choose either current quotient or new quotient (r9:8)
		r3:2 = vmux(p0, r3:2, r7:6) // choose either current remainder or new remainder (r7:6)
	}
	{
		r15:14 = lsr(r15:14, #1)    // shift bit right by 1 for next iteration
		r13:12 = lsr(r13:12, #1)    // shift "shifted divisor" right by 1 for next iteration
	}:endloop0
		jumpr r31                   // return
FUNC_END udivmoddi4


FUNC_START udivdi3
	{
		r6 = cl0(r1:0)              // count leading 0's of dividend (numerator)
		r7 = cl0(r3:2)              // count leading 0's of divisor (denominator)
		r5:4 = r3:2                 // divisor moved into working registers
		r3:2 = r1:0                 // dividend is the initial remainder, r3:2 contains remainder
	}
	{
		r10 = sub(r7,r6)            // left shift count for bit & divisor
		r1:0 = #0                   // initialize quotient to 0
		r15:14 = #1                 // initialize bit to 1
	}
	{
		r11 = add(r10,#1)           // loop count is 1 more than shift count
		r13:12 = lsl(r5:4,r10)      // shift divisor msb into same bit position as dividend msb
		r15:14 = lsl(r15:14,r10)    // shift the bit left by same amount as divisor
	}
	{
		p0 = cmp.gtu(r5:4,r3:2)     // check if divisor > dividend
		loop0(1f,r11)               // register loop

	}
		if (p0) jumpr r31           // if divisor > dividend, we're done, so return

	.falign
1:
	{
		p0 = cmp.gtu(r13:12,r3:2)   // set predicate reg if shifted divisor > current remainder
	}
	{
		r7:6 = sub(r3:2, r13:12)    // subtract shifted divisor from current remainder
		r9:8 = add(r1:0, r15:14)    // save current quotient to temp (r9:8)
	}
	{
		r1:0 = vmux(p0, r1:0, r9:8) // choose either current quotient or new quotient (r9:8)
		r3:2 = vmux(p0, r3:2, r7:6) // choose either current remainder or new remainder (r7:6)
	}
	{
		r15:14 = lsr(r15:14, #1)    // shift bit right by 1 for next iteration
		r13:12 = lsr(r13:12, #1)    // shift "shifted divisor" right by 1 for next iteration
	}:endloop0
		jumpr r31                   // return
FUNC_END udivdi3


FUNC_START umoddi3
	{
		r6 = cl0(r1:0)              // count leading 0's of dividend (numerator)
		r7 = cl0(r3:2)              // count leading 0's of divisor (denominator)
		r5:4 = r3:2                 // divisor moved into working registers
		r3:2 = r1:0                 // dividend is the initial remainder, r3:2 contains remainder
	}
	{
		r10 = sub(r7,r6)            // left shift count for bit & divisor
		r1:0 = #0                   // initialize quotient to 0
		r15:14 = #1                 // initialize bit to 1
	}
	{
		r11 = add(r10,#1)           // loop count is 1 more than shift count
		r13:12 = lsl(r5:4,r10)      // shift divisor msb into same bit position as dividend msb
		r15:14 = lsl(r15:14,r10)    // shift the bit left by same amount as divisor
	}
	{
		p0 = cmp.gtu(r5:4,r3:2)     // check if divisor > dividend
		loop0(1f,r11)               // register loop

	}
		if (p0) jump .hexagon_umoddi3_return           // if divisor > dividend, we're done, so return

	.falign
1:
	{
		p0 = cmp.gtu(r13:12,r3:2)   // set predicate reg if shifted divisor > current remainder
	}
	{
		r7:6 = sub(r3:2, r13:12)    // subtract shifted divisor from current remainder
		r9:8 = add(r1:0, r15:14)    // save current quotient to temp (r9:8)
	}
	{
		r1:0 = vmux(p0, r1:0, r9:8) // choose either current quotient or new quotient (r9:8)
		r3:2 = vmux(p0, r3:2, r7:6) // choose either current remainder or new remainder (r7:6)
	}
	{
		r15:14 = lsr(r15:14, #1)    // shift bit right by 1 for next iteration
		r13:12 = lsr(r13:12, #1)    // shift "shifted divisor" right by 1 for next iteration
	}:endloop0

.hexagon_umoddi3_return:
	{
		r1:0 = r3:2
		jumpr r31
	}
FUNC_END umoddi3


FUNC_START divdi3
		r5:4 = #0
	{
		p2 = cmp.gt(r5:4,r1:0)
		p3 = cmp.gt(r5:4,r3:2)
	}
	{
		p2 = not(p2)
		p3 = not(p3)
	}
	{
		r1:0 = abs(r1:0)
		r3:2 = abs(r3:2)
	}
	{
		r6 = cl0(r1:0)              // count leading 0's of dividend (numerator)
		r7 = cl0(r3:2)              // count leading 0's of divisor (denominator)
		r5:4 = r3:2                 // divisor moved into working registers
		r3:2 = r1:0                 // dividend is the initial remainder, r3:2 contains remainder
	}
	{
		p3 = xor(p2,p3)
		r10 = sub(r7,r6)            // left shift count for bit & divisor
		r1:0 = #0                   // initialize quotient to 0
		r15:14 = #1                 // initialize bit to 1
	}
	{
		r11 = add(r10,#1)           // loop count is 1 more than shift count
		r13:12 = lsl(r5:4,r10)      // shift divisor msb into same bit position as dividend msb
		r15:14 = lsl(r15:14,r10)    // shift the bit left by same amount as divisor
	}
	{
		p0 = cmp.gtu(r5:4,r3:2)     // check if divisor > dividend
		loop0(1f,r11)               // register loop

	}
		if (p0) jump .hexagon_divdi3_return          // if divisor > dividend, we're done, so return

	.falign
1:
	{
		p0 = cmp.gtu(r13:12,r3:2)   // set predicate reg if shifted divisor > current remainder
	}
	{
		r7:6 = sub(r3:2, r13:12)    // subtract shifted divisor from current remainder
		r9:8 = add(r1:0, r15:14)    // save current quotient to temp (r9:8)
	}
	{
		r1:0 = vmux(p0, r1:0, r9:8) // choose either current quotient or new quotient (r9:8)
		r3:2 = vmux(p0, r3:2, r7:6) // choose either current remainder or new remainder (r7:6)
	}
	{
		r15:14 = lsr(r15:14, #1)    // shift bit right by 1 for next iteration
		r13:12 = lsr(r13:12, #1)    // shift "shifted divisor" right by 1 for next iteration
	}:endloop0

.hexagon_divdi3_return:
		r3:2 = neg(r1:0)
	{
		r1:0 = vmux(p3,r3:2,r1:0)
		jumpr r31
	}
FUNC_END divdi3


FUNC_START moddi3
	{
		r5:4 = #0
	}
		p3 = cmp.gt(r5:4,r1:0)
	{
		r1:0 = abs(r1:0)
		r3:2 = abs(r3:2)
	}
	{
		r6 = cl0(r1:0)              // count leading 0's of dividend (numerator)
		r7 = cl0(r3:2)              // count leading 0's of divisor (denominator)
		r5:4 = r3:2                 // divisor moved into working registers
		r3:2 = r1:0                 // dividend is the initial remainder, r3:2 contains remainder
	}
	{
		p3 = not(p3)
		r10 = sub(r7,r6)            // left shift count for bit & divisor
		r1:0 = #0                   // initialize quotient to 0
		r15:14 = #1                 // initialize bit to 1
	}
	{
		r11 = add(r10,#1)           // loop count is 1 more than shift count
		r13:12 = lsl(r5:4,r10)      // shift divisor msb into same bit position as dividend msb
		r15:14 = lsl(r15:14,r10)    // shift the bit left by same amount as divisor
	}
	{
		p0 = cmp.gtu(r5:4,r3:2)     // check if divisor > dividend
		loop0(1f,r11)               // register loop

	}
		if (p0) jump .hexagon_moddi3_return          // if divisor > dividend, we're done, so return

	.falign
1:
	{
		p0 = cmp.gtu(r13:12,r3:2)   // set predicate reg if shifted divisor > current remainder
	}
	{
		r7:6 = sub(r3:2, r13:12)    // subtract shifted divisor from current remainder
		r9:8 = add(r1:0, r15:14)    // save current quotient to temp (r9:8)
	}
	{
		r1:0 = vmux(p0, r1:0, r9:8) // choose either current quotient or new quotient (r9:8)
		r3:2 = vmux(p0, r3:2, r7:6) // choose either current remainder or new remainder (r7:6)
	}
	{
		r15:14 = lsr(r15:14, #1)    // shift bit right by 1 for next iteration
		r13:12 = lsr(r13:12, #1)    // shift "shifted divisor" right by 1 for next iteration
	}:endloop0

.hexagon_moddi3_return:
		r1:0 = neg(r3:2)
	{
		r1:0 = vmux(p3,r3:2,r1:0)
		jumpr r31
	}
FUNC_END moddi3

#ifdef CONFIG_HEXAGON_ARCH_V4
FUNC_START memcpy_likely_aligned_min32bytes_mult8bytes
	{
		p0 = bitsclr(r1,#7)
		p0 = bitsclr(r0,#7)
		if (p0.new) r5:4 = memd(r1++#8)
		r3 = add(r2,#-32)
	}
	{
		if (!p0) jump ##memcpy
		if (p0) memd(r0++#8) = r5:4
		if (p0) r5:4 = memd(r1++#8)
	}
	{
		memd(r0++#8) = r5:4
		r5:4 = memd(r1++#8)
		r3 = lsr(r3,#3)
		p0 = cmp.eq(r3,#0)
	}
	{
		memd(r0++#8) = r5:4
		r5:4 = memd(r1++#8)
		loop0(1f,r3)
		if (p0) jump 2f
	}
	.falign
1:
	{
		memd(r0++#8) = r5:4
		r5:4 = memd(r1++#8)
	}:endloop0
        .falign
2:      
	{
		memd(r0) = r5:4
		r0 -= add(r2,#-8)
		jumpr r31
	}
FUNC_END memcpy_likely_aligned_min32bytes_mult8bytes
#else
FUNC_START memcpy_likely_aligned_min32bytes_mult8bytes
	{
		p0 = bitsclr(r1,#7)
		p1 = bitsclr(r0,#7)
		if (p0.new) r5:4 = memd(r1)
		r3 = add(r2,#-32)
	}
	{
		if (p1) memd(r0) = r5:4
		if (p0) r5:4 = memd(r1+#8)
		p0 = and(p0,p1)
		r3 = lsr(r3,#3)
	}
	{
		if (!p0) jump 2f
		if (p0) memd(r0+#8) = r5:4
		if (p0) r5:4 = memd(r1+#16)
		if (p0) r0 = add(r0,#16)
	}
	{
		memd(r0++#8) = r5:4
		r5:4 = memd(r1+#24)
		loop0(1f,r3)
		p0 = cmp.eq(r2,#32)
	}
	.falign
1:
	{
		memd(r0++#8) = r5:4
		if (!p0) r5:4 = memd(r1+#32)
		r1 = add(r1,#8)
	}:endloop0
	{
		if (!p0) memd(r0) = r5:4
		r0 -= add(r2,#-8)
		jumpr r31
	}
2:
                jump memcpy
FUNC_END memcpy_likely_aligned_min32bytes_mult8bytes
#endif /* __HEXAGON_ARCH__ >= 4 */


/*
 * When doing memcopy of volatile areas, e.g. i/o space registers,
 * or possibly spinlocked memory in other threads, must be careful
 * to not touch memory twice, and etc.
 *
 * The usual memcpy code has side-effects when copying volatile
 * memory; the below implements a much slower, but safer copy.
 */
FUNC_START hexagon_memcpy_volatile
	{
		p1 = cmp.eq(r2,#0)
		p0 = cmp.eq(r0,r1)
		r6 = r0
		r3 = r1
	}
	{
		p0 = or(p0,p1)
		r4 = r0
		if (p0.new) jump:nt .L3
	}
	{
		p0 = cmp.gtu(r1,r0)
		if (!p0.new) jump:nt .L4
	}
		r0 = or(r1,r0)
		r0 = and(r0,#3)
	{
		p0 = cmp.eq(r0,#0)
		if (!p0.new) jump:nt .L41
	}
.L5:
		r5 = lsr(r2,#2)
	{
		p0 = cmp.eq(r5,#0)
		if (p0.new) jump:nt .L11
	}
		r1:0 = combine(r4,r3)
		loop0(.L38,r5)
	.falign
.L38:
	{
		r7 = memw(r0++#4)
		r3 = add(r3,#4)
		r4 = add(r4,#4)
	}
	{
		memw(r1++#4) = r7
	}:endloop0 // start=.L38
.L11:
		r5 = and(r2,#3)
	{
		p0 = cmp.eq(r5,#0)
		if (p0.new) jump:nt .L3
	}
		r1:0 = combine(r4,r3)
		loop0(.L37,r5)
	.falign
.L37:
		r7 = memb(r0++#1)
	{
		memb(r1++#1) = r7
	}:endloop0 // start=.L37
.L3:
	{
		r0 = r6
		jumpr r31
	}
.L4:
	{
		r3 = add(r1,r2)
		r4 = add(r0,r2)
	}
		r0 = or(r3,r4)
		r0 = and(r0,#3)
	{
		p0 = cmp.eq(r0,#0)
		if (!p0.new) jump:nt .L42
	}
.L20:
		r5 = lsr(r2,#2)
	{
		p0 = cmp.eq(r5,#0)
		if (p0.new) jump:nt .L26
	}
		r1:0 = combine(r4,r3)
		loop0(.L35,r5)
	.falign
.L35:
	{
		r0 = add(r0,#-4)
		r1 = add(r1,#-4)
		r3 = add(r3,#-4)
		r4 = add(r4,#-4)
	}
		r7 = memw(r0)
	{
		memw(r1) = r7
	}:endloop0 // start=.L35
.L26:
		r5 = and(r2,#3)
	{
		p0 = cmp.eq(r5,#0)
		if (p0.new) jump:nt .L3
	}
	{
		r1:0 = combine(r4,r3)
		loop0(.L34,r5)
	}
	.falign
.L34:
	{
		r0 = add(r0,#-1)
		r1 = add(r1,#-1)
	}
		r7 = memb(r0)
	{
		memb(r1) = r7
	}:endloop0 // start=.L34
	{
		r0 = r6
		jumpr r31
	}
.L41:
	{
		r0 = xor(r1,r6)
		p0 = cmp.gtu(r2,#3)
	}
		r0 = and(r0,#3)
		p1 = cmp.eq(r0,#0)
	{
		p0 = and(p0,p1)
		if (!p0.new) r5 = add(r2,#0)
		if (!p0.new) jump:nt .L7
	}
		r0 = and(r1,#3)
		r5 = sub(#4,r0)
.L7:
	{
		r2 = sub(r2,r5)
		r0 = r6
		loop0(.L39,r5)
	}
	.falign
.L39:
	{
		r7 = memb(r1++#1)
		r3 = add(r3,#1)
		r4 = add(r4,#1)
	}
	{
		memb(r0++#1) = r7
	}:endloop0 // start=.L39
		jump .L5
.L42:
	{
		r0 = xor(r3,r4)
		p0 = cmp.gtu(r2,#4)
	}
		r0 = and(r0,#3)
		p1 = cmp.eq(r0,#0)
	{
		p0 = and(p0,p1)
		if (!p0.new) r5 = add(r2,#0)
		if (!p0.new) jump:nt .L22
	}
		r5 = and(r3,#3)
.L22:
	{
		r2 = sub(r2,r5)
		r1:0 = combine(r4,r3)
		loop0(.L36,r5)
	}
	.falign
.L36:
	{
		r0 = add(r0,#-1)
		r1 = add(r1,#-1)
		r4 = add(r4,#-1)
		r3 = add(r3,#-1)
	}
		r7 = memb(r0)
	{
		memb(r1) = r7
	}:endloop0 // start=.L36
		jump .L20
FUNC_END hexagon_memcpy_volatile


/* Functions that implement common sequences in function prologues and epilogues
   used to save code size

   Save r27:26 at fp+#-8, r25:24 at fp+#-16, r23:22 at fp+#-24, and r21:20 at
   fp+#-32. */


#ifdef L_common_prologue_epilogue
/* The compiler knows that the __save_* functions clobber LR.  No other
   registers should be used without informing the compiler. */

/* Since we can only issue one store per packet, we don't hurt performance by
   simply jumping to the right point in this sequence of stores. */

FUNC_START save_r27_through_r16
		memd(fp+#-48) = r17:16
FALLTHROUGH_TAIL_CALL save_r27_through_r16 save_r27_through_r18
		memd(fp+#-40) = r19:18
FALLTHROUGH_TAIL_CALL save_r27_through_r18 save_r27_through_r20
		memd(fp+#-32) = r21:20
FALLTHROUGH_TAIL_CALL save_r27_through_r20 save_r27_through_r22
		memd(fp+#-24) = r23:22
FALLTHROUGH_TAIL_CALL save_r27_through_r22 save_r27_through_r24
		memd(fp+#-16) = r25:24
	{
		memd(fp+#-8) = r27:26
		jumpr lr
	}
FUNC_END save_r27_through_r24


/* For each of the *_before_sibcall functions, jumpr lr is executed in parallel
   with deallocframe.  That way, the return gets the old value of lr, which is
   where these functions need to return, and at the same time, lr gets the value
   it needs going into the sibcall. */

FUNC_START restore_r27_through_r20_and_deallocframe_before_sibcall
	{
		r21:20 = memd(fp+#-32)
		jump __restore_r27_through_r22_and_deallocframe_before_sibcall
	}
FUNC_END restore_r27_through_r20_and_deallocframe_before_sibcall


FUNC_START restore_r27_through_r24_and_deallocframe_before_sibcall
	{
		r25:24 = memd(fp+#-16)
		jump __restore_r27_through_r26_and_deallocframe_before_sibcall
	}
FUNC_END restore_r27_through_r24_and_deallocframe_before_sibcall


FUNC_START restore_r27_through_r16_and_deallocframe_before_sibcall
		r17:16 = memd(fp+#-48)
FALLTHROUGH_TAIL_CALL restore_r27_through_r16_and_deallocframe_before_sibcall restore_r27_through_r18_and_deallocframe_before_sibcall
	{
		r19:18 = memd(fp+#-40)
		r21:20 = memd(fp+#-32)
	}
FALLTHROUGH_TAIL_CALL restore_r27_through_r18_and_deallocframe_before_sibcall restore_r27_through_r22_and_deallocframe_before_sibcall
	{
		r23:22 = memd(fp+#-24)
		r25:24 = memd(fp+#-16)
	}
FALLTHROUGH_TAIL_CALL restore_r27_through_r22_and_deallocframe_before_sibcall restore_r27_through_r26_and_deallocframe_before_sibcall
	{
		r27:26 = memd(fp+#-8)
		deallocframe
		jumpr lr
	}
FUNC_END restore_r27_through_r26_and_deallocframe_before_sibcall


/* Here we use the extra load bandwidth to restore LR early, allowing the return
   to occur in parallel with the deallocframe. */

FUNC_START restore_r27_through_r16_and_deallocframe
	{
		r17:16 = memd(fp+#-48)
		r19:18 = memd(fp+#-40)
	}
FALLTHROUGH_TAIL_CALL restore_r27_through_r16_and_deallocframe restore_r27_through_r20_and_deallocframe
	{
		r21:20 = memd(fp+#-32)
		r23:22 = memd(fp+#-24)
	}
FALLTHROUGH_TAIL_CALL restore_r27_through_r20_and_deallocframe restore_r27_through_r24_and_deallocframe
	{
		lr = memw(fp+#4)
		r25:24 = memd(fp+#-16)
	}
	{
		r27:26 = memd(fp+#-8)
		deallocframe
		jumpr lr
	}
FUNC_END restore_r27_through_r24_and_deallocframe


/* Here the load bandwidth is maximized for all three functions. */

FUNC_START restore_r27_through_r18_and_deallocframe
	{
		r19:18 = memd(fp+#-40)
		r21:20 = memd(fp+#-32)
	}
FALLTHROUGH_TAIL_CALL restore_r27_through_r18_and_deallocframe restore_r27_through_r22_and_deallocframe
	{
		r23:22 = memd(fp+#-24)
		r25:24 = memd(fp+#-16)
	}
FALLTHROUGH_TAIL_CALL restore_r27_through_r22_and_deallocframe restore_r27_through_r26_and_deallocframe
	{
		r27:26 = memd(fp+#-8)
		deallocframe
	}
		jumpr lr
FUNC_END restore_r27_through_r26_and_deallocframe


FUNC_START deallocframe
		deallocframe
		jumpr lr
FUNC_END deallocframe


/*******************************************************************************/
/*************following functions added by SRP for newlib support***************/
/*******************************************************************************/


/*common_entry_exit_abi2.S*/
/* Save r17:16 at fp+#-8, r19:18 at fp+#-16, r21:20 at fp+#-24, r23:22 at
   fp+#-32, r25:24 at fp+#-40, and r27:26 at fp+#-48. */


#if __HEXAGON_ARCH__ >= 4
/* The compiler knows that the save_* functions clobber LR.  No other
   registers should be used without informing the compiler. */

FUNC_START save_r16_through_r27
	{
		memd(fp+#-48) = r27:26
		memd(fp+#-40) = r25:24
	}
FALLTHROUGH_TAIL_CALL save_r16_through_r27 save_r16_through_r23
	{
		memd(fp+#-32) = r23:22
		memd(fp+#-24) = r21:20
	}
FALLTHROUGH_TAIL_CALL save_r16_through_r23 save_r16_through_r19
	{
		memd(fp+#-16) = r19:18
		memd(fp+#-8) = r17:16
		jumpr lr
	}
FUNC_END save_r16_through_r19




FUNC_START save_r16_through_r25
	{
		memd(fp+#-40) = r25:24
		memd(fp+#-32) = r23:22
	}
FALLTHROUGH_TAIL_CALL save_r16_through_r25 save_r16_through_r21
	{
		memd(fp+#-24) = r21:20
		memd(fp+#-16) = r19:18
	}
FALLTHROUGH_TAIL_CALL save_r16_through_r21 save_r16_through_r17
	{
		memd(fp+#-8) = r17:16
		jumpr lr
	}
FUNC_END save_r16_through_r17




/* For each of the *_before_tailcall functions, jumpr lr is executed in parallel
   with deallocframe.  That way, the return gets the old value of lr, which is
   where these functions need to return, and at the same time, lr gets the value
   it needs going into the tail call. */

FUNC_START restore_r16_through_r23_and_deallocframe_before_tailcall
	{
		r23:22 = memd(fp+#-32)
		r21:20 = memd(fp+#-24)
	}
FALLTHROUGH_TAIL_CALL restore_r16_through_r23_and_deallocframe_before_tailcall restore_r16_through_r19_and_deallocframe_before_tailcall
	{
		r19:18 = memd(fp+#-16)
		jump __restore_r16_through_r17_and_deallocframe_before_tailcall
	}
FUNC_END restore_r16_through_r19_and_deallocframe_before_tailcall




FUNC_START restore_r16_through_r27_and_deallocframe_before_tailcall
		r27:26 = memd(fp+#-48)
FALLTHROUGH_TAIL_CALL restore_r16_through_r27_and_deallocframe_before_tailcall restore_r16_through_r25_and_deallocframe_before_tailcall
	{
		r25:24 = memd(fp+#-40)
		r23:22 = memd(fp+#-32)
	}
FALLTHROUGH_TAIL_CALL restore_r16_through_r25_and_deallocframe_before_tailcall restore_r16_through_r21_and_deallocframe_before_tailcall
	{
		r21:20 = memd(fp+#-24)
		r19:18 = memd(fp+#-16)
	}
FALLTHROUGH_TAIL_CALL restore_r16_through_r21_and_deallocframe_before_tailcall restore_r16_through_r17_and_deallocframe_before_tailcall
	{
		r17:16 = memd(fp+#-8)
		deallocframe
		jumpr lr
	}
FUNC_END restore_r16_through_r17_and_deallocframe_before_tailcall




FUNC_START restore_r16_through_r23_and_deallocframe
	{
		r23:22 = memd(fp+#-32)
		r21:20 = memd(fp+#-24)
	}
FALLTHROUGH_TAIL_CALL restore_r16_through_r23_and_deallocframe restore_r16_through_r19_and_deallocframe
	{
		r19:18 = memd(fp+#-16)
		jump __restore_r16_through_r17_and_deallocframe
	}
FUNC_END restore_r16_through_r19_and_deallocframe




FUNC_START restore_r16_through_r27_and_deallocframe
		r27:26 = memd(fp+#-48)
FALLTHROUGH_TAIL_CALL restore_r16_through_r27_and_deallocframe restore_r16_through_r25_and_deallocframe
	{
		r25:24 = memd(fp+#-40)
		r23:22 = memd(fp+#-32)
	}
FALLTHROUGH_TAIL_CALL restore_r16_through_r25_and_deallocframe restore_r16_through_r21_and_deallocframe
	{
		r21:20 = memd(fp+#-24)
		r19:18 = memd(fp+#-16)
	}
FALLTHROUGH_TAIL_CALL restore_r16_through_r21_and_deallocframe restore_r16_through_r17_and_deallocframe
	{
		r17:16 = memd(fp+#-8)
		dealloc_return
	}
FUNC_END restore_r16_through_r17_and_deallocframe




FUNC_START __deallocframe
		dealloc_return
FUNC_END __deallocframe




#else /* __HEXAGON_ARCH__ < 4 */




/* The compiler knows that the save_* functions clobber LR.  No other
   registers should be used without informing the compiler. */

/* Since we can only issue one store per packet, we don't hurt performance by
   simply jumping to the right point in this sequence of stores. */

FUNC_START save_r16_through_r27
		memd(fp+#-48) = r27:26
FALLTHROUGH_TAIL_CALL save_r16_through_r27 save_r16_through_r25
		memd(fp+#-40) = r25:24
FALLTHROUGH_TAIL_CALL save_r16_through_r25 save_r16_through_r23
		memd(fp+#-32) = r23:22
FALLTHROUGH_TAIL_CALL save_r16_through_r23 save_r16_through_r21
		memd(fp+#-24) = r21:20
FALLTHROUGH_TAIL_CALL save_r16_through_r21 save_r16_through_r19
		memd(fp+#-16) = r19:18
FALLTHROUGH_TAIL_CALL save_r16_through_r19 save_r16_through_r17
	{
		memd(fp+#-8) = r17:16
		jumpr lr
	}
FUNC_END save_r16_through_r17




/* For each of the *_before_tailcall functions, jumpr lr is executed in parallel
   with deallocframe.  That way, the return gets the old value of lr, which is
   where these functions need to return, and at the same time, lr gets the value
   it needs going into the tail call. */

FUNC_START restore_r16_through_r23_and_deallocframe_before_tailcall
	{
		r23:22 = memd(fp+#-32)
		r21:20 = memd(fp+#-24)
	}
FALLTHROUGH_TAIL_CALL restore_r16_through_r23_and_deallocframe_before_tailcall restore_r16_through_r19_and_deallocframe_before_tailcall
	{
		r19:18 = memd(fp+#-16)
		jump __restore_r16_through_r17_and_deallocframe_before_tailcall
	}
FUNC_END restore_r16_through_r19_and_deallocframe_before_tailcall




FUNC_START restore_r16_through_r27_and_deallocframe_before_tailcall
		r27:26 = memd(fp+#-48)
FALLTHROUGH_TAIL_CALL restore_r16_through_r27_and_deallocframe_before_tailcall restore_r16_through_r25_and_deallocframe_before_tailcall
	{
		r25:24 = memd(fp+#-40)
		r23:22 = memd(fp+#-32)
	}
FALLTHROUGH_TAIL_CALL restore_r16_through_r25_and_deallocframe_before_tailcall restore_r16_through_r21_and_deallocframe_before_tailcall
	{
		r21:20 = memd(fp+#-24)
		r19:18 = memd(fp+#-16)
	}
FALLTHROUGH_TAIL_CALL restore_r16_through_r21_and_deallocframe_before_tailcall restore_r16_through_r17_and_deallocframe_before_tailcall
	{
		r17:16 = memd(fp+#-8)
		deallocframe
		jumpr lr
	}
FUNC_END restore_r16_through_r17_and_deallocframe_before_tailcall




/* Here we use the extra load bandwidth to restore LR early, allowing the return
   to occur in parallel with the deallocframe. */

FUNC_START restore_r16_through_r27_and_deallocframe
	{
		r27:26 = memd(fp+#-48)
		r25:24 = memd(fp+#-40)
	}
FALLTHROUGH_TAIL_CALL restore_r16_through_r27_and_deallocframe restore_r16_through_r23_and_deallocframe
	{
		r23:22 = memd(fp+#-32)
		r21:20 = memd(fp+#-24)
	}
FALLTHROUGH_TAIL_CALL restore_r16_through_r23_and_deallocframe restore_r16_through_r19_and_deallocframe
	{
		lr = memw(fp+#4)
		r19:18 = memd(fp+#-16)
	}
	{
		r17:16 = memd(fp+#-8)
		deallocframe
		jumpr lr
	}
FUNC_END restore_r16_through_r19_and_deallocframe




/* Here the load bandwidth is maximized for all three functions. */

FUNC_START restore_r16_through_r25_and_deallocframe
	{
		r25:24 = memd(fp+#-40)
		r23:22 = memd(fp+#-32)
	}
FALLTHROUGH_TAIL_CALL restore_r16_through_r25_and_deallocframe restore_r16_through_r21_and_deallocframe
	{
		r21:20 = memd(fp+#-24)
		r19:18 = memd(fp+#-16)
	}
FALLTHROUGH_TAIL_CALL restore_r16_through_r21_and_deallocframe restore_r16_through_r17_and_deallocframe
	{
		r17:16 = memd(fp+#-8)
		deallocframe
	}
		jumpr lr
FUNC_END restore_r16_through_r17_and_deallocframe




FUNC_START __deallocframe
		deallocframe
		jumpr lr
FUNC_END __deallocframe
#endif /* __HEXAGON_ARCH__ < 4 */

/*common_entry_exit_abi1.S*/
/* Save r25:24 at fp+#-8 and r27:26 at fp+#-16. */
/* The compiler knows that the save_* functions clobber LR.  No other
   registers should be used without informing the compiler. */

/* Since we can only issue one store per packet, we don't hurt performance by
   simply jumping to the right point in this sequence of stores. */

FUNC_START save_r24_through_r27
		memd(fp+#-16) = r27:26
FALLTHROUGH_TAIL_CALL save_r24_through_r27 save_r24_through_r25
	{
		memd(fp+#-8) = r25:24
		jumpr lr
	}
FUNC_END save_r24_through_r25




/* For each of the *_before_tailcall functions, jumpr lr is executed in parallel
   with deallocframe.  That way, the return gets the old value of lr, which is
   where these functions need to return, and at the same time, lr gets the value
   it needs going into the tail call. */

FUNC_START restore_r24_through_r27_and_deallocframe_before_tailcall
		r27:26 = memd(fp+#-16)
FALLTHROUGH_TAIL_CALL restore_r24_through_r27_and_deallocframe_before_tailcall restore_r24_through_r25_and_deallocframe_before_tailcall
	{
		r25:24 = memd(fp+#-8)
		deallocframe
		jumpr lr
	}
FUNC_END restore_r24_through_r25_and_deallocframe_before_tailcall




/* Here we use the extra load bandwidth to restore LR early, allowing the return
   to occur in parallel with the deallocframe. */

FUNC_START restore_r24_through_r27_and_deallocframe
	{
		lr = memw(fp+#4)
		r27:26 = memd(fp+#-16)
	}
	{
		r25:24 = memd(fp+#-8)
		deallocframe
		jumpr lr
	}
FUNC_END restore_r24_through_r27_and_deallocframe




/* Here the load bandwidth is maximized. */

FUNC_START restore_r24_through_r25_and_deallocframe
	{
		r25:24 = memd(fp+#-8)
		deallocframe
	}
		jumpr lr
FUNC_END restore_r24_through_r25_and_deallocframe

/*******************************************************************************/
/*****************above functions added by SRP for newlib support***************/
/*******************************************************************************/


#endif /* L_common_prologue_epilogue */

/****************************This function is required by crt0_standalone.S*****/
/********probably should be a part of libstandalone.a which does not exit for newlib yet. *****/
#ifdef L_crt0_standalone_support


/* This is the function that starts another thread      */
/* If you recall, the code up above is where we go to   */
/* in the newly-started thread after we use the "start" */
/* instruction (see the system spec).                   */
/* This code sets up the information for the thread     */
/* and then starts the thread up.                       */

	.text

	.p2align 4
	.global thread_create
	.weak thread_create
 	.type thread_create, @function

thread_create:
	/* R0 = start PC */
	/* R1 = stack pointer */
	/* R2 = thread num */
	/* R3 = param0 */
{
        r4.h = #HI (__start_pc)
        r5.h = #HI (__start_sp)
        r6.h = #HI (__start_param)
        r7 = asl (r2, #2)
}
{
        r4.l = #LO (__start_pc)
        r5.l = #LO (__start_sp)
        r6.l = #LO (__start_param)
        r8 = #1
}
{
        r4 = add (r7, r4)
        r5 = add (r7, r5)
        r6 = add (r7, r6)
        r8 = asl (r8, r2)
}
	memw (r4) = r0
	memw (r5) = r1
	memw (r6) = r3
	start (r8)
	jumpr lr

	.size thread_create, . - thread_create

/* This stops the current thread */

	.p2align 4
	.global thread_stop
	.weak thread_stop
 	.type thread_stop, @function

thread_stop:
#if __HEXAGON_ARCH__ < 4
	r0 = ssr
#endif /* __HEXAGON_ARCH__ < 4 */
{
#if __HEXAGON_ARCH__ < 4
	r0 = extractu (r0, #3, #19)
#else /* __HEXAGON_ARCH__ >= 4 */
	r0 = htid
#endif /* __HEXAGON_ARCH__ >= 4 */
	r1 = #1
}
	r1 = lsl (r1, r0)
	stop (r1)
	/* shouldn't get here */
        r28.h = #HI (__coredump)
        r28.l = #LO (__coredump)
	jumpr r28

	.size thread_stop, . - thread_stop

/* This waits until all of the specified threads stop. */

	.p2align 4
	.p2align 4
	.global thread_join
	.weak thread_join
 	.type thread_join, @function

	/* R0 = thread mask */
thread_join:
	/* Firstly, remove the current thread from the mask. */
#if __HEXAGON_ARCH__ < 4
	r1 = ssr
#endif /* __HEXAGON_ARCH__ < 4 */
{
#if __HEXAGON_ARCH__ < 4
	r1 = extractu (r1, #3, #19)
#else /* __HEXAGON_ARCH__ >= 4 */
	r1 = htid
#endif /* __HEXAGON_ARCH__ >= 4 */
	r3 = #1
}
	r1 = asl (r3, r1)
        r1 = not (r1)
	r0 = and (r0, r1)
	r0 = combine (r0.l, r0.l)

1:
	r2 = modectl
	r2 = and (r0, r2)
	{ p0 = cmp.eq (r2, #0)
#if __HEXAGON_ARCH__ >= 3
	  if (p0.new) jumpr:nt lr }
	/* Save some power on V3 and later. */
	pause (#1)
        jump 1b
#else
	  if (!p0.new) jump:t 1b }

	jumpr lr
#endif

	.size thread_join, . - thread_join

/* This reads the current thread number */

	.p2align 4
	.global thread_get_tnum
	.weak thread_get_tnum
 	.type thread_get_tnum, @function

thread_get_tnum:
#if __HEXAGON_ARCH__ < 4
	r0 = ssr
#endif /* __HEXAGON_ARCH__ < 4 */
{
#if __HEXAGON_ARCH__ < 4
	r0 = extractu (r0, #3, #19)
#else /* __HEXAGON_ARCH__ >= 4 */
	r0 = htid
#endif /* __HEXAGON_ARCH__ >= 4 */
	jumpr lr
}

	.size thread_get_tnum, . - thread_get_tnum

/* This saves the stack size for the specified thread number */
/*     (used for graphical profiling of stack)               */

   .p2align 4
   .global thread_stack_size
   .weak thread_stack_size
   .type thread_stack_size, @function

thread_stack_size:
   /* R0 = thread num */
   /* R1 = stack size */

   r2.h = #HI (__stack_size)
{
   r2.l = #LO (__stack_size)
   r3 = asl (r0, #2)
}
{
   r4 = add (r2, r3)
}
   memw (r4) = r1
   jumpr lr

   .size thread_stack_size, . - thread_stack_size


#endif /*L_crt0_standalone_support*/
