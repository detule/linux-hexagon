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

__CPUINIT

.global exc_trap1

exc_trap1:
	//Decode cause
	crswap (r10, sgp);
	{ r0 = p3:0; memd(r10 + #_R0100) = r1:0; }

	r0 = ssr;
	r0 = extractu(r0,#8,#SSR_BIT_CAUSE);
	//Largest trap is 22
	p0 = cmp.ge(r0,#22)
	if(p0) jump error_no_trap
	LOAD32(r1,trap_base)
	r0 = asl(r0,#2)
	r0 = add(r1,r0)
	jumpr r0

trap_base:
	jump error_no_trap	//0
	jump error_no_trap	//HVM_TRAP1_VMRTE		1
	jump error_no_trap	//HVM_TRAP1_VMSETVEC		2
	jump error_no_trap	//HVM_TRAP1_VMSETIE		3
	jump error_no_trap	//HVM_TRAP1_VMGETIE		4
	jump error_no_trap	//HVM_TRAP1_VMINTOP		5
	jump error_no_trap	//6
	jump error_no_trap	//7
	jump error_no_trap	//8
	jump error_no_trap	//9	
	jump error_no_trap	//HVM_TRAP1_VMCLRMAP		10
	jump error_no_trap	//HVM_TRAP1_VMNEWMAP		11
	jump error_no_trap	//HVM_TRAP1_FORMERLY_VMWIRE	12
	jump error_no_trap	//HVM_TRAP1_VMCACHE		13
	jump error_no_trap	//HVM_TRAP1_VMGETTIME		14
	jump error_no_trap	//HVM_TRAP1_VMSETTIME		15
	jump error_no_trap	//HVM_TRAP1_VMWAIT		16
	jump error_no_trap	//HVM_TRAP1_VMYIELD		17
	jump error_no_trap	//HVM_TRAP1_VMSTART		18
	jump error_no_trap	//HVM_TRAP1_VMSTOP		19
	jump error_no_trap	//HVM_TRAP1_VMVPID		20
	jump error_no_trap	//HVM_TRAP1_VMSETREGS		21
	jump error_no_trap	//HVM_TRAP1_VMGETREGS		22

ENTRY(error_no_trap)
    LOAD32(r29, DebugStack)
    r0 = lsr(r0,#2)
    r1 = elr
    call debug_trap1_out
    jump  .

