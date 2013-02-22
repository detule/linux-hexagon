/*
 * Hexagon kernel native support
 *
 * Copyright (c) 2013, Cotulla.
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
#include <asm/hexagon_vm.h>

#include "native_defs.h"


/*
 * C wrappers for virtual machine "instructions".  These
 * could be, and perhaps some day will be, handled as in-line
 * macros, but for tracing/debugging it's handy to have
 * a single point of invocation for each of them.
 * Conveniently, they take paramters and return values
 * consistent with the ABI calling convention.
 */

// __vmrte is not used from C code, only from asm code

ENTRY(__vmsetvec)
// TODO: save pointer to coresys area
//	trap1(#HVM_TRAP1_VMSETVEC);
	jumpr	R31;


/*
  r0 possible values are:
	VM_INT_DISABLE	= 0
	VM_INT_ENABLE	= 1
  
  must returns old interrupt state 
*/


ENTRY(__vmsetie)
	r1 = ssr
	r2 = extractu (r1, #1, #SSR_BIT_IE)	
	r1 = insert (r0, #1, #SSR_BIT_IE)	
	ssr = r1
	r0 = r2
	jumpr	R31;

ENTRY(__vmgetie)
	r1 = ssr
	r0 = extractu (r1, #1, #SSR_BIT_IE)
	jumpr	R31;


ENTRY(__vmintop)
	trap1(#HVM_TRAP1_VMINTOP);
	jumpr	R31;

ENTRY(__vmclrmap)
// TODO: clear TLB entries and map values
//	trap1(#HVM_TRAP1_VMCLRMAP);
	jumpr	R31;


// __vmnewmap implemented inside .C file
// __vmcache implemented inside .C file


// returns uint64 in r0:1
// old is HVM_TRAP1_VMGETTIME
//
ENTRY(__vmgettime)
	r1 = pcyclehi
	r0 = pcyclelo
	r3 = pcyclehi
	p0 = cmp.eq (r3, r1)
	if !p0 jump __vmgettime
	jumpr	R31;

// __vmsettime is not referenced and not used

ENTRY(__vmwait)
	trap1(#HVM_TRAP1_VMWAIT);
	jumpr	R31;

ENTRY(__vmyield)
	trap1(#HVM_TRAP1_VMYIELD);
	jumpr	R31;

ENTRY(__vmstart)
// TODO: implement it 
//	trap1(#HVM_TRAP1_VMSTART);
	jumpr	R31;

ENTRY(__vmstop)
// TODO: implement it 
//	trap1(#HVM_TRAP1_VMSTOP);
	jumpr	R31;

// __vmvpid is not used


/*  Probably not actually going to use these; see vm_entry.S  */

ENTRY(__vmsetregs)
	trap1(#HVM_TRAP1_VMSETREGS);
	jumpr	R31;

ENTRY(__vmgetregs)
	trap1(#HVM_TRAP1_VMGETREGS);
	jumpr	R31;



