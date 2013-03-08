/*

	Some definitions for QDSP6

	Cotulla 2013

*/


// SSR defines
//

// TODO: V2 values. V4 is same?
#define SSR_BIT_IE	18

#define SSR_BIT_EXC	17

#define SSR_BIT_USR 	16

#define SSR_BIT_CAUSE	0


// we hold linux kernel/user mode flag as bit0 in ASID
#define SSR_BIT_ASID_USR 8
#define SSR_BIT_ASID_TID 9

// SYSCFG defines
//

#define SYSCFG_BIT_TLB	0
#define SYSCFG_GIE	4

// END OF FILE
