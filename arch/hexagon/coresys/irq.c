/* linux/arch/arm/mach-msm/irq.c
 *
 * Copyright (C) 2013 Cotulla
 * Copyright (C) 2007 Google, Inc.
 *
 * This software is licensed under the terms of the GNU General Public
 * License version 2, as published by the Free Software Foundation, and
 * may be copied, distributed, and modified under those terms.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 */

#include <linux/init.h>
#include <linux/module.h>
#include <linux/sched.h>
#include <linux/interrupt.h>
#include <linux/ptrace.h>
#include <linux/timer.h>
#include <linux/irq.h>
#include <linux/io.h>
#include <linux/ioport.h>


#if 1
#define DBG(x...) printk("[INT] "x)
#else
#define DBG(x...) do{}while(0)
#endif


// from mach-msm/SIRC.c
extern void msm_init_sirc(void);

//extern u32 coresys_int_pending(void);
//extern void __my_int_ltoggle(int state);

extern void __my_int_gtoggle(int state);
extern void __my_int_cfg(int intr, int cfg);

extern void __my_int_raise(int intr);
extern void __my_int_enable(int intr);
extern void __my_int_disable(int intr);
extern void __my_int_done(int intr);
extern void __my_int_init(void);
extern void __my_int_settype(int intr, int v);
extern void __my_int_setpol(int intr, int v);


static void mask_irq_num(unsigned int irq)
{
	__my_int_disable(irq);		
}


static void qdsp6_irq_mask(struct irq_data *d)
{                            	
	DBG("mask %d\n", d->irq);
	mask_irq_num(d->irq);
}

static void qdsp6_irq_unmask(struct irq_data *d)
{
	DBG("unmask %d\n", d->irq);
	__my_int_enable(d->irq);
}

static void qdsp6_irq_ack(struct irq_data *d)
{
	if (d->irq != 3) DBG("done %d\n", d->irq);
	__my_int_done(d->irq);
}


static int qdsp6_irq_set_type(struct irq_data *d, unsigned int flow_type)
{
	int vidx = (d->irq & 31);
	
	DBG("set_type: %d %X\n", vidx, flow_type);
	if (flow_type & (IRQF_TRIGGER_FALLING | IRQF_TRIGGER_LOW))
	{   		
		__my_int_settype(vidx, 0);
	}
	if (flow_type & (IRQF_TRIGGER_RISING | IRQF_TRIGGER_HIGH))
	{
		__my_int_settype(vidx, 1);
	}

	if (flow_type & (IRQF_TRIGGER_RISING | IRQF_TRIGGER_FALLING)) 
	{
		__my_int_setpol(vidx, 1);
		__irq_set_handler_locked(d->irq, handle_edge_irq);
	}
	if (flow_type & (IRQF_TRIGGER_HIGH | IRQF_TRIGGER_LOW)) 
	{
		__my_int_setpol(vidx, 0);
		__irq_set_handler_locked(d->irq, handle_level_irq);
	}
	return 0;
}


/*  This is actually all we need for handle_fasteoi_irq  */
static void qdsp6_irq_eoi(struct irq_data *d)
{
	int vidx = (d->irq & 31);

	if (vidx != 3) DBG("eoi %d\n", d->irq);
	__my_int_done(vidx);
}



static int qdsp6_irq_set_wake(struct irq_data *d, unsigned int on)
{
	return -EINVAL;
}


static struct irq_chip qdsp6_irq_chip = 
{
	.name          = "hexyqdsp6",
	.irq_ack       = qdsp6_irq_ack,
	.irq_mask      = qdsp6_irq_mask,
	.irq_unmask    = qdsp6_irq_unmask,
	.irq_set_wake  = qdsp6_irq_set_wake,
	.irq_set_type  = qdsp6_irq_set_type,
	.irq_eoi       = qdsp6_irq_eoi
};


static void qdsp6_intr_test()
{
	printk("INTR test start!\n");

	iowrite32(0, (void*)0xAB000008);	// disable timer
	iowrite32(1, (void*)0xAB00000C); 	// clear timer
	iowrite32(32768, (void*)0xAB000000);	// set match
	iowrite32(3, (void*)0xAB000008);	// enable & clear on match


	printk("test 0!\n");

//	__my_int_cfg(4, 0x3F);
	__my_int_cfg(3, 0x3F);

	printk("test 000!\n");

//	__my_int_raise(4);

	printk("test 1!\n");

//	__my_int_enable(4);
	__my_int_enable(3);

	printk("test 2!\n");

//	__my_int_ltoggle(1);

	printk("test 3!\n");

	__my_int_gtoggle(1); 
       
	printk("INTR test done!\n");
	while (1);
}

/**
 * The hexagon core comes with a first-level interrupt controller
 * with 32 total possible interrupts.  
 */
void __init init_IRQ(void)
{
	int irq;


	printk("+init_IRQ()\n");
	__my_int_init();

	for (irq = 0; irq < HEXAGON_CPUINTS; irq++) 
	{
		mask_irq_num(irq);         	
		__my_int_cfg(irq, 0x3F);

		irq_set_chip_and_handler(irq, &qdsp6_irq_chip, handle_fasteoi_irq);
//		irq_set_chip_and_handler(irq, &qdsp6_irq_chip, handle_level_irq);
//		set_irq_flags(irq, IRQF_VALID); // Do we need that?
	}                  

#ifdef CONFIG_HEXAGON_ARCH_V2
	msm_init_sirc();
#endif
    	

//	qdsp6_intr_test();	
	__my_int_gtoggle(1); 

	printk("-init_IRQ()\n");
}
