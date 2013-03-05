extra-y := head.o vmlinux.lds

 
obj-$(CONFIG_SMP) += smp.o 
obj-y += setup.o traps.o syscalltab.o signal.o time.o topology.o
obj-y += process.o syscall.o trampoline.o reset.o ptrace.o
obj-y += vdso.o

obj-$(CONFIG_KGDB)    += kgdb.o
obj-$(CONFIG_MODULES) += module.o hexagon_ksyms.o

# Modules required to work with the Hexagon Virtual Machine
obj-y += vm_events.o vm_switch.o
obj-y += vm_vectors.o vm_ops.o vm_entry.o

obj-$(CONFIG_HAS_DMA) += dma.o

obj-$(CONFIG_STACKTRACE) += stacktrace.o
