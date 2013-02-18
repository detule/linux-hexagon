//
// qdsp6_tlb.h
//
// TLB definitions for QDSP6 by Cotulla
//


#ifndef _CORESYS_TLB_H_
#define _CORESYS_TLB_H_



/*

    Valid mask | Size | L2 | HWVal
    ==============================
    
    0xfffff000 - 4K   - Y  - 0 
    0xffffc000 - 16K  - Y  - 1
    0xffff0000 - 64K  - Y  - 2
    0xfffc0000 - 256K - Y  - 3
    0xfff00000 - 1M   - Y  - 4
    0xffc00000 - 4M   - N  - 5
    0xff000000 - 16M  - N  - 6
    Invalid    -      - N  - 7


    Method to get valid mask:
        0xFFFFFFFF << (12 + 2 * HWVal)
    

    Note: L2 size always 4096 bytes. 
        For 16K, 64K, 256K, 1M it must be filled with repeated entries     
            Like for 16K size 4 entries must have same value

*/

/*


TLB entries format: each entry is 64 bit.


LO V2 format: 
    start[size] in bits

    0[20] 12[20] - PA address
    20[3] 9[3]   - page size    
    23[1] 8[1]   - super 
    24[1] 7[1]   - global
    25[1] 6[1]   - valid
    26[3] 3[3]   - cache control
    29[1] 2[1]   - read
    30[1] 1[1]   - write
    31[1] 0[1]   - execute


HI V2 format:
    start[size] in bits

    31[1]  - dirty
    30[1]  - exception
    29[1]  - valid
    28[1]  - global
    26[2]  - reserved   
    20[6]  - ASID
    0[20]  - VA address    


*/


#define TLB_SIZE_4K         0
#define TLB_SIZE_16K        1
#define TLB_SIZE_64K        2
#define TLB_SIZE_256K       3
#define TLB_SIZE_1M         4
#define TLB_SIZE_4M         5
#define TLB_SIZE_16M        6

#define TLB_L1WB_L2UC       0
#define TLB_L1WT_L2UC       1
#define TLB_L1WB_L2UC_S     2
#define TLB_L1WT_L2UC_S     3
#define TLB_UC              4
#define TLB_L1WT_L2C        5
#define TLB_UC_S            6
#define TLB_L1WB_L2C        7

#define TLB_NONE            0
#define TLB_R               1
#define TLB_W               2
#define TLB_X               4
#define TLB_RW              (TLB_R | TLB_W)
#define TLB_RX              (TLB_R | TLB_X)
#define TLB_WX              (TLB_W | TLB_X)
#define TLB_RWX             (TLB_R | TLB_W | TLB_X)




#define TLB_LO_BIT_SIZE     20

#define TLB_LO_BIT_SUPER    23

#define TLB_LO_BIT_CACHE    26

#define TLB_LO_BIT_W        29
#define TLB_LO_BIT_R        30
#define TLB_LO_BIT_X        31


#define TLB_HI_BIT_VALID    29




#define TLB_ADDR(ad)        ((ad) >> 12)


#define TLB_MAKE_LO(PA, SIZE, CACHE, RWX) \
    ((PA) | ((SIZE) << 20) | ((CACHE) << 26) | ((RWX) << 29) | ((0) << 24))

#define TLB_MAKE_HI(VA, G, ASID) \
    ((VA) | ((ASID) << 20) | ((G) << 28) | (1 << 29))




/* S or Page Size field in PDE */
#ifdef __QMAGLDR__

#define __HVM_PDE_S     (0x7 << 0)
#define __HVM_PDE_S_4KB     0
#define __HVM_PDE_S_16KB    1
#define __HVM_PDE_S_64KB    2
#define __HVM_PDE_S_256KB   3
#define __HVM_PDE_S_1MB     4
#define __HVM_PDE_S_4MB     5
#define __HVM_PDE_S_16MB    6
#define __HVM_PDE_S_INVALID 7

#endif


#endif // _CORESYS_TLB_H_
