/*

	This file defines usage of TLB entries in QDSP6
	Total amount of entries = 64

*/

// core TLB mapping.
// exception handlers located inside it
// linux kernel also located inside it
// must be never changed
//
#define TLBUSG_CORE		0


// used only during start up once
//
#define TLBUSG_INDENTITY	1


// used for debug purposes
//
#define TLBUSG_DEBUG		2


// used for debug purposes 2
//
#define TLBUSG_DEBUG2		3


// used to fetch values from L2 page tables
// VA always same, 0xF0000000, 4K mapping
//
#define TLBUSG_L2FETCH		4


// minimum TLB entry for replacement
//
#define TLBUSG_REPLACE_MIN	5


// maximum TLB entry for replacement
//
#define TLBUSG_REPLACE_MAX	63


