//
// trap1.S
//
// implements HVM trap1 ops for QDSP6
//
// 2013, Cotulla, Jon Pry
// 

#include <linux/linkage.h>
#include <linux/init.h>
#include <asm/asm-offsets.h>
#include <asm/mem-layout.h>
#include <asm/hexagon_vm.h>
#include <asm/vm_mmu.h>
#include <asm/page.h>

#include "qdsp6_tlb.h"
#include "tlb_usage.h"
#include "native_defs.h"
#include "swd_regs.h"



#define LOAD32(reg, value)    \
        reg.h = #HI(value);    \
        reg.l = #LO(value)

//
    .macro GET_TID reg
	\reg = ssr
// Thread ID [0..5]
    	\reg = extractu (\reg, #3, #19)
    .endm

	.section	".coresys", "ax"


///////////////////////////////////////////////////////////////////////
// trap1 modify r0-r4 registers
// like ABI function call
// r0 and r1 are parameters
//
ENTRY(exc_trap1)
	//Decode cause
	crswap (r10, sgp);
	memd(r10 + #_R0504) = r5:4;
        memw(r10 + #_R31) = r31; 	// LR
        r4 = p3:0
        memw(r10 + #_RFLAGS) = r4; 

	r5 = ssr;
	r5 = extractu(r5, #8, #SSR_BIT_CAUSE);

	//Largest trap is MY_TRAP1_MAX
	p0 = cmp.gt(r5, #MY_TRAP1_MAX)
	if (p0) jump error_no_trap

	LOAD32(r4,trap_base)
	r4 += asl(r5, #2)
	jumpr r4

trap_base:
	jump error_no_trap	//0
	jump trap1_rte          //HVM_TRAP1_VMRTE		1
	jump trap1_setvec       //HVM_TRAP1_VMSETVEC		2       IMP
	jump trap1_setie        //HVM_TRAP1_VMSETIE		3       IMP
	jump trap1_getie        //HVM_TRAP1_VMGETIE		4       IMP
	jump error_no_trap	//HVM_TRAP1_VMINTOP		5
	jump error_no_trap	//6
	jump error_no_trap	//7
	jump error_no_trap	//8
	jump error_no_trap	//9	
	jump trap1_clrmap       //HVM_TRAP1_VMCLRMAP		10      IMP
	jump trap1_newmap	//HVM_TRAP1_VMNEWMAP		11      IMP
	jump error_no_trap	//HVM_TRAP1_FORMERLY_VMWIRE	12	NOT USED
	jump error_no_trap	//HVM_TRAP1_VMCACHE		13      No usage
	jump trap1_gettime	//HVM_TRAP1_VMGETTIME		14      IMP
	jump error_no_trap	//HVM_TRAP1_VMSETTIME		15	NOT USED
	jump trap1_wait		//HVM_TRAP1_VMWAIT		16
	jump error_no_trap	//HVM_TRAP1_VMYIELD		17
	jump trap1_start	//HVM_TRAP1_VMSTART		18
	jump error_no_trap	//HVM_TRAP1_VMSTOP		19
	jump error_no_trap	//HVM_TRAP1_VMVPID		20      NOT USED
	jump trap1_setregs	//HVM_TRAP1_VMSETREGS		21
	jump trap1_getregs	//HVM_TRAP1_VMGETREGS		22

	jump trap1_int_gtoggle	//MY_TRAP1_INT_GTOGGLE		23
	jump trap1_int_cfg      //MY_TRAP1_INT_CFG		24
	jump trap1_int_raise    //MY_TRAP1_INT_RAISE		25
	jump trap1_int_enable   //MY_TRAP1_INT_ENABLE		26
	jump trap1_int_disable  //MY_TRAP1_INT_DISABLE		27
	jump trap1_int_done     //MY_TRAP1_INT_DONE		28
	jump trap1_int_init     //MY_TRAP1_INT_INIT		29
	jump trap1_int_settype  //MY_TRAP1_INT_SETTYPE		30
	jump trap1_int_setpol   //MY_TRAP1_INT_SETPOL 		31
	jump trap1_init         //MY_TRAP1_INIT 		32


ENTRY(error_no_trap)
	LOAD32(r29, DebugStack)
	r0 = lsr(r4,#2)
	r1 = elr
	call debug_trap1_out
	jump  .


return_from_trap1:
	r31 = memw(r10 + #_R31)
	r4 = memw(r10 + #_RFLAGS);
	p3:0 = r4; 
	crswap (r10, sgp)
	rte


///////////////////////////////////////////////////////////////////////
//	 T R A P 1    I M P L E M E N T A T I O N
///////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////
// R0 - page table PA
//
trap1_newmap:
	call 	coresys_newmap			// No stack usage
	call 	coresys_clear_tlb_replace	
	jump 	return_from_trap1
	

///////////////////////////////////////////////////////////////////////
trap1_clrmap:
	call	coresys_clear_tlb_replace	// No stack usage
	jump 	return_from_trap1
	

///////////////////////////////////////////////////////////////////////
// returns uint64 in r0:1
//
trap1_gettime:
	r1 = pcyclehi
	r0 = pcyclelo
	r3 = pcyclehi
	p0 = cmp.eq (r3, r1)
	if !p0 jump trap1_gettime

	jump 	return_from_trap1


//////////////////////////////////
trap1_setvec:
	LOAD32(r1, coresys_gevb)
	memw(r1) = r0
	jump 	return_from_trap1

//////////////////////////////////
trap1_wait:
	//this doesn't seem to work
	//interrupts probably have to be enabled by dropping SSR[EXC]
	//exc_interrupt must be short circuited somehow first
//        r0 = #0
//	wait(r0)
	jump 	return_from_trap1

//////////////////////////////////
trap1_start:
	//r0 = starting address
	//r1 = stack pointer
	LOAD32(r2, thread_start)
	memw(r2) = r0
	LOAD32(r2, thread_stack)
	memw(r2) = r1

	//The new thread inherits the creators l1 table
	GET_TID	r2
        LOAD32(r1, L1PageTables);
    	r1 += asl(r2, #2)
   	r1 = memw (r1)
	LOAD32(r2, thread_map)
	memw(r2) = r1


	r2 = #1
	//TODO: replace #1 with core to start
	r2 = asl(r2,#1)
	start(r2)
	jump	return_from_trap1


///////////////////////////////////////////////////////////////////////
//  r0 possible values are:
//	VM_INT_DISABLE	= 0
//	VM_INT_ENABLE	= 1
//  
//  must return old interrupt state 
//
trap1_setie:
	r1 = ssr
	r2 = extractu (r1, #1, #SSR_BIT_IE)	
	r1 = insert (r0, #1, #SSR_BIT_IE)	
	ssr = r1
	r0 = r2
	jump 	return_from_trap1


///////////////////////////////////////////////////////////////////////
trap1_getie:
	r1 = ssr
	r0 = extractu (r1, #1, #SSR_BIT_IE)
	jump 	return_from_trap1
	
///////////////////////////////////////////////////////////////////////
// getregs doesn't use c calling conventions. no registers can be 
// clobbered!
trap1_getregs:
	r3 = #0
    	memw(r10 + #_RGUARD) = r3
	r0 = memw(r10 + #_RGELR);
	r1 = memw(r10 + #_RGSR);
	r2 = memw(r10 + #_RGOSP);
	r3 = memw(r10 + #_RGBADVA);
	r4 = memw(r10 + #_RFLAGS);
	p3:0 = r4
	//R5:4 was clobbered by trap1 entry
	// R31 is not touched
	r5:4 = memd(r10 + #_R0504);
	crswap(r10, sgp)
	rte

///////////////////////////////////////////////////////////////////////
trap1_setregs:
	memw(r10 + #_RGELR) = r0
	memw(r10 + #_RGSR) = r1
	memw(r10 + #_RGOSP) = r2
	memw(r10 + #_RGBADVA) = r3
	jump return_from_trap1

///////////////////////////////////////////////////////////////////////
trap1_int_gtoggle:
	call 	coresys_int_gtoggle
	jump	return_from_trap1

trap1_int_cfg:
	call 	coresys_int_cfg
	jump	return_from_trap1

trap1_int_raise:
	call 	coresys_int_raise
	jump	return_from_trap1

trap1_int_enable:
	call 	coresys_int_enable
	jump	return_from_trap1

trap1_int_disable:
	call 	coresys_int_disable
	jump	return_from_trap1

trap1_int_done:
	call 	coresys_int_done
	jump	return_from_trap1

trap1_int_init:
	call 	coresys_int_init
	jump	return_from_trap1

trap1_int_settype:
	call 	coresys_int_settype
	jump	return_from_trap1

trap1_int_setpol:
	call 	coresys_int_setpol
	jump	return_from_trap1


///////////////////////////////////////////////////////////////////////
// do coresys initilization
// Supervisor mode -> User mode transfer
//
trap1_init:
	call coresys_init

	// change mode to USER
	r1 = ssr
	r1 = setbit(r1, #SSR_BIT_USR)
	ssr = r1	

	crswap (r10, sgp)
	rte


///////////////////////////////////////////////////////////////////////
// Return from exception:
// 1)exchange stack for switch to user mode (GOSP <-> R29)
// 2)set SSR bits according to GSR
//
trap1_rte:
	memd (r10 + #_R0100) = r1:0
	memd (r10 + #_R0302) = r3:2

//TODO: Ensure that atomic operation in progress at exception time will fail
#if 0
	r0 = memw_locked(r29)
	memw_locked(r29,p0) = r0 
#endif
//deal with gsr
//TODO: needs to be optimized and actually work so bits can be cleared
	r1 = memw(r10 + #_RGELR);
	elr = r1


	// Handle stack swap
	//
	r1 = memw(r10 + #_RGSR);
	p0 = tstbit(r1, #GSR_USR);
	if (!p0) jump trap1_rte_non_user_mode 

	// return to USER mode
	{ r29 = memw(r10 + #_RGOSP); memw(r10 + #_RGOSP) = r29; }

	
trap1_rte_non_user_mode:

	// Modify SSR[IE], SSR[USR] here 
	// we hold linux kernel/user mode flag as bit0 in ASID
	//	
	r2 = ssr
	r3 = extractu (r1, #1, #GSR_USR)
	r2 = insert (r3, #1, #SSR_BIT_ASID_USR)	// ASID change!!

	r3 = extractu (r1, #1, #GSR_IE)
	r2 = insert (r3, #1, #SSR_BIT_IE)

	r2 = setbit(r2, #SSR_BIT_USR)
	ssr = r2;
	isync

	//Restore r0,r10,flags
	r0 = memw(r10 + #_RFLAGS);
	p3:0 = r0
	//R5:4 was clobbered by trap1 entry
	r5:4 = memd(r10 + #_R0504);
	r3:2 = memd(r10 + #_R0302);
	r1:0 = memd(r10 + #_R0100);
	crswap (r10, sgp)
	rte


///////////////////////////////////////////////////////////////////////
//    D A T A    D E F I N I T I O N S
///////////////////////////////////////////////////////////////////////
.global coresys_gevb
coresys_gevb: .word 0



