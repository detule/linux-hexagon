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
	my_out("TLB %d values: LO_PA=%08X HI_VA=%08X\n", idx, lo, hi);
}


void debug_tlb_miss_fetch(void)
{
	my_out("== swapper_pg_dir DEBUG ==\n");
	my_out("\tswapper_pg_dir VA: %X PA: %X\n", (u32)swapper_pg_dir, __pa(swapper_pg_dir));
	my_out("\tswapper_pg_dir[0] = %08X\n\t", swapper_pg_dir[0]);
	debug_dump_tlb(TLBUSG_L1FETCH);
}



void debug_error_out(uint32_t elr, uint32_t badva, uint32_t lr)
{
	my_out("ERROR: SSR=%X ELR=%08X ADDR=%08X LR=%08X\r\n", get_ssr(), elr, badva, lr);	
	my_out("swapper entry %08X\n", swapper_pg_dir[badva >> 22]);

	debug_dump_tlb(TLBUSG_L1FETCH);
	debug_dump_tlb(TLBUSG_L2FETCH);
	
	sprint_symbol(symBuf1, elr);
	sprint_symbol(symBuf2, lr);
	my_out("  ELR='%s' LR='%s'\r\n", symBuf1, symBuf2);
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
                                  