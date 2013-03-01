/* Copyright (c) 2008-2009, Code Aurora Forum. All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 and
 * only version 2 as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 */

#ifndef __ASM_ARCH_MSM_SIRC_H
#define __ASM_ARCH_MSM_SIRC_H


void msm_init_sirc(void);


/*
 * Secondary interrupt controller interrupts
 */

#define FIRST_SIRC_IRQ 		      INT_Q6_SIRC0_START 
#define LAST_SIRC_IRQ                 (INT_Q6_SIRC0_START + 2 * INT_Q6_SIRC_COUNT)


#define SIRC_MASK                     0x007FFFFF


#endif
