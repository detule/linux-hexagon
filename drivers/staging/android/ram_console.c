/* drivers/android/ram_console.c
 *
 * Copyright (C) 2007-2008 Google, Inc.
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
#include <linux/proc_fs.h>
#include <linux/string.h>
#include <linux/uaccess.h>
#include <linux/io.h>
#include <linux/tty.h>
#include <linux/tty_driver.h>
#include "ram_console.h"

#ifdef CONFIG_ANDROID_RAM_CONSOLE_ERROR_CORRECTION
#include <linux/rslib.h>
#endif

#define MAX_ROOM 4096

struct ram_console_buffer {
	uint32_t    sig;
	uint32_t    start;
	uint32_t    size;
	uint8_t     data[0];
};

#define RAM_CONSOLE_SIG (0x43474244) /* DBGC */

static char *ram_console_old_log;
static size_t ram_console_old_log_size;

static volatile struct ram_console_buffer *ram_console_buffer;
static size_t ram_console_buffer_size;
#ifdef CONFIG_ANDROID_RAM_CONSOLE_ERROR_CORRECTION
static char *ram_console_par_buffer;
static struct rs_control *ram_console_rs_decoder;
static int ram_console_corrected_bytes;
static int ram_console_bad_blocks;
#define ECC_BLOCK_SIZE CONFIG_ANDROID_RAM_CONSOLE_ERROR_CORRECTION_DATA_SIZE
#define ECC_SIZE CONFIG_ANDROID_RAM_CONSOLE_ERROR_CORRECTION_ECC_SIZE
#define ECC_SYMSIZE CONFIG_ANDROID_RAM_CONSOLE_ERROR_CORRECTION_SYMBOL_SIZE
#define ECC_POLY CONFIG_ANDROID_RAM_CONSOLE_ERROR_CORRECTION_POLYNOMIAL
#endif

void ram_console_write_size(const char *s, unsigned count);

static void
ram_console_write(struct console *console, const char *s, unsigned int count)
{
	ram_console_write_size(s,count);
}

static struct tty_driver *ram_console_tty_driver;

static struct tty_driver *ram_console_device(struct console *c, int *index)
{
	*index = 0;
	return ram_console_tty_driver;
}

static struct console ram_console = {
	.name	= "ttyR",
	.write	= ram_console_write,
	.device = ram_console_device,
	.flags	= CON_PRINTBUFFER | CON_ENABLED,
	.index	= -1,
};

void ram_console_enable_console(int enabled)
{
	if (enabled)
		ram_console.flags |= CON_ENABLED;
	else
		ram_console.flags &= ~CON_ENABLED;
}

static int ram_console_tty_init(void);

static int __init ram_console_init(volatile struct ram_console_buffer *buffer,
				   size_t buffer_size, const char *bootinfo,
				   char *old_buf)
{
#ifdef CONFIG_ANDROID_RAM_CONSOLE_ERROR_CORRECTION
	int numerr;
	uint8_t *par;
#endif

	ram_console_tty_init();
	register_console(&ram_console);
#ifdef CONFIG_ANDROID_RAM_CONSOLE_ENABLE_VERBOSE
	console_verbose();
#endif
	return 0;
}

static int __init ram_console_early_init(void)
{
	return ram_console_init((struct ram_console_buffer *)
		0,0,
		NULL,
		0);
}

struct ram_console_port {
	struct tty_port port;
	struct mutex port_write_mutex;
};

static struct ram_console_port ram_console_port;
 
static int ram_console_tty_open(struct tty_struct *tty, struct file *filp)
{
	tty->driver_data = &ram_console_port;
	printk("ram_console_tty open\n");
//	tty_set_ldisc(N_TTY);

	return tty_port_open(&ram_console_port.port, tty, filp);
}

static void ram_console_tty_close(struct tty_struct *tty, struct file *filp)
{
	struct ram_console_port *rcp = tty->driver_data;

	tty_port_close(&rcp->port, tty, filp);
}

static int ram_console_tty_write(struct tty_struct *tty,
		const unsigned char *buf, int count)
{
	struct ram_console_port *rcp = tty->driver_data;
//	printk("%s\n",__func__);

	/* exclusive use of tpk_printk within this tty */
	mutex_lock(&rcp->port_write_mutex);
	ram_console_write(0,buf, count);
	mutex_unlock(&rcp->port_write_mutex);

	return count;
}

static int ram_console_tty_write_room(struct tty_struct *tty)
{
	return MAX_ROOM;
}

static int ram_console_tty_ioctl(struct tty_struct *tty,
			unsigned int cmd, unsigned long arg)
{
	struct ram_console_port *rcp = tty->driver_data;
	printk("%s\n",__func__);
	if (!rcp)
		return -EINVAL;

	switch (cmd) {
	/* Stop TIOCCONS */
	case TIOCCONS:
		return -EOPNOTSUPP;
	default:
		return -ENOIOCTLCMD;
	}
	return 0;
}

static void ram_console_tty_set_ldisc(struct tty_struct *tty)
{
	printk("%s set_ldisc\n", __func__);
}

static const struct tty_operations ram_console_tty_ops = {
	.open = ram_console_tty_open,
	.close = ram_console_tty_close,
	.write = ram_console_tty_write,
	.write_room = ram_console_tty_write_room,
	.ioctl = ram_console_tty_ioctl,
	.set_ldisc = ram_console_tty_set_ldisc,
};

static struct tty_port_operations null_ops = { };

static int __init ram_console_tty_init(void)
{
	int ret = -ENOMEM;

	tty_port_init(&ram_console_port.port);
	ram_console_port.port.ops = &null_ops;
	mutex_init(&ram_console_port.port_write_mutex);

	ram_console_tty_driver = tty_alloc_driver(1, TTY_DRIVER_UNNUMBERED_NODE);
	if (IS_ERR(ram_console_tty_driver))
		return PTR_ERR(ram_console_tty_driver);

	ram_console_tty_driver->driver_name = "ramconsole";
	ram_console_tty_driver->name = "ttyR";
	ram_console_tty_driver->major = TTYAUX_MAJOR;
	ram_console_tty_driver->minor_start = 4;
	ram_console_tty_driver->type = TTY_DRIVER_TYPE_CONSOLE;
	ram_console_tty_driver->init_termios = tty_std_termios;
	ram_console_tty_driver->init_termios.c_oflag = OPOST | OCRNL | ONOCR | ONLRET;
	ram_console_tty_driver->flags |= TTY_DRIVER_REAL_RAW; 
	tty_set_operations(ram_console_tty_driver, &ram_console_tty_ops);
	tty_port_link_device(&ram_console_port.port, ram_console_tty_driver, 0);

	ret = tty_register_driver(ram_console_tty_driver);

	if (ret < 0) {
		printk(KERN_ERR "Couldn't register ram_console_tty driver\n");
		goto error;
	}
	printk("Registered ram_console_tty Major %d, Minor %d\n", TTYAUX_MAJOR, 4);

	return 0;

error:
	tty_unregister_driver(ram_console_tty_driver);
	put_tty_driver(ram_console_tty_driver);
	ram_console_tty_driver = NULL;
	return ret;
}

#ifdef CONFIG_ANDROID_RAM_CONSOLE_EARLY_INIT
postcore_initcall(ram_console_early_init);
#else
postcore_initcall(ram_console_module_init);
#endif

