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
#include <asm/hexagon_vm.h>
#include <asm/vm_mmu.h>
#include <asm/page.h>

#include "qdsp6_tlb.h"
#include "tlb_usage.h"
#include "native_defs.h"
#include "swd_regs.h"



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


	.section	".coresys.head", "ax"
    	.ascii  "Q6SM"      // signature


	.section	".coresys", "ax"


// this global variable holds last changed TLB index
// during TLBMiss operation
//
.global tlb_last_index
tlb_last_index: .word   TLBUSG_REPLACE_MIN

tlb_miss_count: .word   0

.global tlb_debug_log
tlb_debug_log:  .word   0

.global last_exc_ssr
last_exc_ssr:  .word   0


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


    	
    GET_TID r6

    // Setup SGP value
    //
    r4 = #SUPER_WORLD_SIZE
    r4 = mpyi (r6, r4)              // r4 - Offset in bytes 

    LOAD32(r5, SuperWorldData)
    r5 = add (r5, r4)
    sgp = r5          


    // change mode to USER
    // SSR[EXC] = 1 SSR[USR] = 1
    //
    r1 = ssr
    r1 = clrbit(r1, #SSR_BIT_IE)
    r1 = setbit(r1, #SSR_BIT_USR)
    r1 = setbit(r1, #SSR_BIT_EXC)
    ssr = r1	


    // return from exception
    // SSR[EXC] = 0, activates user mode
    // 
    elr = r31
    rte



// function for debug purposes
//
ENTRY(get_miss_count)
    LOAD32(r0, tlb_miss_count)
    r0 = memw (r0)
    jumpr r31



// This function must not use stack
// because called from trap1 handler directly
//
ENTRY(coresys_clear_tlb_replace)
// clear replacement tlb entries
    r0 = #TLBUSG_REPLACE_MIN
    r2 = #0
.cs_tlb_clear_lp:
    p0 = cmp.gt (r0, #TLBUSG_REPLACE_MAX)
    if p0 jump .cs_tlb_clear_exit

    TLB_ENTRY_SET r0, r2, r2 // idx, lo, hi

    { 
	r0 = add (r0, #1)
        jump .cs_tlb_clear_lp 
    }

.cs_tlb_clear_exit:
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


ENTRY(coresys_user_test)
    r0 = ssr
    r1 = #1 
    r0 = insert (r1, #3, #16)
    r0 = #0
//    ssr = r0

    LOAD32(r0, 0xF1000000)	// +10
    r1 = memw(r0)               // +18
    memw(r0) = r3		// +1C


// TLB entry S=0, G=1
//
// User mode without RTE, TLB_RWX - no fault
// User mode without RTE, TLB_R   - read OK, write FAIL, SSR=C30023
// User mode without RTE, TLB_WX  - write OK, read FAIL, SSR=C30022
//
// TLB entry S=1, G=1
//
// User mode without RTE, TLB_R   - read OK, write FAIL, SSR=C30023 
// Supermode without RTE, TLB_R   - no fault
//
// TLB entry S=0, G=1
// Supermode without RTE, TLB_R   - no fault
//
// TLB entry S=1, G=1
// Supermode without RTE, TLB_R   - 
//

    jump .

    LOAD32(r0, user_jump)
    elr = r0
    rte
user_jump:
    r0 = ssr
    jumpr r31




//
// Exception vectors 
//
    .p2align 12
exc_vectors:
    jump exc_reset
    jump exc_nmi
    jump exc_error2
    jump exc_error2
    jump exc_tlbmiss_X
    jump exc_reserved
    jump exc_tlbmiss_RW
    jump exc_reserved
    jump exc_trap0
    jump exc_trap1
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


exc_error:
exc_reserved:
//    jump handle_error_exception
// Debug error code which prints information about exception
// 
#if 1
    LOAD32(r29, DebugStack)
    r0 = elr
    r1 = badva
    r2 = r31
    LOAD32(r3,debug_error_out)
    callr r3
#endif
    jump    .



exc_test:
    LOAD32(r29, DebugStack)
    r0 = elr
    r1 = badva
    r2 = r31
    LOAD32(r3,debug_test_out)
    callr r3
    jump    .


// called when HW thread core started by start (r0) command
//
exc_reset:

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



#if 1
// old jonpry code

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


    //Rewrite the ssr cause field to store that this was an execute fault
    r2 = ssr
    r1 = #3
    r2 = insert(r1,#8,#0)
    ssr = r2

    //This fault could be do to an instruction packet crossing a page boundry
    //In that case ELR will be wrong. This may not be the correct place to do this as 
    //we will need to acquire the SMP lock to do this work

    //Elr is the initial fault address. Elr always points to the beginning of a packet
    //So there are no worries so long as the packet is more than 12 bytes from the page boundary
    r1 = elr
    r2 = #0xfff
    r3 = and(r1,r2)
    r2 = #0xff0
    p0 = cmp.gt(r3,r2)
    if(!p0) jump    exc_tlb_miss_common

    //At this point, this could be a double faulting instruction
    //Check this by seeing if tlbp picks up anything
    r2 = elr

    // Make TLB HI entry
    //TODO: add ASID
    r2 = lsr (r2, #12)          // >> 12
    tlbhi = r2
    tlbp
    r3 = tlbidx
    //Tlbp will set the high bit if there is currently no entry
    //TODO: even if we get a valid index, we must check that that TLB_LO
    //has X permission, and if this is a usermode fault, that the entry
    //has user mode permissions
    p0 = tstbit(r3,#31)	
    if(p0) jump    exc_tlb_miss_common
	
    //Now we need to round up the badva
    r2 = add(r2,#1)
    r1 = asl(r2,#12)
	
    jump    exc_tlb_miss_common

// end of old jonpry code
#else
// new, more easy way

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
    r2 = ssr
    p0 = tstbit (r2, #1)
    if (p0) r1 = add(r1, #(4 * 4))


    // SSR[CAUSE] = 3 to report it as an execute fault
    r3 = #3
    r2 = insert(r3, #8, #SSR_BIT_CAUSE)
    ssr = r2

    jump    exc_tlb_miss_common


#endif


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

// uncomment to have a log of TLB miss calls
//
#if 0
    LOAD32(r3, DebugLog)  
    LOAD32(r4, tlb_debug_log)
    r2 = memw(r4)
    r3 += asl(r2, #4)

    r5 = ssr
    memw(r3) = r1
    memw(r3 + #4) = r31  
    memw(r3 + #8) = r5  
    memw(r3 + #12) = r8  
  
    r2 = add (r2, #1)
    memw(r4) = r2

#endif


    GET_TID	r6

    LOAD32(r3, L1FETCH_ADDRESS);
    r3 += asl (r6, #12)		// r2 = L1FETCH_ADDRESS + TID * 0x1000

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

// Check bit field layout here
#if __HVM_PTE_W_BIT != __HVM_PTE_R_BIT + 1
#error Wrong bit definitions W
#endif
#if __HVM_PTE_X_BIT != __HVM_PTE_R_BIT + 2
#error Wrong bit definitions X
#endif

    // extract RWX
    r7 = extractu (r3, #3, #__HVM_PTE_R_BIT)

    // if all RWX are zero this is invalid/empty L2 entry 
    // call fault handler
    p0 = cmp.eq (r7, #0)
    if p0 jump exc_tlb_miss_invalid

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
        p0 = cmp.ge (r2, #TLBUSG_REPLACE_MAX)    // MAX
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

    tlbhi = r4      // VA
    tlblo = r1      // PA
    tlbidx = r2
    tlbw
    isync        


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





exc_nmi:
// path to dump current state 
//
    LOAD32(r29, DebugStack)
    r0 = elr
    r1 = badva
    r2 = r31
    LOAD32(r3,debug_error_out)
    callr r3
    jump    .





// called if TLB present but protection error
//
exc_error2:
#if 0
// fatal error path
//
    LOAD32(r29, DebugStack)
    r0 = elr
    r1 = badva
    r2 = r31
    LOAD32(r3,debug_error_out)
    callr r3
    jump    .
#endif

    jump exc_fault  

    


   
// called if L1 or L2 page table walk failed
//
exc_tlb_miss_invalid:

#if 0
//    call excpt_error
    LOAD32(r29, DebugStack)
    r0 = elr
    r1 = badva
    r2 = r31    
//    r2 = r3
    r3 = r5
    r4 = r6
    LOAD32(r5,debug_tlbmiss_invalid)
    callr r5
    jump .
#endif

   // linux exception handle code 
   // assumes that badva contains fault address
   // but for tlbmissX fault address IS in ELR
   // so we fix it here
   //
   badva = r1


   r2 = ssr
   r2 = and (r2, #3)  
   p0 = cmp.eq (r2, #1)
   p1 = cmp.eq (r2, #2)
   p3 = cmp.eq (r2, #3)
   p2 = or (p0, p1)

   r3 = #HVM_GE_C_RPROT
   if p2 r3 = #HVM_GE_C_WPROT
   if p3 r3 = #HVM_GE_C_XPROT


   // we are replacing cause field in SSR to emulate 
   // HVM behaviour, it will be copied to GSR later
   //
   r1 = ssr
   r1 = insert (r3, #8, #SSR_BIT_CAUSE)
   ssr = r1
    
// restore saved regs for tlbmiss handler 
// and jump to linux exception handler
//
    p3:0  = r0
    r1:0  = memd (r10 + #_R0100)
    r3:2  = memd (r10 + #_R0302)
    r5:4  = memd (r10 + #_R0504)
    r7:6  = memd (r10 + #_R0706)
    r9:8  = memd (r10 + #_R0908)
    crswap (r10, sgp)

    jump exc_fault  






    .macro EXCEPTION_ENTER_HEAD 
        crswap (r10, sgp);
        { 
           r0 = p3:0 ; 
           memd (r10 + #_R0100) = r1:0; 
        } 
	/*Interrupts are not enabled while in EX mode*/ 
	/*Save flags*/ 
	memw(r10 + #_RFLAGS) = r0; 
		
	/*set the usr mode bit and interupt enable bit in _RGSR */ 
	r0 = #0; // r0 holds GSR

#if 1
	// langpoo's way is one way
	r1 = ssr; 
	r1 = extractu (r1, #1, #SSR_BIT_IE)
	r0 = insert (r1, #1, #GSR_IE)
	                       	
	/* low 8 bits is cause field */
	r1 = ssr
	r1 = extractu (r1, #8, #SSR_BIT_CAUSE)
	r0 = insert (r1, #16, #GSR_CAUSE) // HVM_VMEST_CAUSE_MSK = 0xFFFF

#else         	
	// but jonpry's classic way is here!
	r1 = ssr
	p0 = tstbit(r1, #SSR_BIT_IE)
	if (!p0) jump 1f
		r0 = setbit(r0, #GSR_IE)
1:
	
#endif	
	r1 = ssr
	p0 = tstbit(r1,#SSR_BIT_USR); 
	r1 = r29; 
	if(!p0) jump 1f;

		/*If usermode switch to kernel stack, else borrow stack in r29*/ 
		r1 = memw(r10 + #_RGOSP);
		{ r1 = r29; r29 = r1; }
		r0 = setbit(r0,#GSR_USR);
1:
	memw(r10 + #_RGOSP) = r1; 
	memw(r10 + #_RGSR) = r0;
	r0 = elr
	memw(r10 + #_RGELR) = r0;
	r0 = badva
	memw(r10 + #_RGBADVA) = r0;

	/* disable interrupts and exception mode
	// before calling exception handler
	// not we need also clear USR bit 
	// otherwise USR=1 EXC=0 IE=0 will cause SSR access fault
	*/

	r0 = ssr
	r0 = clrbit(r0,#SSR_BIT_IE)
	r0 = clrbit(r0,#SSR_BIT_USR)
	ssr = r0
	isync

	//Check the fault guard, and then set the guard
	r0 = memw(r10+#_RGUARD)
	p0 = cmp.ge(r0,#1)
	if(p0) jump guard_debug
	LOAD32 (r0, last_exc_ssr)
	r1 = ssr
	memw (r0) = r1
	r0 = #1
	memw(r10+#_RGUARD) = r0;


    .endm

#define VEC_FAULT (2*4)
#define VEC_TRAP0 (5*4)
#define VEC_INT   (7*4)

exc_done:
	/*Restore r0,r10,flags*/
	r1 = memw(r10+#_RFLAGS);
	p3:0 = r1;
	r1:0 = memd(r10+#_R0100); 
	crswap (r10, sgp)
	rte

exc_fault:
//	jump exc_test
 	EXCEPTION_ENTER_HEAD;
	LOAD32(r0,coresys_gevb)
	r0 = memw(r0)
	r0 = add(r0, #VEC_FAULT)
	elr = r0
	jump exc_done

exc_int:
//	jump int_debug
 	EXCEPTION_ENTER_HEAD;
	LOAD32(r0,coresys_gevb)
	r0 = memw(r0)
	r0 = add(r0, #VEC_INT)
	elr = r0
	jump exc_done

exc_trap0:
//	jump int_debug
	EXCEPTION_ENTER_HEAD;
	LOAD32(r0,coresys_gevb)
	r0 = memw(r0)
	r0 = add(r0, #VEC_TRAP0)
	elr = r0
	jump exc_done

ENTRY(int_debug)
    LOAD32(r29, DebugStack)
    LOAD32(r3,debug_intr_out)
    callr r3
    jump  .

ENTRY(guard_debug)
    LOAD32(r29, DebugStack)
    LOAD32 (r0, last_exc_ssr)
    r0 = memw (r0)
    r0 = elr
    r1 = r29
    LOAD32(r3,debug_guard_out)
    callr r3
    jump  .

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
    .fill (512), 1, 0
DebugStack:


    .p2align 2     // Align to 8 bytes
    .globl DebugLog
DebugLog:
    .fill (4096), 1, 0


ENTRY(_SW_MMU_END)
    


// END OF FILE
