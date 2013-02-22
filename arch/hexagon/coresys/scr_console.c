/* hexagon/coresys/scr_console.c
 *
 * Copyright (C) 2013 Cotulla
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


#include <linux/console.h>
#include <linux/init.h>
#include <linux/module.h>
#include <linux/platform_device.h>
#include <linux/string.h>
#include <linux/uaccess.h>
#include <linux/font.h>
#include <linux/delay.h>
#include <asm/io.h>


#ifdef CONFIG_HEXAGON_ARCH_V2

// HTC LEO
#define SCR_FB_LCD_WIDTH	480
#define SCR_FB_LCD_HEIGHT	800

#define SCR_FB_BASE		0xF0300000 
#define SCR_FB_SIZE		0x00100000

#else


#error Screen console code is not tested. 

// HTC Touchpad
#define SCR_FB_LCD_WIDTH	1024
#define SCR_FB_LCD_HEIGHT	768

#define SCR_FB_BASE		0xF0300000 

#define SCR_FB_SIZE		0x00400000


#endif





/* Defined in include/linux/fb.h. When, on write, a registered framebuffer device is detected,
 * we immediately unregister ourselves. */
#ifndef CONFIG_SCR_FB_CONSOLE_BOOT
extern int num_registered_fb;
#endif


/* Set max console size for a 4x4 font */
#define SCR_FB_CON_MAX_ROWS	(SCR_FB_LCD_WIDTH / 4)
#define SCR_FB_CON_MAX_COLS	(SCR_FB_LCD_HEIGHT / 4)



/* Pack color data in 565 RGB format; r and b are 5 bits, g is 6 bits */
#define SCR_FB_RGB(r, g, b) 	((((r) & 0x1f) << 11) | (((g) & 0x3f) << 5) | (((b) & 0x1f) << 0))

/* Some standard colors */
unsigned short scr_fb_colors[8] = 
{
	SCR_FB_RGB(0x00, 0x00, 0x00), /* Black */
	SCR_FB_RGB(0x1f, 0x00, 0x00), /* Red */
	SCR_FB_RGB(0x00, 0x15, 0x00), /* Green */
	SCR_FB_RGB(0x0f, 0x15, 0x00), /* Brown */
	SCR_FB_RGB(0x00, 0x00, 0x1f), /* Blue */
	SCR_FB_RGB(0x1f, 0x00, 0x1f), /* Magenta */
	SCR_FB_RGB(0x00, 0x3f, 0x1f), /* Cyan */
	SCR_FB_RGB(0x1f, 0x3f, 0x1f)  /* White */
};

/* We can use any font which has width <= 8 pixels */
const struct font_desc *scr_fb_default_font;

/* Pointer to font data (255 * font_rows bytes of data)  */
const unsigned char *scr_fb_font_data;

/* Size of font in pixels */
unsigned int scr_fb_font_cols, scr_fb_font_rows;

/* Size of console in chars */
unsigned int scr_fb_console_cols, scr_fb_console_rows;

/* Current position of cursor (where next character will be written) */
unsigned int scr_fb_cur_x, scr_fb_cur_y;

/* Current fg / bg colors */
unsigned char scr_fb_cur_fg, scr_fb_cur_bg;

/* Buffer to hold characters and attributes */
unsigned char scr_fb_chars[SCR_FB_CON_MAX_ROWS][SCR_FB_CON_MAX_COLS];
unsigned char scr_fb_fg[SCR_FB_CON_MAX_ROWS][SCR_FB_CON_MAX_COLS];
unsigned char scr_fb_bg[SCR_FB_CON_MAX_ROWS][SCR_FB_CON_MAX_COLS];

static void scr_fb_console_write(struct console *console, const char *s, unsigned int count);


/* Console data */
static struct console scr_fb_console = 
{
	.name	= "scr_fb",
	.write	= scr_fb_console_write,
	.flags	=
// Enable to use console only during boot
//		CON_BOOT |
		CON_PRINTBUFFER | CON_ENABLED,
	.index	= -1,
};


/* Update the framebuffer from the character buffer then start DMA */
static void scr_fb_console_update(void)
{
	unsigned int memaddr, stride, width, height, x, y, i, j, r1, c1, r2, c2;
	unsigned short *ptr;
	unsigned char ch;

	memaddr = SCR_FB_BASE;

	ptr = (unsigned short*) memaddr;
	for (i = 0; i < scr_fb_console_rows * scr_fb_font_rows; i++) {
		r1 = i / scr_fb_font_rows;
		r2 = i % scr_fb_font_rows;
		for (j = 0; j < scr_fb_console_cols * scr_fb_font_cols; j++) {
			c1 = j / scr_fb_font_cols;
			c2 = j % scr_fb_font_cols;
			ch = scr_fb_chars[r1][c1];
			*ptr++ = scr_fb_font_data[(((int) ch) * scr_fb_font_rows) + r2] & ((1 << (scr_fb_font_cols - 1)) >> c2)
				? scr_fb_colors[scr_fb_fg[r1][c1]]
				: scr_fb_colors[scr_fb_bg[r1][c1]];
		}
		ptr += SCR_FB_LCD_WIDTH - scr_fb_console_cols * scr_fb_font_cols;
	}

	stride = SCR_FB_LCD_WIDTH * 2;
	width = SCR_FB_LCD_WIDTH;
	height = SCR_FB_LCD_HEIGHT;
	x = 0;
	y = 0;

	// TODO: update code here
}

/* Clear screen and buffers */
static void scr_fb_console_clear(void)
{
	/* Default white on black, clear everything */
	memset((void*)SCR_FB_BASE, 0, SCR_FB_LCD_WIDTH * SCR_FB_LCD_HEIGHT * 2);
	memset(scr_fb_chars, 0, scr_fb_console_cols * scr_fb_console_rows);
	memset(scr_fb_fg, 7, scr_fb_console_cols * scr_fb_console_rows);
	memset(scr_fb_bg, 0, scr_fb_console_cols * scr_fb_console_rows);
	scr_fb_cur_x = scr_fb_cur_y = 0;
	scr_fb_cur_fg = 7;
	scr_fb_cur_bg = 0;
	scr_fb_console_update();
}


/* Write a string to character buffer; handles word wrapping, auto-scrolling, etc
 * After that, calls scr_fb_console_update to send data to the LCD */
static void scr_fb_console_write(struct console *console, const char *s, unsigned int count)
{
	unsigned int i, j, k, scroll;
	const char *p;

//#ifndef CONFIG_SCR_FB_CONSOLE_BOOT
#if 0
	// See if a framebuffer has been registered. If so, we disable this console to prevent conflict with
	// other FB devices (i.e. msm_fb).
	if (num_registered_fb > 0) 
	{
		printk(KERN_INFO "scr_fb_console: framebuffer device detected, disabling boot console\n");
		console->flags = 0;
		return;
	}
#endif

	scroll = 0;
	for (k = 0, p = s; k < count; k++, p++) {
		if (*p == '\n') {
			/* Jump to next line */
			scroll = 1;
		} else if (*p == '\t') {
			/* Tab size 8 chars */
			scr_fb_cur_x = (scr_fb_cur_x + 7) % 8;
			if (scr_fb_cur_x >= scr_fb_console_cols) {
				scroll = 1;
			}
		} else if (*p == '\x1b') {
			/* Escape char (ascii 27)
			 * Some primitive way to change color:
			 * \x1b followed by one digit to represent color (0 black ... 7 white) */
			if (k < count - 1) {
				p++;
				scr_fb_cur_fg = *p - '0';
				if (scr_fb_cur_fg >= 8) {
					scr_fb_cur_fg = 7;
				}
			}
		} else if (*p != '\r') {
			/* Ignore \r, other cars get written here */
			scr_fb_chars[scr_fb_cur_y][scr_fb_cur_x] = *p;
			scr_fb_fg[scr_fb_cur_y][scr_fb_cur_x] = scr_fb_cur_fg;
			scr_fb_bg[scr_fb_cur_y][scr_fb_cur_x] = scr_fb_cur_bg;
			scr_fb_cur_x++;
			if (scr_fb_cur_x >= scr_fb_console_cols) {
				scroll = 1;
			}
		}
		if (scroll) {
			scroll = 0;
			scr_fb_cur_x = 0;
			scr_fb_cur_y++;
			if (scr_fb_cur_y == scr_fb_console_rows) {
				/* Scroll below last line, shift all rows up
				 * Should have used a bigger buffer so no shift,
				 * would actually be needed -- but hey, it's a one night hack */
				scr_fb_cur_y--;
				for (i = 1; i < scr_fb_console_rows; i++) {
					for (j = 0; j < scr_fb_console_cols; j++) {
						scr_fb_chars[i - 1][j] = scr_fb_chars[i][j];
						scr_fb_fg[i - 1][j] = scr_fb_fg[i][j];
						scr_fb_bg[i - 1][j] = scr_fb_bg[i][j];
					}
				}
				for (j = 0; j < scr_fb_console_cols; j++) {
					scr_fb_chars[scr_fb_console_rows - 1][j] = 0;
					scr_fb_fg[scr_fb_console_rows - 1][j] = scr_fb_cur_fg;
					scr_fb_bg[scr_fb_console_rows - 1][j] = scr_fb_cur_bg;
				}
			}
		}
	}

	scr_fb_console_update();

#ifdef CONFIG_SCR_FB_CONSOLE_DELAY
	/* Delay so we can see what's there, we have no keys to scroll */
	mdelay(500);
#endif
}

// Make sure we don't init twice
static bool scr_fb_console_init_done = false;


int __init scr_fb_console_init(void)
{
	if (scr_fb_console_init_done)
	{
		printk(KERN_INFO "scr_fb_console_init: already initialized, bailing out\n");
		return 0;
	}
	scr_fb_console_init_done = true;


	/* Init font (we support any font that has width <= 8; height doesn't matter) */
	scr_fb_default_font = get_default_font(SCR_FB_LCD_WIDTH, SCR_FB_LCD_HEIGHT, 0xFF, 0xFFFFFFFF);
	if (!scr_fb_default_font) 
	{
		printk(KERN_WARNING "Can't find a suitable font for scr_fb\n");
		return -1;
	}

	scr_fb_font_data = scr_fb_default_font->data;
	scr_fb_font_cols = scr_fb_default_font->width;
	scr_fb_font_rows = scr_fb_default_font->height;
	scr_fb_console_cols = SCR_FB_LCD_WIDTH / scr_fb_font_cols;
	if (scr_fb_console_cols > SCR_FB_CON_MAX_COLS)
		scr_fb_console_cols = SCR_FB_CON_MAX_COLS;
	scr_fb_console_rows = SCR_FB_LCD_HEIGHT / scr_fb_font_rows;
	if (scr_fb_console_rows > SCR_FB_CON_MAX_ROWS)
		scr_fb_console_rows = SCR_FB_CON_MAX_ROWS;

	/* Clear the buffer; we could probably see the Haret output if we didn't clear
	 * the buffer (if it used same physical address) */
	scr_fb_console_clear();

	/* Welcome message */
#define SCR_FB_MSG	"Welcome to Hexagon Linux!\nKeep SSR alive!\n"
	scr_fb_console_write(&scr_fb_console, SCR_FB_MSG, strlen(SCR_FB_MSG));

	/* Register console */
	register_console(&scr_fb_console);
	console_verbose();

	return 0;
}

//console_initcall(scr_fb_console_init);

