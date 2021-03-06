/*
 * Early kernel startup code for native Hexagon
 *
 * Copyright (C) 2013 Cotulla
 * Copyright (c) 2010-2011, The Linux Foundation. All rights reserved.
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 and
 * only version 2 as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
 * 02110-1301, USA.
 */

#include <linux/linkage.h>
#include <linux/init.h>
#include <asm/asm-offsets.h>
#include <asm/mem-layout.h>
#include <asm/vm_mmu.h>
#include <asm/hexagon_vm.h>
#include <asm/page.h>

#include "qdsp6_tlb.h"
#include "native_defs.h"
#include "tlb_usage.h"

/*
Startup tasks:

1. setup mapping for corearea at FFF0 0000 at TLB#0
2. fill page tables TID#0. put kernel to 16M TLB#0.
   set indentity mapping to page tablefor MMU on.
3. turn on MMU
4. jump to kernel VA (C000 0000+)
5. remove indentity mapping from MMU.
6. call kernel entry point (start_kernel)

*/


// this macro can be used to load 32bit constant into register without 
// any relative addressing. NOTE: CONST32() use GP relative addressing!
//
#define LOAD32(reg, value)    \
        reg.h = #HI(value);    \
        reg.l = #LO(value)


    .macro TLB_ENTRY_SET index, regl, regh
        tlbhi = \regh
        tlblo = \regl
        tlbidx = \index
        tlbw
        isync        
    .endm



// Boot parameters
// used to pass information to kernel
// signature 'Q6BP' = 0x50423651
// they are located at C000 0000
// kernel starts at C000 1000
//

.section	".tags.text","ax"
.global __initrd_sign
.global __initrd_start
.global __initrd_size

__initrd_sign:   .word 0
__initrd_start:  .word 0
__initrd_size:   .word 0

	.fill (4 * 1024 - 12), 1, 0

	LOAD32(r0, PHYS_OFFSET + ENTRY_OFFSET)
	jumpr	r0




	__HEAD
ENTRY(stext)

//TODO: works for v2 and v3, what about v4?

     r0 = #0                  
     ssr = r0                 
     isync                    
     ickill                   
     dckill                   
     r2.h = #64                 
     r2.l = #0                 
     s60 = r2   

     nop        
     nop        
     nop        

     nop        
     nop        
     nop        

     nop        
     nop        
     nop

     r2 = #0     
     diag = r2   
     r10 = #46
     syscfg = r10
 
     r0 = #0
     pcyclelo = r0
     isync
     pcyclehi = r0
     isync

  
     r0 = syscfg
     r0 = setbit(r0, #6) 
     syscfg = r0
     r0 = setbit(r0, #5)
     syscfg = r0
     isync


     r0 = ssr
     r0 = setbit(r0, #22)
     r0 = setbit(r0, #23)
     ssr = r0
     isync


     r1 = #2
     r0 = syscfg
     r0 = insert(r1, #2, #16) 
     syscfg = r0
     isync
     l2kill
     isync     

#ifdef CONFIG_HEXAGON_ARCH_V3
//TODO: this is pretty touchpad specific. Other devices may not have the PLL
//configured to usable values. Even on touchpad this is a high clock 
//rate which may not work without voltage scaling
     LOAD32(r0,0x2800001C)
     r1 = memw(r0)
     r1 = clrbit(r1,#6)
     r1 = clrbit(r1,#5)
     r1 = clrbit(r1,#4)
     r1 = setbit(r1,#3)
     memw(r0) = r1
#endif

//////


// 0. clear all 64 TLB entries to be sure no mappings 
//
	r0 = #0
	r2 = #0
.tlb_clear_lp:
        p0 = cmp.gt (r0, #63)
        if p0 jump .tlb_clear_exit

	TLB_ENTRY_SET r0, r2, r2 // idx, lo, hi

        { r0 = add (r0, #1)
          jump .tlb_clear_lp }

.tlb_clear_exit:



// 1. setup TLB#0 mapping for CoreSys.
// NOTE: lowmem seems must be mapped continously. 
// this code works only if RAM size >= 16M.
// the rest (RAM_SIZE - 16M) must be mapped somewhere else during boot
//
#if CORESYS_PHYSICAL & (0x10000 - 1)
#error CORESYS_PHYSICAL must be aligned to 64K
#endif
#if CORESYS_VIRTUAL & (0x10000 - 1)
#error CORESYS_VIRTUAL must be aligned to 64K
#endif

// CotullaTODO: remove R later to prevent user mode from reading coresys?
    	LOAD32(r1, TLB_MAKE_LO(TLB_ADDR(CORESYS_PHYSICAL), TLB_SIZE_64K, TLB_L1WB_L2C, TLB_RWX))
    	LOAD32(r2, TLB_MAKE_HI(TLB_ADDR(CORESYS_VIRTUAL), 1, 0)) // global

        r0 = #TLBUSG_CORE
	TLB_ENTRY_SET r0, r1, r2 // idx, lo, hi
	

#ifdef CONFIG_HEXAGON_ARCH_V2

// Setup debug entry for ram console HTC LEO
//
    	LOAD32(r1, TLB_MAKE_LO(TLB_ADDR(0x2FF00000), TLB_SIZE_1M, TLB_UC, TLB_RWX))
    	LOAD32(r2, TLB_MAKE_HI(TLB_ADDR(0xF8000000), 1, 0)) // global
    	r0 = #TLBUSG_DEBUG
    	TLB_ENTRY_SET r0, r1, r2 // idx, lo, hi


// Setup debug entry for vibro mark  HTC LEO
//

// GPIO VIBRO 
//	LOAD32(r1, TLB_MAKE_LO(TLB_ADDR(0xA9000000), TLB_SIZE_1M, TLB_UC, TLB_RWX))
//	LOAD32(r2, TLB_MAKE_HI(TLB_ADDR(0xA9000000), 1, 0)) // global

// TIMERS
//	LOAD32(r1, TLB_MAKE_LO(TLB_ADDR(0xAB000000), TLB_SIZE_1M, TLB_UC, TLB_RWX))
//	LOAD32(r2, TLB_MAKE_HI(TLB_ADDR(0xAB000000), 1, 0)) // global

// SCREEN CONSOLE
	LOAD32(r1, TLB_MAKE_LO(TLB_ADDR(0x02A00000), TLB_SIZE_1M, TLB_L1WB_L2C, TLB_RWX))
	LOAD32(r2, TLB_MAKE_HI(TLB_ADDR(0xF0300000), 1, 0)) // global

	r0 = #TLBUSG_DEBUG2
	TLB_ENTRY_SET r0, r1, r2 // idx, lo, hi

#else

    	LOAD32(r1, TLB_MAKE_LO(TLB_ADDR(0x49000000), TLB_SIZE_16M, TLB_UC, TLB_RWX))
	r2 = #1;
	r2 = asl(r2,#23)
	r1 = or(r1,r2)
    	LOAD32(r2, TLB_MAKE_HI(TLB_ADDR(0xF8000000), 1, 0)) // global
    	r0 = #TLBUSG_DEBUG
    	TLB_ENTRY_SET r0, r1, r2 // idx, lo, hi

//Debug entry for hexagon timers
#if 0

		LOAD32(r1, TLB_MAKE_LO(TLB_ADDR(0x28000000), TLB_SIZE_16M, TLB_UC, TLB_RWX))
		LOAD32(r2, TLB_MAKE_HI(TLB_ADDR(0x28000000), 1, 0)) // global
		r0 = #TLBUSG_DEBUG2
		TLB_ENTRY_SET r0, r1, r2 // idx, lo, hi
#endif

#endif


// init page tables
// clear L1 kernel page table
// fill it with __HVM_PDE_S_INVALID
//
	// setup initial page table
        LOAD32(r0, swapper_pg_dir)
	// convert VA -> PA
        // PA = VA - PAGE_OFFSET + PHYS_OFFSET
        // PA = VA + (PHYS_OFFSET - PAGE_OFFSET)
	// C010 0000 -> 1010 0000       
        LOAD32(r1, (PHYS_OFFSET - PAGE_OFFSET))
        r0 = add (r0, r1) 
        r4 = r0


	r1 = #__HVM_PDE_S_INVALID
	r3 = #1024	// 1024 entries in L1, each 4M  
	loop0(3f, r3)
3:
	{
		memw(r0 ++ #4) = r1
	}:endloop0


// put kernel 16M entry
//
#define PTE_BITS ( __HVM_PTE_R | __HVM_PTE_W | __HVM_PTE_X	\
		  | __HEXAGON_C_WB_L2 << 6			\
		  | __HVM_PDE_S_16MB)

	LOAD32(r1, PAGE_OFFSET >> 22)	// >> 22 same as / 4M
	r4 += asl (r1, #2)	// entry size is 4

	LOAD32(r5, PTE_BITS)
	LOAD32(r2, PHYS_OFFSET)
	r5 = or (r2, r5) 

	// 16M must be repeated 4 times
	memw (r4 ++ #4) = r5
	memw (r4 ++ #4) = r5
	memw (r4 ++ #4) = r5
	memw (r4 ++ #4) = r5
		


// 2. setup kernel identity map:
// detect current address by PC and map 1M entry
// to TLB#1. it will be cleared back later.
//

	// fill addresses below 
    	LOAD32(r1, TLB_MAKE_LO(0, TLB_SIZE_1M, TLB_UC, TLB_RWX)) // PA
    	LOAD32(r2, TLB_MAKE_HI(0, 1, 0)) // VA, global
	                      	
	// TLB_LO{r1} |= ((PC & 0xFFF00000) >> 12)	
	LOAD32(r4, 0xFFF00000)		// 1M MASK 
	r3 = pc
	r3 = and (r3, r4)

	r1 |= lsr (r3, #12) 		// >> 12 
	r2 |= lsr (r3, #12) 		// >> 12 
	
	r0 = #TLBUSG_INDENTITY
	TLB_ENTRY_SET r0, r1, r2 // idx, lo, hi


// set mapping for kernel 16M temporal
//
    	LOAD32(r1, TLB_MAKE_LO(TLB_ADDR(PHYS_OFFSET), TLB_SIZE_16M, TLB_L1WB_L2C, TLB_RWX))
    	LOAD32(r2, TLB_MAKE_HI(TLB_ADDR(PAGE_OFFSET), 0, 0)) // non-global, ASID=0

        r0 = #TLBUSG_REPLACE_MIN
	TLB_ENTRY_SET r0, r1, r2 // idx, lo, hi



// Enable TLB/MMU 
//		
        r0 = syscfg
        r0 = setbit (r0, #SYSCFG_BIT_TLB)
        syscfg = r0
        isync

	/*  Jump into virtual address range 0xC0000000+.  */
	LOAD32(r31, __head_s_vaddr_target);
	jumpr r31


	/*  Insert trippy space effects.  */
__head_s_vaddr_target:

	// remove indentify mapping here
	//
	
	r2 = #0
	r0 = #TLBUSG_INDENTITY
	TLB_ENTRY_SET r0, r2, r2 // idx, lo, hi


	// coresys init
	// starts SW MMU
	// call coresys directly
 	// page table must be already inited
	// SUPERVISOR MODE 

	LOAD32(r3, coresys_init)
	callr r3

	// returns in USER MODE


 	// setup initial page table
        LOAD32(r0, swapper_pg_dir)
	// convert VA -> PA
        // PA = VA - PAGE_OFFSET + PHYS_OFFSET
        // PA = VA + (PHYS_OFFSET - PAGE_OFFSET)
	// C010 0000 -> 1010 0000       
        LOAD32(r1, (PHYS_OFFSET - PAGE_OFFSET))
        r0 = add (r0, r1)	// PA address of page table 

	trap1(#HVM_TRAP1_VMNEWMAP);	// coresys_newmap

	//
	// here should be the first tlb miss fault
	//

	/*
	 * OK, at this point we should start to be much more careful,
	 * we're going to enter C code and start touching memory
	 * in all sorts of places.
	 * This means:
	 *      SGP needs to be OK
	 *	Need to lock shared resources
	 *	A bunch of other things that will cause
	 * 	all kinds of painful bugs
	 */

	/*
	 * Stack pointer should be pointed at the init task's
	 * thread stack, which should have been declared in arch/init_task.c.
	 * So uhhhhh...
	 * It's accessible via the init_thread_union, which is a union
	 * of a thread_info struct and a stack; of course, the top
	 * of the stack is not for you.  The end of the stack
	 * is simply init_thread_union + THREAD_SIZE.
	 */

	{r29.H = #HI(init_thread_union); r0.H = #HI(_THREAD_SIZE); }
	{r29.L = #LO(init_thread_union); r0.L = #LO(_THREAD_SIZE); }

	/*  initialize the register used to point to current_thread_info */
	/*  Fixme:  THREADINFO_REG can't be R2 because of that memset thing. */
	{r29 = add(r29,r0); THREADINFO_REG = r29; }

	/*  Hack:  zero bss; */
	{ r0.L = #LO(__bss_start);  r1 = #0; r2.l = #LO(__bss_stop); }
	{ r0.H = #HI(__bss_start);           r2.h = #HI(__bss_stop); }

	r2 = sub(r2,r0);
	call memset;

//	LOAD32(r3,coresys_newmap)
//	callr r3


// Cotulla: Test LEO bzZZzz code    
#if 0
     r0.h = #0xA900
     r0.l = #0x080C
     r10 = memw(r0)
     r2 = #0x20
     r10 = or (r10, r2)
     memw(r0) = r10
     dckill
#endif

#if 0
1:
r24.L = #0x0000
r24.H = #0x4801
r25.L = #0x0000
r25.H = #0x4890
r0.H = #0xCCAA
r0.L = #0xCBDF

1:
memw(r24) = R0
r24 = add(r24,#4);
p0 = cmp.ltu(r24,r25)
if (p0) jump 1b

1:
jump 1b
#endif
//	call debug_tlb_miss_fetch

	/* Time to make the doughnuts and drink Kefir.   */
	call start_kernel		

	/*
	 * Should not reach here.
	 */
1:
	jump 1b

.p2align PAGE_SHIFT
ENTRY(external_cmdline_buffer)
        .fill _PAGE_SIZE,1,0

.data
.p2align PAGE_SHIFT
ENTRY(empty_zero_page)
        .fill _PAGE_SIZE,1,0



// kernel L1 PTE - 1024 entries, each describes 4M
// must be aligned to 4096 bytes
//
// linux generic mm code rely to that global variable
// it's used as init_mm.pgd value
//
    .data
    .p2align 12
    .globl swapper_pg_dir
swapper_pg_dir:
    .fill (4 * 1024), 1, 0

