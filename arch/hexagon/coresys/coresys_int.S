//
// coresys_int.S
//
// implements interrupt support for QDSP6
//
// 2013, Cotulla
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


	.section	".coresys", "ax"


///////////////////////////////////////////////////////////////////////
//    I N T E R R U P T     C O D E 
///////////////////////////////////////////////////////////////////////

// interrupts init
//
ENTRY(coresys_int_init)
    r0 = #0
    imask = r0

    r1 = #-1
    iel = r1
    iahl = r1
    cswi (r1)
    ciad (r1)
    imask = r1
    isync
    jumpr r31



// r0 - interrupt number
// r1 - 1 active high
//      0 active low
//
ENTRY(coresys_int_setpol)

// get bit clear mask
    r3 = #1
    r3 = asl (r3, r0)	// r3 = 1 << intr
    r3 = sub (#-1, r3)  // r3 = 0xFFFF FFFF - (1 << intr)

// modify    
    r2 = iahl
    r2 = and (r2, r3)	// clear bit
    r2 |= asl (r1, r0)	// set new value
    iahl = r2

    isync
    jumpr r31



// r0 - interrupt number
// r1 - 1 edge
//      0 level
//
ENTRY(coresys_int_settype)

// get bit clear mask
    r3 = #1
    r3 = asl (r3, r0)	// r3 = 1 << intr
    r3 = sub (#-1, r3)  // r3 = 0xFFFF FFFF - (1 << intr)

// modify    
    r2 = iel
    r2 = and (r2, r3)	// clear bit
    r2 |= asl (r1, r0)	// set new value
    iel = r2

    isync
    jumpr r31


// r0 - interrupt number
// r1 - mask
//
ENTRY(coresys_int_cfg)

    r0 = and (r0, #31) 
    r0 = sub (#31, r0)
	
    r2 = asl (r0, #16)
    r1 = or (r2, r1)
    iassignw (r1)	
    jumpr r31



// r0 - interrupt number
//
ENTRY(coresys_int_done)

    r0 = and (r0, #31) 
    r0 = sub (#31, r0)
	
    r1 = #0 
    r1 = setbit (r1, r0)

    ciad (r1)	
    jumpr r31


// r0 - interrupt number
//
ENTRY(coresys_int_raise)

    r0 = and (r0, #31) 
    r0 = sub (#31, r0)
	
    r1 = #0 
    r1 = setbit (r1, r0)

    swi (r1)	
    jumpr r31


ENTRY(coresys_int_pending)
    r0 = ipend
    jumpr r31


// r0 - interrupt number
//
ENTRY(coresys_int_enable)

    r0 = and (r0, #31) 
    r0 = sub (#31, r0)

    r2 = imask
    r2 = clrbit (r2, r0)
    imask = r2

    r1 = #0 
    r1 = setbit (r1, r0)
    ciad (r1)	

    jumpr r31



// r0 - interrupt number
//
ENTRY(coresys_int_disable)

    r0 = and (r0, #31) 
    r0 = sub (#31, r0)

    r2 = imask
    r2 = setbit (r2, r0)
    imask = r2

    jumpr r31


// r0 - 0 disable, 1 enable
//
ENTRY(coresys_int_gtoggle)
   
    r1 = syscfg
    r1 = insert(r0, #1, #SYSCFG_GIE)
    syscfg = r1

    jumpr r31


// r0 - 0 disable, 1 enable
//
ENTRY(coresys_int_ltoggle)
   
    r1 = ssr
    r1 = insert(r0, #1, #SSR_BIT_IE)
    ssr = r1

    jumpr r31


