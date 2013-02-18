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
#include <asm/cacheflush.h>
#include <asm/hexagon_vm.h>
#include "native_defs.h"



#define spanlines(start, end) \
	(((end - (start & ~(LINESIZE - 1))) >> LINEBITS) + 1)


// Added function according to Hexagon Virtual Machine specifications
// for IDSYNC cache opcode (page 30)
// Not clear why it must flush and invalidate DCache instead of just flush...
//
void hexagon_idsync_range(unsigned long start, unsigned long end)
{
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


extern void my_out(const char *str, ...);

void debug_error_out(uint32_t elr, uint32_t badva, uint32_t lr)
{
	my_out("ERROR: ELR=%08X ADDR=%08X LR=%08X\r\n", elr, badva, lr);
}

