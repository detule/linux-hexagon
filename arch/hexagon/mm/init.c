/*
 * Memory subsystem initialization for Hexagon
 *
 * Copyright (c) 2013 Cotulla
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

#include <linux/init.h>
#include <linux/mm.h>
#include <linux/bootmem.h>
#include <asm/atomic.h>
#include <linux/highmem.h>
#include <asm/tlb.h>
#include <asm/sections.h>
#include <asm/vm_mmu.h>

#ifdef CONFIG_BLK_DEV_INITRD
#include <linux/initrd.h>
#endif


extern void my_out(const char *str, ...);
int __init scr_fb_console_init(void);



#define BOOTPARAM_SIGN		0x50423651	// 'Q6BP'


#ifndef DMA_RESERVE
#define DMA_RESERVE		(1)
#endif

#define DMA_CHUNKSIZE		(1<<22)
#define DMA_RESERVED_BYTES	(DMA_RESERVE * DMA_CHUNKSIZE)


// this defines declare physical memory 
// which can be used for Linux OS
// Note that kernel is already loaded at the start
//

#ifdef CONFIG_HEXAGON_ARCH_V2

// HTC LEO
//#define PLAT_RAM_SIZE    	(24 * 1024 * 1024)
#define PLAT_RAM_SIZE    	(20 * 1024 * 1024)

#else

// HTC TouchPad
#define PLAT_RAM_SIZE    	(36 * 1024 * 1024)


#endif





// pfn for the start of ram. start of kernel
// like 1000 0000
unsigned long bootmem_start_pfn;

// pfn  for the end of kernel
// like 1040 0000
unsigned long bootmem_free_pfn;

// pfn for the dma area start 
// like 1140 0000
unsigned long bootmem_dma_pfn;

// pfn for the end of ram.
// like 1180 0000
unsigned long bootmem_end_pfn;

// defines RAM size. can be changed by mem= cmd line
//
unsigned long platform_ram_size = PLAT_RAM_SIZE;


// this variables define DMA reserved area
//
size_t hexagon_coherent_pool_size;
unsigned long hexagon_coherent_pool_start;




/*  Set as variable to limit PMD copies  */
int max_kernel_seg = 0x303;

/*  think this should be (page_size-1) the way it's used...*/
unsigned long zero_page_mask;

/*  indicate pfn's of high memory  */
unsigned long highstart_pfn, highend_pfn;

/* struct mmu_gather defined in asm-generic.h;  */
DEFINE_PER_CPU(struct mmu_gather, mmu_gathers);

/* Default cache attribute for newly created page tables */
unsigned long _dflt_cache_att = CACHEDEF;

/*
 * The current "generation" of kernel map, which should not roll
 * over until Hell freezes over.  Actual bound in years needs to be
 * calculated to confirm.
 */
DEFINE_SPINLOCK(kmap_gen_lock);

/*  checkpatch says don't init this to 0.  */
unsigned long long kmap_generation;

/*
 * mem_init - initializes memory
 *
 * Frees up bootmem
 * Fixes up more stuff for HIGHMEM
 * Calculates and displays memory available/used
 */
void __init mem_init(void)
{
	/*  No idea where this is actually declared.  Seems to evade LXR.  */
	totalram_pages += free_all_bootmem();
	num_physpages = bootmem_end_pfn - bootmem_start_pfn;	/*  seriously, what?  */

	printk(KERN_INFO "totalram_pages = %ld\n", totalram_pages);

	/*
	 *  To-Do:  someone somewhere should wipe out the bootmem map
	 *  after we're done?
	 */

	/*
	 * This can be moved to some more virtual-memory-specific
	 * initialization hook at some point.  Set the init_mm
	 * descriptors "context" value to point to the initial
	 * kernel segment table's physical address.
	 */
	init_mm.context.ptbase = __pa(init_mm.pgd);
}

/*
 * free_initmem - frees memory used by stuff declared with __init
 *
 * Todo:  free pages between __init_begin and __init_end; possibly
 * some devtree related stuff as well.
 */
void __init_refok free_initmem(void)
{
}

static inline int free_area(unsigned long pfn, unsigned long end, char *s)
{
	unsigned int pages = 0, size = (end - pfn) << (PAGE_SHIFT - 10);

	for (; pfn < end; pfn++) {
		struct page *page = pfn_to_page(pfn);
		ClearPageReserved(page);
		init_page_count(page);
		__free_page(page);
		pages++;
	}

	if (size && s)
		printk(KERN_INFO "Freeing %s memory: %dK\n", s, size);

	return pages;
}

/*
 * free_initrd_mem - frees...  initrd memory.
 * @start - start of init memory
 * @end - end of init memory
 *
 * Apparently has to be passed the address of the initrd memory.
 *
 * Wrapped by #ifdef CONFIG_BLKDEV_INITRD
 */
void free_initrd_mem(unsigned long start, unsigned long end)
{

//	poison_init_mem((void *)start, PAGE_ALIGN(end) - start);
	totalram_pages += free_area(PFN_DOWN(__pa(start)),
				    PFN_UP(__pa(end)),
				    "initrd");
}

void sync_icache_dcache(pte_t pte)
{
	unsigned long addr;
	struct page *page;

	page = pte_page(pte);
	addr = (unsigned long) page_address(page);

	__vmcache_idsync(addr, PAGE_SIZE);
}

/*
 * In order to set up page allocator "nodes",
 * somebody has to call free_area_init() for UMA.
 *
 * In this mode, we only have one pg_data_t
 * structure: contig_mem_data.
 */
void __init paging_init(void)
{
	unsigned long zones_sizes[MAX_NR_ZONES] = {0, };

	/*
	 *  This is not particularly well documented anywhere, but
	 *  give ZONE_NORMAL all the memory, including the big holes
	 *  left by the kernel+bootmem_map which are already left as reserved
	 *  in the bootmem_map; free_area_init should see those bits and
	 *  adjust accordingly.
	 */

	zones_sizes[ZONE_NORMAL] = max_low_pfn - min_low_pfn;

	free_area_init_node(0, zones_sizes, bootmem_start_pfn, NULL);

//	free_area_init(zones_sizes);  /*  sets up the zonelists and mem_map  */

	/*
	 * Start of high memory area.  Will probably need something more
	 * fancy if we...  get more fancy.
	 */
	high_memory = (void *)PFN_PHYS(bootmem_end_pfn + 1);
}

  

/*
 * Pick out the memory size.  We look for mem=size,
 * where size is "size[KkMm]"
 */
static int __init early_mem(char *p)
{
	unsigned long size;
	char *endp;

	size = memparse(p, &endp);
	if (size < PLAT_RAM_SIZE)	
	{
		platform_ram_size = size;
	}
	return 0;
}
early_param("mem", early_mem);



extern u32 __initrd_sign;
extern u32 __initrd_start;
extern u32 __initrd_size;


void __init setup_arch_memory(void)
{
	int i, ptestart, bootmap_size;
	u32 numpte;
	u32 *pte = (u32 *) &swapper_pg_dir[0];


	if (platform_ram_size < (16 * 1024 * 1024 + DMA_RESERVED_BYTES))
	{
		my_out("RAM size must be >= 16M + 4M due huge TLB mapping and DMA reserve (%X)\r\n", platform_ram_size);
		BUG();
	}

	if (DMA_RESERVED_BYTES & ((4 * 1024 * 1024) - 1))
	{
		my_out("DMA reserved must be equal num of 4M due TLB 4M mapping\r\n");
		BUG();
	}


	// pfn for the start of ram. start of kernel
	// like 1000 0000
	bootmem_start_pfn = PFN_UP(PHYS_OFFSET);

	// pfn  for the end of kernel
	// like 1040 0000
	bootmem_free_pfn = PFN_UP(__pa((unsigned long)_end));

	// pfn for the end of ram.
	// like 1180 0000
	bootmem_end_pfn = PFN_DOWN(PHYS_OFFSET + platform_ram_size);

	// pfn for the end lowmem (DMA reserved area)
	//
	bootmem_dma_pfn = bootmem_end_pfn - PFN_DOWN(DMA_RESERVED_BYTES);


//      Memory map: 
//      |start-----------|free--------------|dma--------end|
//      |     kernel     |bootmem|          |              |
//

	hexagon_coherent_pool_size  = (size_t)DMA_RESERVED_BYTES;
	hexagon_coherent_pool_start = __va(PFN_PHYS(bootmem_dma_pfn));

	min_low_pfn = bootmem_start_pfn;
	max_low_pfn = bootmem_dma_pfn; 

	// this includes kernel, bootmemmap, but doesn't include DMA
	bootmap_size = init_bootmem_node(NODE_DATA(0), bootmem_free_pfn, bootmem_start_pfn, bootmem_dma_pfn);


	my_out("bootmem_start_pfn:  0x%08X\n", bootmem_start_pfn);
	my_out("bootmem_free_pfn:   0x%08X\n", bootmem_free_pfn);
	my_out("bootmem_dma_pfn:    0x%08X\n", bootmem_dma_pfn);
	my_out("bootmem_end_pfn:    0x%08X\n", bootmem_end_pfn);
	my_out("bootmap_size:  %d\n", bootmap_size);
	my_out("min_low_pfn:  0x%08X\n", min_low_pfn);
	my_out("max_low_pfn:  0x%08X\n", max_low_pfn);
	my_out("dma_start:  0x%08X\n", hexagon_coherent_pool_start);
	my_out("dma_size:   0x%08X\n", hexagon_coherent_pool_size);

	if (__initrd_sign == BOOTPARAM_SIGN)
	{	
		my_out("initrd_start: 0x%08X\n", __initrd_start);
		my_out("initrd_size: 0x%08X\n", __initrd_size);
	}
	else
	{
		my_out("boot params are not present %08X!\n", __initrd_sign);
	}

	//Setup the kernel > 16MB maps
	numpte = (platform_ram_size - DMA_RESERVED_BYTES - 16*1024*1024) >> 22;  // num of 4M blocks
	ptestart = (((unsigned)__va(PFN_PHYS(bootmem_start_pfn)) + 16*1024*1024) >> 22);  // start index in the page table (VA)
	for (i = 0; i < numpte; i++)
	{
		//Beginning of 4MB sections
		if(i>=numpte - numpte%4)
			pte[ptestart + i] = (((unsigned)(PFN_PHYS(bootmem_start_pfn + i) + 16*1024*1024) & __HVM_PTE_PGMASK_4MB)
				| __HVM_PTE_R | __HVM_PTE_W | __HVM_PTE_X
				| __HEXAGON_C_WB_L2 << 6 | __HVM_PDE_S_4MB);
		//16MB sections
		else
			pte[ptestart + i] = (((PFN_PHYS(bootmem_start_pfn + i) + 16*1024*1024) & __HVM_PTE_PGMASK_16MB)
				| __HVM_PTE_R | __HVM_PTE_W | __HVM_PTE_X
				| __HEXAGON_C_WB_L2 << 6 | __HVM_PDE_S_16MB);
	}	 
	
	//Setup the DMA mapping
	numpte = DMA_RESERVED_BYTES >> 22;  // num of 4M blocks
	ptestart = (hexagon_coherent_pool_start >> 22);  // start index in the page table (VA)
	for (i = 0; i < numpte; i++)
	{
		pte[ptestart + i] = ((PFN_PHYS(bootmem_dma_pfn + i) & __HVM_PTE_PGMASK_4MB)
				| __HVM_PTE_R | __HVM_PTE_W | __HVM_PTE_X
				| __HEXAGON_C_UNC << 6 | __HVM_PDE_S_4MB);
	}	        	

	my_out("numdma= %d %X %08X\n", numpte, ptestart, pte[0xC1000000 >> 22]);

        	
	// CotullaTODO: clear some parts of page table ?

	/*
	 * Free all the memory that wasn't taken up by the bootmap, the DMA
	 * reserve, or kernel itself.
	 */

	// we free only available ram memory between free+bootmapsize and dma
	// note that initial state of bootmem is reserved
	//
	free_bootmem(PFN_PHYS(bootmem_free_pfn) + bootmap_size,
		     PFN_PHYS(bootmem_dma_pfn - bootmem_free_pfn) - bootmap_size);

#ifdef CONFIG_BLK_DEV_INITRD	
	if (__initrd_sign == BOOTPARAM_SIGN && __initrd_start && __initrd_size) {
		if (__initrd_start + __initrd_size <= (max_low_pfn << PAGE_SHIFT)) {
			reserve_bootmem(__initrd_start, __initrd_size, BOOTMEM_DEFAULT);
			initrd_start = (u32)phys_to_virt(__initrd_start);
			initrd_end = initrd_start + __initrd_size;
		}
		else {
			printk(KERN_ERR
			       "initrd extends beyond end of memory (0x%08x > 0x%08lx)\n"
			       "disabling initrd\n",
			       __initrd_start + __initrd_size,
			       max_low_pfn << PAGE_SHIFT);
			__initrd_start = 0;
		}
	}
#endif


	/*
	 *  The bootmem allocator seemingly just lives to feed memory
	 *  to the paging system
	 */
	printk(KERN_INFO "PAGE_SIZE=%lu\n", PAGE_SIZE);
	paging_init();  /*  See Gorman Book, 2.3  */

	/*
	 *  At this point, the page allocator is kind of initialized, but
	 *  apparently no pages are available (just like with the bootmem
	 *  allocator), and need to be freed themselves via mem_init(),
	 *  which is called by start_kernel() later on in the process
	 */

#ifdef CONFIG_HEXAGON_ARCH_V2
// Uncomment to enable console
	scr_fb_console_init();
#endif

}
