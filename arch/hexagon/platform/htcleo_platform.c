/*
 * Board-specific setup code for HTC LEO
 *
 * Copyright (C) 2013 Cotulla
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/module.h>

#include <linux/etherdevice.h>
#include <linux/init.h>
#include <linux/linkage.h>
#include <linux/platform_device.h>
#include <linux/types.h>
#include <linux/sizes.h>
#include <linux/irq.h>

#include "msm_hsusb.h"
#include "msm_otg.h"

    
#define MSM_HSUSB_PHYS        0xA0800000
#define MSM_HSUSB_SIZE        SZ_1K

#define INT_USB_HS	      INT_Q6_USB_HS



int usb_phy_reset(void  __iomem *regs)
{
	printk("%s: %s\n", __FILE__, __func__);
	return 0;
}


static struct resource resources_otg[] = 
{
	{
		.start	= MSM_HSUSB_PHYS,
		.end	= MSM_HSUSB_PHYS + MSM_HSUSB_SIZE,
		.flags	= IORESOURCE_MEM,
	},
	{
		.start	= INT_USB_HS,
		.end	= INT_USB_HS,
		.flags	= IORESOURCE_IRQ,
	},
};


struct platform_device msm_device_otg = 
{
	.name		= "msm_otg",
	.id		= -1,
	.num_resources	= ARRAY_SIZE(resources_otg),
	.resource	= resources_otg,
	.dev		= {
		.coherent_dma_mask	= 0xffffffff,
	},
};


static struct msm_otg_platform_data msm_otg_pdata = 
{
 	 .phy_reset = usb_phy_reset,
         .pemp_level              = PRE_EMPHASIS_WITH_20_PERCENT,
         .cdr_autoreset           = CDR_AUTO_RESET_DISABLE,
         .drv_ampl                = HS_DRV_AMPLITUDE_DEFAULT,
         .se1_gating              = SE1_GATING_DISABLE,
	 .otg_mode		  = OTG_USER_CONTROL,
	 .usb_mode                = USB_PERIPHERAL_MODE
};


static struct msm_hsusb_gadget_platform_data msm_gadget_pdata = 
{
	.is_phy_status_timer_on = 1,
};


static struct resource resources_gadget_peripheral[] = {
         {
                .start  = MSM_HSUSB_PHYS,
                .end    = MSM_HSUSB_PHYS + SZ_1K - 1,
                .flags  = IORESOURCE_MEM,
         },
         {
                .start  = INT_USB_HS,
                .end    = INT_USB_HS,
                .flags  = IORESOURCE_IRQ,
         },
};

static u64 dma_mask = 0xffffffffULL;
static struct platform_device msm_device_gadget_peripheral = 
{
        .name           = "msm_hsusb",
        .id             = -1,
        .num_resources  = ARRAY_SIZE(resources_gadget_peripheral),
        .resource       = resources_gadget_peripheral,
        .dev            = {
                .dma_mask               = &dma_mask,
                .coherent_dma_mask      = 0xffffffffULL,
         },
};



static struct platform_device *devices[] __initdata = 
{
	&msm_device_otg,
	&msm_device_gadget_peripheral,

//	&msm_device_smd,
};


static int __init hexagon_init(void)
{       	
	printk("hexagon_init called\n");

	msm_device_otg.dev.platform_data = &msm_otg_pdata;
	msm_device_gadget_peripheral.dev.platform_data = &msm_gadget_pdata;

	platform_add_devices(devices, ARRAY_SIZE(devices));
	return 0;
}

postcore_initcall(hexagon_init);
