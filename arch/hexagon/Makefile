#  Makefile for the Hexagon arch

KBUILD_DEFCONFIG = comet_defconfig

# Do not use GP-relative jumps
KBUILD_CFLAGS += -G0
LDFLAGS_vmlinux += -G0

# Do not use single-byte enums; these will overflow.
KBUILD_CFLAGS += -fno-short-enums

# Modules must use either long-calls, or use pic/plt.
# Use long-calls for now, it's easier.  And faster.
# CFLAGS_MODULE += -fPIC
# LDFLAGS_MODULE += -shared
CFLAGS_MODULE += -mlong-calls

cflags-$(CONFIG_HEXAGON_ARCH_V1) += $(call cc-option,-mv1)
cflags-$(CONFIG_HEXAGON_ARCH_V2) += $(call cc-option,-mv2)
cflags-$(CONFIG_HEXAGON_ARCH_V3) += $(call cc-option,-mv3)
cflags-$(CONFIG_HEXAGON_ARCH_V4) += $(call cc-option,-mv4)

aflags-$(CONFIG_HEXAGON_ARCH_V1) += $(call cc-option,-mv1)
aflags-$(CONFIG_HEXAGON_ARCH_V2) += $(call cc-option,-mv2)
aflags-$(CONFIG_HEXAGON_ARCH_V3) += $(call cc-option,-mv3)
aflags-$(CONFIG_HEXAGON_ARCH_V4) += $(call cc-option,-mv4)

ldflags-$(CONFIG_HEXAGON_ARCH_V1) += $(call cc-option,-mv1)
ldflags-$(CONFIG_HEXAGON_ARCH_V2) += $(call cc-option,-mv2)
ldflags-$(CONFIG_HEXAGON_ARCH_V3) += $(call cc-option,-mv3)
ldflags-$(CONFIG_HEXAGON_ARCH_V4) += $(call cc-option,-mv4)

KBUILD_CFLAGS += $(cflags-y)
KBUILD_AFLAGS += $(aflags-y)

#  no KBUILD_LDFLAGS?
LDFLAGS += $(ldflags-y)

# Thread-info register will be r19.  This value is not configureable;
# it is hard-coded in several files.
TIR_NAME := r19
KBUILD_CFLAGS += -ffixed-$(TIR_NAME) -DTHREADINFO_REG=$(TIR_NAME) -D__linux__
KBUILD_AFLAGS += -DTHREADINFO_REG=$(TIR_NAME)

head-y := arch/hexagon/kernel/head.o

core-y += arch/hexagon/kernel/ \
	arch/hexagon/mm/ \
	arch/hexagon/lib/	\
	arch/hexagon/coresys/	\
	arch/hexagon/platform/
	

# Cotulla ADD for qImage
#

OBJCOPYFLAGS	:=-O binary -R .comment -S

boot := arch/hexagon/boot
MACHINE  :=

all: 	qImage

qImage: vmlinux
	$(Q)$(MAKE) $(build)=$(boot) MACHINE=$(MACHINE) $(boot)/$@

# We use MRPROPER_FILES and CLEAN_FILES now
archclean:
	$(Q)$(MAKE) $(clean)=$(boot)

