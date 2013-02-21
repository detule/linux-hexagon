//
// coresys.S
//
// implements SW MMU for QDSP6
//
// 2013, Cotulla
// 

/*

    SW MMU assembly code 

    This code assumed to be run inside special coresys area    
    which is always mapped by TLB. We map it to TLB #0.
    
    TLB has 64 entries.

*/


#include <linux/linkage.h>
#include <linux/init.h>
#include <asm/asm-offsets.h>
#include <asm/mem-layout.h>
#include <asm/vm_mmu.h>
#include <asm/page.h>

#include "qdsp6_tlb.h"
#include "tlb_usage.h"
#include "native_defs.h"



    .macro TLB_ENTRY_SET index, regl, regh
        tlbhi = \regh
        tlblo = \regl
        tlbidx = \index
        tlbw
        isync        
    .endm


// Get hardware thread ID
//
    .macro GET_TID reg
	\reg = ssr
// Thread ID [0..5]
    	\reg = extractu (\reg, #3, #19)
    .endm


#define LOAD32(reg, value)    \
        reg.h = #HI(value);    \
        reg.l = #LO(value)





#define HW_THREADS          6
#define L1_PAGETABLE_SIZE   4096
#define SUPER_WORLD_SIZE    128


#define L1FETCH_ADDRESS     0xF0000000


#define L2FETCH_ADDRESS     0xF0100000
#define L2FETCH_TLB_HI      TLB_MAKE_HI(TLB_ADDR(L2FETCH_ADDRESS), 1, 0)  // global = 1, ASID = 0
#define L2FETCH_TLB_LO      TLB_MAKE_LO(0, TLB_SIZE_4K, TLB_L1WB_L2C, TLB_R) // without actual PA address


	__CPUINIT



ENTRY(_SW_MMU_START)

    .ascii  "Q6SM"      // signature


// this global variable holds last changed TLB index
// during TLBMiss operation
//
tlb_last_index: .word   TLBUSG_REPLACE_MIN

tlb_miss_count: .word   0



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
ENTRY(coresys_int_setpolarity)

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



///////////////////////////////////////////////////////////////////////
//    S W    M M U     & &    E X C E P T I O N S 
///////////////////////////////////////////////////////////////////////




// coresys initilization function
// must be runned once on thread #0
// setup exception vectors
// init supervisor global pointer register
//
ENTRY(coresys_init)
    LOAD32(r0, exc_vectors)
    evb = r0

// Clear data storage
//
    r1 = #0
    LOAD32(r0, SuperWorldData)
    r3 = #((HW_THREADS * SUPER_WORLD_SIZE) / 4)
    loop0(1f, r3)
1:
    {
	memw(r0 ++ #4) = r1
    }:endloop0


// clear page tables pointers
//
    LOAD32(r0, L1PageTables)
    r3 = #HW_THREADS
    loop0(2f, r3)
2:
    {
	memw(r0 ++ #4) = r1
    }:endloop0


// clear L1 kernel page table
// fill it with __HVM_PDE_S_INVALID
//
    LOAD32(r0, swapper_pg_dir)
    r1 = #__HVM_PDE_S_INVALID
    r3 = #1024	// 1024 entries in L1, each 4M  
    loop0(3f, r3)
3:
    {
	memw(r0 ++ #4) = r1
    }:endloop0

    	
    GET_TID r6

// Setup SGP value
//
    r4 = #SUPER_WORLD_SIZE
    r4 = mpyi (r6, r4)              // r4 - Offset in bytes 

    LOAD32(r5, SuperWorldData)
    r5 = add (r5, r4)
    sgp = r5          

    jumpr r31



// function for debug purposes
//
ENTRY(get_miss_count)
    LOAD32(r0, tlb_miss_count)
    r0 = memw (r0)
    jumpr r31




// r0 - physical address of L1 pagetable
//
ENTRY(coresys_newmap)

    GET_TID r3	

// store value for debug purposes
//
    LOAD32(r2, L1PageTables)
    r2 += asl(r3, #2)
    memw (r2) = r0
  

// update TLB mapping for L1
//
    r3 = asl (r3, #12)		// r3 = TID * 0x1000 = offset 

    LOAD32(r1, TLB_MAKE_LO(0, TLB_SIZE_4K, TLB_L1WB_L2C, TLB_R)) // PA
    r0 += asl (r3, #12)		// r0 = physic L1 address + TID * 0x1000
    r1 |= lsr (r0, #12)         // to TLB format
    // r1 - PA LO TLB entry


    LOAD32(r0, TLB_MAKE_HI(0, 1, 0)) // VA global
    LOAD32(r2, L1FETCH_ADDRESS);
    r2 += asl (r3, #12)		// r2 = L1FETCH_ADDRESS + TID * 0x1000
    r0 |= lsr (r2, #12)         // to TLB format
    // r0 - VA HI TLB entry	

    r2 = #TLBUSG_L1FETCH
    r2 = add (r2, r3) 		// r2 = TLBUSG_L1FETCH + TID
    TLB_ENTRY_SET r2, r1, r0 // idx, lo, hi


    jumpr r31
    



ENTRY(coresys_clrmap)
// CotullaTODO: implement it
// probably use tlbp to locate TLB index for specified VA and clear it?
//
    jumpr r31




//
// Exception vectors 
//
    .p2align 12
exc_vectors:
    jump exc_reset
    jump exc_nmi
    jump exc_error
    jump exc_error
    jump exc_tlbmiss_X
    jump exc_reserved
    jump exc_tlbmiss_RW
    jump exc_reserved
    jump exc_trap
    jump exc_trap
    jump exc_reserved
    jump exc_reserved
    jump exc_reserved
    jump exc_reserved
    jump exc_reserved
    jump exc_reserved

    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int
    jump exc_int


exc_nmi:
exc_error:
exc_reserved:
//    jump handle_error_exception
// Debug error code which prints information about exception
// 
#if 1
    LOAD32(r29, DebugStack)
    r0 = r8
    r1 = badva
    r2 = r31
    call debug_error_out
#endif
    jump    .


// called when HW thread core started by start (r0) command
//
exc_reset:

// CotullaTODO
#if 0
// setup GP pointer
    LOAD32(r0, __default_sda_base__)
    gp = r0

// setup stack pointer
    LOAD32(r0, 0x11900000 - 16)
    r29 = r0

#endif

    GET_TID r6

// Setup SGP value
//
    r4 = #SUPER_WORLD_SIZE
    r4 = mpyi (r6, r4)              // r4 - Offset in bytes 

    LOAD32(r5, SuperWorldData)
    r5 = add (r5, r4)
    sgp = r5    

	r5 = #0
	chicken = r5;      

//    call    thread_start
    jump    .


#define _R0100   0
#define _R0302   8
#define _R0504  16
#define _R0706  24
#define _R0908  32
#define _RGOSP  40
#define _RGSR   44
#define _RFLAGS 48

#define GSR_USR 31
#define GSR_IE  30


exc_tlbmiss_X:

// save registers
// p0-p3, r0-r3
//
    crswap (r10, sgp)  
    { 
        r0 = p3:0         
        memd (r10 + #_R0100) = r1:0
    }    
    memd (r10 + #_R0302) = r3:2
    memd (r10 + #_R0504) = r5:4
    memd (r10 + #_R0706) = r7:6
    memd (r10 + #_R0908) = r9:8
    r1 = elr
    jump    exc_tlb_miss_common




exc_tlbmiss_RW:
    crswap (r10, sgp)
    { 
        r0 = p3:0         
        memd (r10 + #_R0100) = r1:0
    }
    memd (r10 + #_R0302) = r3:2
    memd (r10 + #_R0504) = r5:4
    memd (r10 + #_R0706) = r7:6
    memd (r10 + #_R0908) = r9:8
    r1 = badva;




// r1 is fault address
//
exc_tlb_miss_common:
	r8 = elr

// Process statistic
//
    LOAD32(r3, tlb_miss_count)
    r6 = memw(r3)
    r6 = add (r6, #1)
    memw(r3) = r6

    GET_TID	r6

#if 0
    LOAD32(r3, L1PageTables)
    r4 = #4096
    r4 = mpyi (r6, r4)          // each L1 is 4096 bytes       
    r3 = add (r3, r4)        // get L1 page table base for thread
#else

    LOAD32(r3, L1FETCH_ADDRESS);
    r3 += asl (r6, #12)		// r2 = L1FETCH_ADDRESS + TID * 0x1000

#endif    
       
    r5 = extractu (r1, #10, #22)    // L1: r5 = index in L1 page table table
    r3 = addasl (r3, r5, #2)        

    r3 = memw (r3)                  // r3 = entry from L1 table

    r5 = extractu (r3, #3, #0)      // get type from L1 entry  
    p0 = cmp.eq (r5, #__HVM_PDE_S_INVALID)  
    if p0 jump exc_tlb_miss_invalid


// Only one level for 4M and 16M entries
//
    p0 = cmp.eq (r5, #__HVM_PDE_S_4MB)  
    if p0 jump exc_tlb_miss_process
    p0 = cmp.eq (r5, #__HVM_PDE_S_16MB)  
    if p0 jump exc_tlb_miss_process
    

// L2 table fetch:
// map L2 page table according to L1 entry
// we assume that L2 tables are ALWAYS aligned to 4096 bytes
// r3 - L1 entry
//
    r2 = extractu (r3, #20, #12)
    LOAD32(r4, L2FETCH_TLB_LO)
    r4 = insert (r2, #20, #0)      // insert real PA address

    LOAD32(r3, L2FETCH_TLB_HI)
    r2 = #TLBUSG_L2FETCH

    tlbhi = r3
    tlblo = r4
    tlbidx = r2
    tlbw
    isync

    r7 = extractu (r1, #10, #12)    // L2 index
    LOAD32(r4, L2FETCH_ADDRESS)
    r3 = addasl (r4, r7, #2)
    r3 = memw (r3)                  // r3 = entry from L2 table

/*
    r2 = r5
    r1 = r4
    r0 = r3
    call excpt_error
    jump    .
*/


// registers usage:
// r1 - tlbmiss VA address
// r3 - HVM page table entry (L1 or L2, both have same format)
// r5 - HVM entry type  
// r6 - HW Thread ID [0..5]
//
exc_tlb_miss_process:

// Update TLB counter
//
    LOAD32(r7, tlb_last_index)
    r2 = memw(r7)

    {
        p0 = cmp.gt (r2, #TLBUSG_REPLACE_MAX)    // MAX
        if !p0.new r2 = add (r2, #1)
        if (p0.new) r2 = #TLBUSG_REPLACE_MIN    // MIN
    }
    memw(r7) = r2


// Make address mask:
// 0xFFFFFFFF << (12 + 2 * HWVal)
//
    r4 = asl(r5, #1)            // *2
    r4 = add(r4, #12)           // +12
    r7 = #-1                    // r2 = 0xFFFFFFFF
    r7 = asl(r7, r4)            // r7 - address mask like 0xfffff000 for 4K 


// Make TLB HI entry
//        
    r1 = and (r1, r7)           // apply mask to VA
    r4 = lsr (r1, #12)          // >> 12


// CotullaTODO: handler Global bit here?

    r4 = setbit(r4, #TLB_HI_BIT_VALID)
    r4 = insert (r6, #6, #20)   // ASID = HWthreadID    

    
// Make TLB LO entry
// we need to take from HVM page table entry:
// PA, XWR, Cache, UserMode, 


// Put PA address
    r1 = and (r3, r7)           // apply mask to HVM entry 
    r1 = lsr (r1, #12)          // >> 12
    

// Map U-XWR from HVM to native TLB format
    r7 = extractu (r3, #1, #__HVM_PTE_R_BIT)   
    r1 = insert (r7, #1, #TLB_LO_BIT_R)

    r7 = extractu (r3, #1, #__HVM_PTE_W_BIT)   
    r1 = insert (r7, #1, #TLB_LO_BIT_W)

    r7 = extractu (r3, #1, #__HVM_PTE_X_BIT)   
    r1 = insert (r7, #1, #TLB_LO_BIT_X)

    p0 = tstbit (r3, #__HVM_PTE_U_BIT)    
    r7 = mux (p0, #0, #1)
    r1 = insert (r7, #1, #TLB_LO_BIT_SUPER)


// Put cache bits
    r6 = extractu (r3, #3, #__HVM_PTE_C_BIT)    
    r1 = insert (r6, #3, #TLB_LO_BIT_CACHE)


// Put size field
    r1 = insert (r5, #3, #TLB_LO_BIT_SIZE)


/*
    r0 = r1
    r1 = r4
    call excpt_error
    jump    .
*/


    tlbhi = r4      // VA
    tlblo = r1      // PA
    tlbidx = r2
    tlbw
    isync        

// TEST
//    jump exc_tlb_miss_invalid

// return code
//
    p3:0  = r0
    r1:0  = memd (r10 + #_R0100)
    r3:2  = memd (r10 + #_R0302)
    r5:4  = memd (r10 + #_R0504)
    r7:6  = memd (r10 + #_R0706)
    r9:8  = memd (r10 + #_R0908)
    crswap (r10, sgp)
    rte


   

exc_tlb_miss_invalid:
//    call excpt_error
    LOAD32(r29, DebugStack)
    r0 = elr
    r1 = badva
    r2 = r31    
//    r2 = r3
    r3 = r5
    r4 = r6
    call debug_tlbmiss_invalid

    jump    .

#define EXCEPTION_ENTER_HEAD \
    crswap (r10, sgp);\
    { \
        r0 = p3:0 ; \
        memd (r10 + #_R0100) = r1:0; \
    } \
	/*Interrupts are not enabled while in EX mode*/ \
	r1=ssr; \
	p0 = tstbit(r1,#SSR_BIT_IE); \
	/*Save flags*/ \
	memw(r10 + #_RFLAGS) = r0; \
\
	/*set the usr mode bit and interupt enable bit in _RGSR */ \
	r0 = #0; \
	if(!p0) jump 1f; \
	r0 = setbit(r0,#GSR_IE); \
1: \
	p0 = tstbit(r1,#SSR_BIT_USR); \

exc_int:
 	EXCEPTION_ENTER_HEAD;
	if(!p0) jump 1f 
		//If usermode switch to kernel stack, else borrow stack in r29
		r1 = memw(r10 + #_RGOSP);
		{ r1 = r29; r29 = r1; }
		memw(r10 + #_RGOSP) = r1; 
		r0 = setbit(r0,#GSR_USR)
1:
	memw(r10 + #_RGSR) = r0;
	
	//Restore r0,r10
	r1:0 = memd(r10+#_R0100);
	crswap (r10, sgp)

	jump _K_enter_interrupt

.global int_debug
int_debug:
    LOAD32(r29, DebugStack)
    call debug_intr_out
    jump  .

exc_trap:
	EXCEPTION_ENTER_HEAD;
	if(!p0) jump 1f
	r0 = setbit(r0,#GSR_IE)
1:

	p0 = tstbit(r1,#SSR_BIT_USR);
	if(!p0) jump 1f 
	r0 = setbit(r0,#GSR_USR)
1:
	memw(r10 + #_RGSR) = r0;

	//musical chairs with stack pointer
	r0 = memw(r10 + #_RGOSP);
	{ r0 = r29; r29 = r0; }
	memw(r10 + #_RGOSP) = r0;
	
	//Restore r0,r10
	r1:0 = memd(r10+#_R0100);
	crswap (r10, sgp)

	jump _K_enter_trap0

// ret in r0,r1,r2,r3,r4 only r31,r5 can be clobbered!
.global coresys_getregs
coresys_getregs:
    crswap (r10, sgp)
	r0 = elr;
	r1 = memw(r10+#_RGSR);
	r2 = memw(r10+#_RGOSP);
	r3 = badva;
	r4 = memw(r10+#_RFLAGS);
	//Restore
    crswap (r10, sgp)
	jumpr lr

// r0,r1,r2,r3,r4 arguments, all registers up to 29 safe to clobber
.global coresys_setregs
coresys_setregs:
//interrupts and traps must be disabled here, this state is only valid one per core
	crswap (r10, sgp)
	elr = r0
	memw(r10 + #_RGSR) = r1;
	memw(r10 + #_RGOSP) = r2;
	badva = r3
	memw(r10 + #_RFLAGS) = r4;

	//Restore
    crswap (r10, sgp)
	jumpr lr

// r29 stack, must restore to gosp
.global coresys_rte
coresys_rte:
	crswap (r10, sgp)
	memd (r10 + #_R0100) = r1:0
	memd (r10 + #_R0302) = r3:2

//TODO: do this unless this is a kmode interrupt return
//	r0 = memw(r10 + #_RGOSP);
//	memw(r10 + #_RGOSP) = r29;
//	{ r0 = r29; r29 = r0; }

//deal with gsr
//TODO: needs to be optimized and actually work so bits can be cleared
	r0 = p3:0
	r1 = memw(r10 + #_RGSR);
	r2 = ssr;
	p0 = tstbit(r1,#GSR_USR);
	if(!p0) jump 1f 
	r2 = setbit(r2,#SSR_BIT_USR)
1:
	p0 = tstbit(r1,#GSR_IE);
	if(!p0) jump 1f
	r2 = setbit(r2,#SSR_BIT_IE)
1:
	ssr=r2;
	
	//Restore r0,r10,flags
	r0 = memw(r10+#_RFLAGS);
	p3:0 = r0
	r3:2 = memd(r10+#_R0302);
	r1:0 = memd(r10+#_R0100);
    crswap (r10, sgp)
	rte

.global foo
foo:
	jumpr r31

///////////////////////////////////////////////////////////////////////
//    D A T A      D E C L A R A T I O N S 
///////////////////////////////////////////////////////////////////////
//
// Data area for each thread here (stored in SGP)
// 
    
    .globl SuperWorldData
    .p2align 4  // Align to 16 bytes (some places use access by 8 bytes)
SuperWorldData:
    .fill (HW_THREADS * SUPER_WORLD_SIZE), 1, 0


//
// physical addresses of L1 page tables for each thread
// 

    .globl L1PageTables
L1PageTables:
    .fill (HW_THREADS * 4), 1, 0

//
// Exceptions debug stack 
//
    .p2align 2     // Align to 8 bytes
    .globl DebugStack
DebugStack:
    .fill (512), 1, 0



// kernel L1 PTE - 1024 entries, each describes 4M
// must be aligned to 4096 bytes
//
// linux generic mm code rely to that global variable
// it's used as init_mm.pgd value
//
    .p2align 12
    .globl swapper_pg_dir
swapper_pg_dir:
    .fill (4 * 1024), 1, 0


ENTRY(_SW_MMU_END)
    


// END OF FILE
