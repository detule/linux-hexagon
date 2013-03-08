/*
 * Hexagon VM instruction support
 *
 * Copyright (c) 2010-2011, The Linux Foundation. All rights reserved.
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

/*
 * C wrappers for virtual machine "instructions".  These
 * could be, and perhaps some day will be, handled as in-line
 * macros, but for tracing/debugging it's handy to have
 * a single point of invocation for each of them.
 * Conveniently, they take paramters and return values
 * consistent with the ABI calling convention.
 */

ENTRY(__vmsetvec)
	trap1(#HVM_TRAP1_VMSETVEC);
	jumpr	R31;

ENTRY(__vmsetie)
	trap1(#HVM_TRAP1_VMSETIE);
	jumpr	R31;

ENTRY(__vmgetie)
	trap1(#HVM_TRAP1_VMGETIE);
	jumpr	R31;

ENTRY(__vmintop)
	trap1(#HVM_TRAP1_VMINTOP);
	jumpr	R31;

ENTRY(__vmclrmap)
	trap1(#HVM_TRAP1_VMCLRMAP);
	jumpr	R31;

ENTRY(__vmnewmap)
	r1 = #VM_NEWMAP_TYPE_PGTABLES;
	trap1(#HVM_TRAP1_VMNEWMAP);
	jumpr	R31;

ENTRY(__vmcache)
// NOT USED
//	trap1(#HVM_TRAP1_VMCACHE);
	jumpr	R31;

ENTRY(__vmgettime)
	trap1(#HVM_TRAP1_VMGETTIME);
	jumpr	R31;

ENTRY(__vmwait)
	trap1(#HVM_TRAP1_VMWAIT);
	jumpr	R31;

ENTRY(__vmyield)
//	trap1(#HVM_TRAP1_VMYIELD);
	jumpr	R31;

ENTRY(__vmstart)
	trap1(#HVM_TRAP1_VMSTART);
	jumpr	R31;

ENTRY(__vmstop)
//	trap1(#HVM_TRAP1_VMSTOP);
	jumpr	R31;


ENTRY(__my_int_cfg)
	trap1(#MY_TRAP1_INT_CFG);
	jumpr	r31;

ENTRY(__my_int_raise)
	trap1(#MY_TRAP1_INT_RAISE);
	jumpr	r31;

ENTRY(__my_int_enable)
	trap1(#MY_TRAP1_INT_ENABLE);
	jumpr	r31;

ENTRY(__my_int_disable)
	trap1(#MY_TRAP1_INT_DISABLE);
	jumpr	r31;

ENTRY(__my_int_done)
	trap1(#MY_TRAP1_INT_DONE);
	jumpr	r31;

ENTRY(__my_int_init)
	trap1(#MY_TRAP1_INT_INIT);
	jumpr	r31;

ENTRY(__my_int_settype)
	trap1(#MY_TRAP1_INT_SETTYPE);
	jumpr	r31;

ENTRY(__my_int_setpol)
	trap1(#MY_TRAP1_INT_SETPOL);
	jumpr	r31;

ENTRY(__my_int_gtoggle)
	trap1(#MY_TRAP1_INT_GTOGGLE);
	jumpr	r31;

