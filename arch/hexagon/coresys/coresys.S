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



    .macro TLB_ENTRY_SET index, regl, regh
        tlbhi = \regh
        tlblo = \regl
        tlbidx = \index
        tlbw
        isync        
    .endm


#define LOAD32(reg, value)    \
        reg.h = #HI(value);    \
        reg.l = #LO(value)





#define HW_THREADS          6
#define L1_PAGETABLE_SIZE   4096
#define SUPER_WORLD_SIZE    128


#define L2FETCH_ADDRESS     0xF0000000
#define L2FETCH_TLB_HI      TLB_MAKE_HI(TLB_ADDR(L2FETCH_ADDRESS), 1, 0)  // global = 1, ASID = 0
#define L2FETCH_TLB_LO      TLB_MAKE_LO(0, TLB_SIZE_4K, TLB_UC, TLB_R) // without actual PA address


	__CPUINIT



ENTRY(_SW_MMU_START)

    .ascii  "Q6SM"      // signature


// this global variable holds last changed TLB index
// during TLBMiss operation
//
tlb_last_index: .word   TLBUSG_REPLACE_MIN

tlb_miss_count: .word   0



    .globl get_miss_count
get_miss_count:
    LOAD32(r0, tlb_miss_count)
    r0 = memw (r0)
    jumpr r31


handle_vmnewmap:
    r2 = memw(r1)
    memw(r0) = r2
    
    jumpr r31
    



handle_vmclrmap:
    jumpr r31


// coresys initilization function
// must be runned once on thread #0
// setup exception vectors
// init supervisor global pointer register
//
    .globl coresys_init
coresys_init:
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


    LOAD32(r0, L1PageTables)
    r3 = #((HW_THREADS * L1_PAGETABLE_SIZE) / 4)
    loop0(2f, r3)
2:
    {
	memw(r0 ++ #4) = r1
    }:endloop0


// Get Thread ID
//
    r4 = ssr
    r6 = extractu (r4, #3, #19)     // r6 = Thread ID [0..5]

// Setup SGP value
//
    r4 = #SUPER_WORLD_SIZE
    r4 = mpyi (r6, r4)              // r4 - Offset in bytes 

    LOAD32(r5, SuperWorldData)
    r5 = add (r5, r4)
    sgp = r5          

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
exc_trap:
exc_reserved:
exc_int:
//    jump handle_error_exception
// Debug error code which prints information about exception
// 
#if 1
    LOAD32(r29, DebugStack)
    r0 = elr
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

// Get Thread ID
//
    r4 = ssr
    r6 = extractu (r4, #3, #19)     // r6 = Thread ID [0..5]

// Setup SGP value
//
    r4 = #SUPER_WORLD_SIZE
    r4 = mpyi (r6, r4)              // r4 - Offset in bytes 

    LOAD32(r5, SuperWorldData)
    r5 = add (r5, r4)
    sgp = r5          

//    call    thread_start
    jump    .






exc_tlbmiss_X:

// save registers
// p0-p3, r0-r3
//
    crswap (r10, sgp)  
    { 
        r0 = p3:0         
        memd (r10 + #0) = r1:0
    }    
    memd (r10 + #8) = r3:2
    memd (r10 + #16) = r5:4
    memd (r10 + #24) = r7:6
//    memd (r10 + #32) = r9:8
    r1 = elr
    jump    exc_tlb_miss_common




exc_tlbmiss_RW:
    crswap (r10, sgp)
    { 
        r0 = p3:0         
        memd (r10 + #0) = r1:0
    }
    memd (r10 + #8) = r3:2
    memd (r10 + #16) = r5:4
    memd (r10 + #24) = r7:6
//    memd (r10 + #32) = r9:8
    r1 = badva;




// r1 is fault address
//
exc_tlb_miss_common:


// Process statistic
//
    LOAD32(r3, tlb_miss_count)
    r6 = memw(r3)
    r6 = add (r6, #1)
    memw(r3) = r6



// Get Thread ID
//
    r4 = ssr
    r6 = extractu (r4, #3, #19)     // r6 = Thread ID [0..5]


    LOAD32(r3, L1PageTables)
    r4 = #4096
    r4 = mpyi (r6, r4)          // each L1 is 4096 bytes       
    r3 = add (r3, r4)        // get L1 page table base for thread

       
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
    r6 = extractu (r3, #20, #12)
    LOAD32(r4, L2FETCH_TLB_LO)
    r4 = insert (r6, #20, #0)      // insert real PA address

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


// return code
//
    p3:0  = r0
    r1:0  = memd (r10 + #0)
    r3:2  = memd (r10 + #8)
    r5:4  = memd (r10 + #16)
    r7:6  = memd (r10 + #24)
//    r9:8  = memd (r10 + #32)
    crswap (r10, sgp)
    rte


   

exc_tlb_miss_invalid:
//    call excpt_error
    jump    .


////////////////////////////////////////////////////////////////////////////////
//
// Data area for each thread here (stored in SGP)
// 
    
    .globl SuperWorldData
    .p2align 4  // Align to 16 bytes (some places use access by 8 bytes)
SuperWorldData:
    .fill (HW_THREADS * SUPER_WORLD_SIZE), 1, 0


//
// L1 page tables for each thread here
// 

    .p2align 12     // Align to 4096 bytes
    .globl L1PageTables
L1PageTables:
    .fill (HW_THREADS * L1_PAGETABLE_SIZE), 1, 0

//
// Exceptions debug stack 
//
    .p2align 2     // Align to 8 bytes
    .globl DebugStack
DebugStack:
    .fill (512), 1, 0



ENTRY(_SW_MMU_END)
    


// END OF FILE