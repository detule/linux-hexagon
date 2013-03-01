/*
 * Native management functions for Hexagon
 *
 * Copyright (c) 2013 Cotulla
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

#include <linux/mm.h>
#include <linux/module.h>
#include <linux/kallsyms.h>
#include <asm/cacheflush.h>
#include <asm/hexagon_vm.h>
#include "native_defs.h"
#include "tlb_usage.h"



#define spanlines(start, end) \
	(((end - (start & ~(LINESIZE - 1))) >> LINEBITS) + 1)


// Added function according to Hexagon Virtual Machine specifications
// for IDSYNC cache opcode (page 30)
// Not clear why it must flush and invalidate DCache instead of just flush...
//
void hexagon_idsync_range(unsigned long start, unsigned long size)
{
	unsigned long end = start + size;
	unsigned long lines = spanlines(start, end-1);
	unsigned long i, flags;

	start &= ~(LINESIZE - 1);

	local_irq_save(flags);

	for (i = 0; i < lines; i++) {
		__asm__ __volatile__ (
			"	dccleaninva(%0); "
			"	icinva(%0);	"
			:
			: "r" (start)
		);
		start += LINESIZE;
	}
	__asm__ __volatile__ (
		"isync"
	);
	local_irq_restore(flags);
}


long __vmcache(enum VM_CACHE_OPS op, unsigned long addr, unsigned long len)
{
	switch (op)
	{
	case ickill:
		__asm__ __volatile__ (
			"ickill"
		);
	break;
	case dckill:
		__asm__ __volatile__ (
			"dckill"
		);
	break;
	case l2kill:
		__asm__ __volatile__ (
			"l2kill"
		);
	break;
	case idsync:
        	hexagon_idsync_range(addr, len);
	break;
	
	}
	return 0;
}



extern void coresys_newmap(u32 pte_base);


long __vmnewmap(void * base)
{
	printk("++++SET NEW MAP++++ %08X\n", (u32)base);
	coresys_newmap((u32)base);
	return 0;	
}



extern void my_out(const char *str, ...);
extern int get_miss_count(void);

static char symBuf1[KSYM_SYMBOL_LEN];
static char symBuf2[KSYM_SYMBOL_LEN];


u32 get_ssr(void)
{
	u32 val = 0;

	__asm__ __volatile__(
		"%0 = ssr;\n"
		: "=r" (val)
	);
	return val;
}


u32 get_elr(void)
{
	u32 val = 0;

	__asm__ __volatile__(
		"%0 = elr;\n"
		: "=r" (val)
	);
	return val;
}

void debug_dump_tlb(u32 idx)
{
	u32 lo = 0, hi = 0;

	__asm__ __volatile__(
		"tlbidx = %2;\n"
		"tlbr;\n"
		"%0 = tlblo;\n"
		"%1 = tlbhi;\n"
		: "=r" (lo), "=r" (hi)
		: "r" (idx)
	);
	my_out("TLB %02d values: LO_PA=%08X HI_VA=%08X\n", idx, lo, hi);
}


void debug_dump_tlb_all(void)
{
	u32 i;
	u32 lo = 0, hi = 0;

	for (i = 0; i < 64; i++)
	{
	__asm__ __volatile__(
		"tlbidx = %2;\n"
		"tlbr;\n"
		"%0 = tlblo;\n"
		"%1 = tlbhi;\n"
		: "=r" (lo), "=r" (hi)
		: "r" (i)
	);
	if (lo != 0 && hi != 0) my_out("TLB %02d values: LO_PA=%08X HI_VA=%08X\n", i, lo, hi);
	}
}


void debug_tlb_miss_fetch(void)
{
	my_out("== swapper_pg_dir DEBUG ==\n");
	my_out("\tswapper_pg_dir VA: %X PA: %X\n", (u32)swapper_pg_dir, __pa(swapper_pg_dir));
	my_out("\tswapper_pg_dir[0] = %08X\n\t", swapper_pg_dir[0]);
	debug_dump_tlb(TLBUSG_L1FETCH);
}


void debug_test_out(uint32_t elr, uint32_t badva, uint32_t lr)
{
	my_out("ERR_TST: %d SSR=%X ELR=%08X ADDR=%08X LR=%08X\r\n", get_miss_count(), get_ssr(), elr, badva, lr);	
	
	sprint_symbol(symBuf1, elr);
	sprint_symbol(symBuf2, lr);
	my_out("  ELR='%s' LR='%s'\r\n", symBuf1, symBuf2);
}


extern u32 tlb_debug_log;
extern u32 DebugLog[];

void debug_tlb_last(void)
{
	int i;

	my_out("tlb_debug_log=%d\r\n", tlb_debug_log);

	for (i = 0; i < tlb_debug_log; i++)
	{
		u32 *ptr = &DebugLog[4 * i];
		my_out("%02d: A=%08X LR=%08X SSR=%08X ELR=%08X\n", i, ptr[0], ptr[1],ptr[2],ptr[3]);	
	}
}


void debug_error_out(uint32_t elr, uint32_t badva, uint32_t lr)
{
	my_out("ERROR: %d SSR=%X ELR=%08X ADDR=%08X LR=%08X\r\n", get_miss_count(), get_ssr(), elr, badva, lr);	
	my_out("swapper entry %08X\n", swapper_pg_dir[badva >> 22]);

	debug_dump_tlb(TLBUSG_L1FETCH);
	debug_dump_tlb(TLBUSG_L2FETCH);
	
	sprint_symbol(symBuf1, elr);
	sprint_symbol(symBuf2, lr);
	my_out("  ELR='%s' LR='%s'\r\n", symBuf1, symBuf2);
	debug_tlb_last();
}


void do_dump_tlb_miss(u32 elr, u32 badva, u32 lr)
{
	my_out("MISSTLB: %d SSR=%X ELR=%08X ADDR=%08X LR=%08X\r\n", get_miss_count(), get_ssr(), elr, badva, lr);
}

void debug_intr_out(uint32_t elr, uint32_t lr)
{
	my_out("INTR: ELR=%08X LR=%08X SSR=%X\r\n", elr, lr, get_ssr());
	sprint_symbol(symBuf1, elr);
	sprint_symbol(symBuf2, lr);
	my_out("  ELR='%s' LR='%s'\r\n", symBuf1, symBuf2);
}


//void debug_tlbmiss_invalid(uint32_t elr, uint32_t badva, uint32_t lr)
void debug_tlbmiss_invalid(uint32_t elr, uint32_t badva, uint32_t lr, u32 indx, u32 tid)
{
	my_out("ERROR TLBMISS %d: SSR=%X ELR=%08X ADDR=%08X LR=%08X %X %X\r\n", get_miss_count(), get_ssr(), elr, badva, lr, indx, tid);	
	my_out("swapper entry  %08X\n", swapper_pg_dir[badva >> 22]);
	my_out("swapper entry2 %08X\n", ((u32*)0xF0000000)[badva >> 22]);
	my_out("swapper entry3 %08X\n", ((u32*)0xF0100000)[(badva >> 12) & 0x3FF]);

	debug_dump_tlb(TLBUSG_L1FETCH);
	debug_dump_tlb(TLBUSG_L2FETCH);
	debug_dump_tlb(TLBUSG_REPLACE_MIN);
	debug_dump_tlb(TLBUSG_REPLACE_MIN + 1);
	
#if 1
	sprint_symbol(symBuf1, elr);
	sprint_symbol(symBuf2, lr);
	my_out("  ELR='%s' LR='%s'\r\n", symBuf1, symBuf2);
#endif
}


asmlinkage void __sched test_schedule(void)
{
	my_out("schedule1 SSR=%X ELR=%X\n", get_ssr(), get_elr());
	schedule();
	my_out("schedule2 SSR=%X\n", get_ssr());
}


// special test code for testing xmiss on page boundary
// 4 instructions in the one packet - 16 bytes
//

extern void tst_pkg_code_start(void);
extern void tst_pkg_code_end(void);
typedef void (*TstPkgCode_t)(void);


void debug_xfault_on_page_bound(void)
{
	TstPkgCode_t fn;
	int csize = (u32)tst_pkg_code_end - (u32)tst_pkg_code_start;
	u8 *ptr = (u8*)0x70000000;	
	printk("debug_xfault_on_page_bound = %X csize = %d\n", ptr, csize);
	csize = 8;

//	memcpy((ptr + 0xFF8), (void*)tst_pkg_code_start, csize);
//	fn = (TstPkgCode_t)(ptr + 0xFF8);
	fn = (TstPkgCode_t)(ptr + 0x1000);
	printk("before call\n");
	fn();
	printk("after call\n");
	while (1);
}
                                  