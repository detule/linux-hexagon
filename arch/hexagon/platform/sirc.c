/* 
 * Copyright (c) 2013 Cotulla
 * Copyright (c) 2008-2009, Code Aurora Forum. All rights reserved.
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
 *
 */

#include <linux/io.h>
#include <linux/irq.h>
#include <linux/interrupt.h>
#include <asm/irq.h>
#include "sirc.h"




#ifdef CONFIG_HEXAGON_ARCH_V2

// QSD8250B HTC LEO

#define MSM_SIRC_BASE			0xAB010000
#define MSM_SIRC_SIZE			0x1000


#define Q6SS_SIRC_COUNT			2


// defined as offsets from base
//
#define Q6SS_SIRC_INT_ENABLE(i)       	(0x400 * (i) + 0x00)
#define Q6SS_SIRC_INT_ENABLE_CLEAR(i)   (0x400 * (i) + 0x04)
#define Q6SS_SIRC_INT_ENABLE_SET(i)     (0x400 * (i) + 0x08)
#define Q6SS_SIRC_INT_TYPE(i)           (0x400 * (i) + 0x0C)
#define Q6SS_SIRC_INT_POLARITY(i)       (0x400 * (i) + 0x10)
#define Q6SS_SIRC_IRQ_STATUS(i)         (0x400 * (i) + 0x14)
#define Q6SS_SIRC_INT_CLEAR(i)          (0x400 * (i) + 0x18)
#define Q6SS_SIRC_SOFT_INT(i)           (0x400 * (i) + 0x1C)


// interrupt number in first level controller
//
#define Q6SS_SIRC_L1_INTR(i)	      	(23 + i) 


#else



#define MSM_SIRC_BASE			0x28890000
#define MSM_SIRC_SIZE			0x1000


#define Q6SS_SIRC_COUNT			8


// defined as offsets from base
// TODO: check it
//
#define Q6SS_SIRC_INT_ENABLE(i)       	(0x100 + (i) * 4)
#define Q6SS_SIRC_INT_ENABLE_CLEAR(i)   (0x180 + (i) * 4)
#define Q6SS_SIRC_INT_ENABLE_SET(i)     (0x200 + (i) * 4)
#define Q6SS_SIRC_INT_TYPE(i)           (0x280 + (i) * 4)
#define Q6SS_SIRC_INT_POLARITY(i)       (0x300 + (i) * 4)
#define Q6SS_SIRC_IRQ_STATUS(i)         (0x380 + (i) * 4)
#define Q6SS_SIRC_INT_CLEAR(i)          (0x400 + (i) * 4)
#define Q6SS_SIRC_SOFT_INT(i)           (0x480 + (i) * 4)


// interrupt number in first level controller
//
// TODO: what number should be here?
#define Q6SS_SIRC_L1_INTR(i)	      	(23 + i) 
#error SIRC code is not present 


#endif



#if 1
#define DBG(x...) printk("[SINT] "x)
#else
#define DBG(x...) do{}while(0)
#endif


struct sirc_regs_t 
{
	void    *int_enable;
	void    *int_enable_clear;
	void    *int_enable_set;
	void    *int_type;
	void    *int_polarity;
	void    *int_clear;

	void    *int_status;
	unsigned int cascade_irq;
};



static u8* sirc_base;
static unsigned int int_enable;
static unsigned int wake_enable;
static struct sirc_regs_t sirc_regs[Q6SS_SIRC_COUNT];

u32* hsusb_base;


static int sirc_get_regs_and_num(struct irq_data *d, struct sirc_regs_t **ptr, unsigned int *mask)
{
	int i, offset;

	if (d->irq < FIRST_SIRC_IRQ || d->irq >= LAST_SIRC_IRQ)
	{
		printk("ERROR: wrong SIRC number %d\n", d->irq);
		return -1;
	}

	offset = d->irq - FIRST_SIRC_IRQ;
	i = offset / 32;

	if (i >= Q6SS_SIRC_COUNT)
	{
		printk("ERROR: wrong SIRC number2 %d\n", d->irq);
		return -1;
	}

	*ptr = &sirc_regs[i];
	*mask = 1 << (offset % 32);	
	return 0;
}
 

/* Mask off the given interrupt. Keep the int_enable mask in sync with
   the enable reg, so it can be restored after power collapse. */
static void sirc_irq_mask(struct irq_data *d)
{
	unsigned int mask;
	struct sirc_regs_t *ptr = NULL;

	DBG("mask %d\n", d->irq);
	if (sirc_get_regs_and_num(d, &ptr, &mask)) return;
	
	iowrite32(mask, ptr->int_enable_clear);
	int_enable &= ~mask;
	return;
}

/* Unmask the given interrupt. Keep the int_enable mask in sync with
   the enable reg, so it can be restored after power collapse. */
static void sirc_irq_unmask(struct irq_data *d)
{
	unsigned int mask;
	struct sirc_regs_t *ptr = NULL;

	DBG("unmask %d\n", d->irq);
	if (sirc_get_regs_and_num(d, &ptr, &mask)) return;
	DBG("unmask %X %X\n", (u32)mask, (u32)ptr->int_enable_set);

	iowrite32(mask, ptr->int_enable_set);
	int_enable |= mask;
	return;
}

static void sirc_irq_ack(struct irq_data *d)
{
	unsigned int mask;
	struct sirc_regs_t *ptr = NULL;

	DBG("ack %d\n", d->irq);
	if (sirc_get_regs_and_num(d, &ptr, &mask)) return;

	iowrite32(mask, ptr->int_clear);
	return;
}

static int sirc_irq_set_wake(struct irq_data *d, unsigned int on)
{
	unsigned int mask;
	struct sirc_regs_t *ptr = NULL;


	if (sirc_get_regs_and_num(d, &ptr, &mask)) return 0;

	/* Used to set the interrupt enable mask during power collapse. */
	if (on)
		wake_enable |= mask;
	else
		wake_enable &= ~mask;

	return 0;
}

static int sirc_irq_set_type(struct irq_data *d, unsigned int flow_type)
{
	unsigned int mask;
	unsigned int val;
	struct sirc_regs_t *ptr = NULL;


	DBG("set_type %d %X\n", d->irq, flow_type);
	if (sirc_get_regs_and_num(d, &ptr, &mask)) return 0;

	val = ioread32(ptr->int_polarity);

	if (flow_type & (IRQF_TRIGGER_LOW | IRQF_TRIGGER_FALLING))
		val |= mask;
	else
		val &= ~mask;

	iowrite32(val, ptr->int_polarity);

	val = ioread32(ptr->int_type);
	if (flow_type & (IRQF_TRIGGER_RISING | IRQF_TRIGGER_FALLING)) {
		val |= mask;
		__irq_set_handler_locked(d->irq, handle_edge_irq);
	} else {
		val &= ~mask;
		__irq_set_handler_locked(d->irq, handle_level_irq);
	}

	iowrite32(val, ptr->int_type);

	return 0;
}

/* Finds the pending interrupt on the passed cascade irq and redrives it */
static void sirc_irq_handler(unsigned int irq, struct irq_desc *desc)
{
	int i, offset = 0;
	unsigned int sirq;
	unsigned int status;	
	struct sirc_regs_t *ptr = NULL;

	
//	printk("SIRC IRQ %d\n", irq);
	for (i = 0; i < Q6SS_SIRC_COUNT; i++)
	{
		if (sirc_regs[i].cascade_irq == irq) 
		{
			ptr = &sirc_regs[i];
			offset = INT_Q6_SIRC_COUNT * i;
			break;
		}
	}

	if (ptr == NULL)
	{
		printk("ERROR: SIRC invalid irq in handler %d\n", irq);
		return;
	}
	
	status = ioread32(ptr->int_status);
	status &= SIRC_MASK;
	if (status == 0)
		return;

	for (sirq = 0;
	     (sirq < INT_Q6_SIRC_COUNT) && ((status & (1U << sirq)) == 0);
	     sirq++)
		;

	DBG("report %d at %d\n", sirq, offset);
	generic_handle_irq(sirq + FIRST_SIRC_IRQ + offset);

	desc->irq_data.chip->irq_ack(&desc->irq_data);
}


static struct irq_chip sirc_irq_chip = 
{
	.name          = "hexagon-sirc",
	.irq_ack       = sirc_irq_ack,
	.irq_mask      = sirc_irq_mask,
	.irq_unmask    = sirc_irq_unmask,
	.irq_set_wake  = sirc_irq_set_wake,
	.irq_set_type  = sirc_irq_set_type,
};



void dump_sirc_state(void)
{
	if (sirc_base) printk("SIRC: %08X %08X\n", ioread32(sirc_regs[1].int_enable), ioread32(sirc_regs[1].int_status));
}


void __init msm_init_sirc(void)
{
	int i;

	int_enable = 0;
	wake_enable = 0;


	printk("msm_init_sirc() enter\n");
	hsusb_base = ioremap(0xA0800000, 0x1000);

	sirc_base = ioremap(MSM_SIRC_BASE, MSM_SIRC_SIZE);
	if (!sirc_base)
	{
		printk("Can't map sirc_base\n");
		return;
	}


	printk("msm_init_sirc: %08X %08X\n", MSM_SIRC_BASE, MSM_SIRC_SIZE);
	for (i = 0; i < Q6SS_SIRC_COUNT; i++)
	{
		sirc_regs[i].int_enable       = sirc_base + Q6SS_SIRC_INT_ENABLE(i);
		sirc_regs[i].int_enable_clear = sirc_base + Q6SS_SIRC_INT_ENABLE_CLEAR(i);
		sirc_regs[i].int_enable_set   = sirc_base + Q6SS_SIRC_INT_ENABLE_SET(i);
		sirc_regs[i].int_type         = sirc_base + Q6SS_SIRC_INT_TYPE(i);
		sirc_regs[i].int_polarity     = sirc_base + Q6SS_SIRC_INT_POLARITY(i);
		sirc_regs[i].int_clear        = sirc_base + Q6SS_SIRC_INT_CLEAR(i);
		sirc_regs[i].int_status       = sirc_base + Q6SS_SIRC_IRQ_STATUS(i);
		sirc_regs[i].cascade_irq      = Q6SS_SIRC_L1_INTR(i);
	}


	for (i = FIRST_SIRC_IRQ; i < LAST_SIRC_IRQ; i++) 
	{
		irq_set_chip_and_handler(i, &sirc_irq_chip, handle_level_irq);
//		irq_set_chip_and_handler(i, &sirc_irq_chip, handle_edge_irq);
//		set_irq_flags(i, IRQF_VALID);
	}

	for (i = 0; i < Q6SS_SIRC_COUNT; i++) 
	{
		irq_set_chained_handler(sirc_regs[i].cascade_irq, sirc_irq_handler);
		irq_set_irq_wake(sirc_regs[i].cascade_irq, 1);
	}
}

