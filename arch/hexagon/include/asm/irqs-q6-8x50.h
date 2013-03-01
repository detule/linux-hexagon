/*
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

#ifndef _ASM_IRQ_Q6_QSD8X50_H_
#define _ASM_IRQ_Q6_QSD8X50_H_


/* QSD8x50 ADSP6 Level One Interrupt Mapping */

#define INT_Q6_ETM		0
#define INT_Q6_ISDB		1
#define INT_Q6_MPRPH		2
#define INT_Q6_RGPTIMER		3
#define INT_Q6_UGPTIMER		4
#define INT_Q6_IPC0		5
#define INT_Q6_IPC1		6
#define INT_Q6_IPC2		7
#define INT_Q6_IPC3		8
#define INT_Q6_IPC4		9
#define INT_Q6_IPC5		10
#define INT_Q6_SPSS		11
#define INT_Q6_AUDIO		12
#define INT_Q6_VIDEO_FE		13
#define INT_Q6_ADM		14
#define INT_Q6_VIDEO_ENC	15
#define INT_Q6_VIDEO_DEC	16
#define INT_Q6_GRAPHICS		17
#define INT_Q6_MDP		18
#define INT_Q6_MDSP4		19
#define INT_Q6_MARM_FIQ		20
#define INT_Q6_MARM_IRQ		21
#define INT_Q6_MARM_RESET	22
#define INT_Q6_SIRC0		23
#define INT_Q6_SIRC1		24
#define INT_Q6_AVS_DONE		25


/* Max number of interrupts per secondary controller */
#define INT_Q6_SIRC_COUNT 	32



#define INT_Q6_SIRC0_START	(HEXAGON_CPUINTS)
#define INT_Q6_SIRC1_START	(INT_Q6_SIRC0_START + INT_Q6_SIRC_COUNT)



/* QSD8x50 ADSP6 Level Two Group Zero Interrupt Mapping */
#define INT_Q6_EBI1			(INT_Q6_SIRC0_START + 0)
#define INT_Q6_IMEM			(INT_Q6_SIRC0_START + 1)
#define INT_Q6_SMI			(INT_Q6_SIRC0_START + 2)
#define INT_Q6_AXI			(INT_Q6_SIRC0_START + 3)
#define INT_Q6_PBUS_ERROR		(INT_Q6_SIRC0_START + 4)
#define INT_Q6_TV_ENC			(INT_Q6_SIRC0_START + 5)
#define INT_Q6_EBI2_OP_DONE		(INT_Q6_SIRC0_START + 6)
#define INT_Q6_EBI2_WR_ER_DONE		(INT_Q6_SIRC0_START + 7)

#define INT_Q6_A0_PEN			(INT_Q6_SIRC0_START + 15)
#define INT_Q6_CRYPTO			(INT_Q6_SIRC0_START + 16)
#define INT_Q6_GPIO_GROUP2		(INT_Q6_SIRC0_START + 18)
#define INT_Q6_GPIO_GROUP1		(INT_Q6_SIRC0_START + 19)
#define INT_Q6_MDDI_EXTERN		(INT_Q6_SIRC0_START + 20)
#define INT_Q6_MDDI_PRIMARY		(INT_Q6_SIRC0_START + 21)
#define INT_Q6_MDDI_CLIENT		(INT_Q6_SIRC0_START + 22)
#define INT_Q6_TCHSCRN_I2C		(INT_Q6_SIRC0_START + 23)
#define INT_Q6_TCHSCRN_SRC1		(INT_Q6_SIRC0_START + 24)
#define INT_Q6_TCHSCRN_SRC2		(INT_Q6_SIRC0_START + 25)
#define INT_Q6_TCHSCRN_SSBI		(INT_Q6_SIRC0_START + 26)



/* QSD8x50 ADSP6 Level Two Group One Interrupt Mapping */
#define INT_Q6_USB_FS1		(INT_Q6_SIRC1_START + 0)
#define INT_Q6_USB_HS		(INT_Q6_SIRC1_START + 1)
#define INT_Q6_USB_FS2		(INT_Q6_SIRC1_START + 2)
#define INT_Q6_SDC1_0		(INT_Q6_SIRC1_START + 3)
#define INT_Q6_SDC1_1		(INT_Q6_SIRC1_START + 4)
#define INT_Q6_SDC2_0		(INT_Q6_SIRC1_START + 5)
#define INT_Q6_SDC2_1		(INT_Q6_SIRC1_START + 6)
#define INT_Q6_SDC3_0		(INT_Q6_SIRC1_START + 7)
#define INT_Q6_SDC3_1		(INT_Q6_SIRC1_START + 8)
#define INT_Q6_SDC4_0		(INT_Q6_SIRC1_START + 9)
#define INT_Q6_SDC4_1		(INT_Q6_SIRC1_START + 10)
#define INT_Q6_SPI_OUT		(INT_Q6_SIRC1_START + 11)
#define INT_Q6_SPI_IN		(INT_Q6_SIRC1_START + 12)
#define INT_Q6_SPI_ERR		(INT_Q6_SIRC1_START + 13)
#define INT_Q6_UART1		(INT_Q6_SIRC1_START + 14)
#define INT_Q6_UART1_RX		(INT_Q6_SIRC1_START + 15)
#define INT_Q6_UART2		(INT_Q6_SIRC1_START + 16)
#define INT_Q6_UART2_RX		(INT_Q6_SIRC1_START + 17)
#define INT_Q6_UART3		(INT_Q6_SIRC1_START + 18)
#define INT_Q6_UART3_RX		(INT_Q6_SIRC1_START + 19)
#define INT_Q6_UARTDM1		(INT_Q6_SIRC1_START + 20)
#define INT_Q6_UARTDM1_RX	(INT_Q6_SIRC1_START + 21)
#define INT_Q6_UARTDM2		(INT_Q6_SIRC1_START + 22)
#define INT_Q6_UARTDM2_RX	(INT_Q6_SIRC1_START + 23)
#define INT_Q6_TSIF		(INT_Q6_SIRC1_START + 24)



// Main + 2 SIRC
//
#define NR_IRQS 	(HEXAGON_CPUINTS + 2 * INT_Q6_SIRC_COUNT)


#endif
