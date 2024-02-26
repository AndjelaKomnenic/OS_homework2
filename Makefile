B=bootloader
K=kernel
U=user
T=tools

OBJS = \
	$K/bio.o\
	$K/console.o\
	$K/exec.o\
	$K/file.o\
	$K/fs.o\
	$K/ide.o\
	$K/ioapic.o\
	$K/kalloc.o\
	$K/kbd.o\
	$K/lapic.o\
	$K/log.o\
	$K/main.o\
	$K/mp.o\
	$K/picirq.o\
	$K/pipe.o\
	$K/proc.o\
	$K/sleeplock.o\
	$K/spinlock.o\
	$K/string.o\
	$K/swtch.o\
	$K/syscall.o\
	$K/sysfile.o\
	$K/sysproc.o\
	$K/trapasm.o\
	$K/trap.o\
	$K/uart.o\
	$K/vectors.o\
	$K/vm.o\

# Cross-compiling (e.g., on Mac OS X)
# TOOLPREFIX = i386-jos-elf

# Using native tools (e.g., on X86 Linux)
#TOOLPREFIX = 

# Try to infer the correct TOOLPREFIX if not set
ifndef TOOLPREFIX
TOOLPREFIX := $(shell if i686-elf-objdump -i 2>&1 | grep '^elf32-i386$$' >/dev/null 2>&1; \
	then echo 'i686-elf-'; \
	elif objdump -i 2>&1 | grep 'elf32-i386' >/dev/null 2>&1; \
	then echo ''; \
	else echo "***" 1>&2; \
	echo "*** Error: Couldn't find an i?86-*-elf version of GCC/binutils." 1>&2; \
	echo "*** Is the directory with i686-elf-gcc in your PATH?" 1>&2; \
	echo "*** If your i?86-*-elf toolchain is installed with a command" 1>&2; \
	echo "*** prefix other than 'i686-elf-', set your TOOLPREFIX" 1>&2; \
	echo "*** environment variable to that prefix and run 'make' again." 1>&2; \
	echo "*** To turn off this error, run 'gmake TOOLPREFIX= ...'." 1>&2; \
	echo "***" 1>&2; exit 1; fi)
endif

# If the makefile can't find QEMU, specify its path here
# QEMU = qemu-system-i386

# Try to infer the correct QEMU
ifndef QEMU
QEMU = $(shell \
	command -v qemu \
	|| command -v qemu-system-i386 \
	|| command -v qemu-system-x86_64 \
	|| command -v /Applications/Q.app/Contents/MacOS/i386-softmmu.app/Contents/MacOS/i386-softmmu \
	|| { \
	echo "***" 1>&2; \
	echo "*** Error: Couldn't find a working QEMU executable." 1>&2; \
	echo "*** Is the directory containing the qemu binary in your PATH" 1>&2; \
	echo "*** or have you tried setting the QEMU variable in Makefile?" 1>&2; \
	echo "***" 1>&2; exit 1; })
endif

CC = $(TOOLPREFIX)gcc
AS = $(TOOLPREFIX)gas
LD = $(TOOLPREFIX)ld
OBJCOPY = $(TOOLPREFIX)objcopy
STRIPNOTES = -R '.note' -R '.note.*'
OBJDUMP = $(TOOLPREFIX)objdump
CFLAGS = -mgeneral-regs-only -fno-pic -static -fno-builtin -fno-strict-aliasing -O2 -Wall -ggdb -m32 -fno-omit-frame-pointer -I.
CFLAGS += $(shell $(CC) -fno-stack-protector -E -x c /dev/null >/dev/null 2>&1 && echo -fno-stack-protector)
ASFLAGS = -m32 -I. -gdwarf-2 -Wa,-divide
# FreeBSD ld wants ``elf_i386_fbsd''
LDFLAGS += -m $(shell $(LD) -V | grep elf_i386 2>/dev/null | head -n 1)

# Disable PIE when possible (for Ubuntu 16.10 toolchain)
ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]no-pie'),)
CFLAGS += -fno-pie -no-pie
endif
ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]nopie'),)
CFLAGS += -fno-pie -nopie
endif

# Enable dependency tracking
override CFLAGS += -MMD -MF .deps/$@ -MT $@
MKDEPDIR = mkdir -p .deps/$(@D)

.PHONY: all
all: xv6.img fs.img

# Ensure that any header changes cause all sources to be recompiled.
%.o: %.c
	$(MKDEPDIR)
	$(CC) -c $(CFLAGS) -o $@t $<
	$(OBJCOPY) $(STRIPNOTES) $@t $@
	rm $@t

%.o: %.S
	$(MKDEPDIR)
	$(CC) -c $(ASFLAGS) -o $@ $<

xv6.img: $B/bootblock $K/kernel
	dd if=/dev/zero of=xv6.img count=10000
	dd if=$B/bootblock of=xv6.img conv=notrunc
	dd if=$K/kernel of=xv6.img seek=1 conv=notrunc

xv6memfs.img: $B/bootblock $K/kernelmemfs
	dd if=/dev/zero of=xv6memfs.img count=10000
	dd if=$B/bootblock of=xv6memfs.img conv=notrunc
	dd if=$K/kernelmemfs of=xv6memfs.img seek=1 conv=notrunc

$B/bootblock: $B/bootasm.S $B/bootmain.c
	$(MKDEPDIR)
	$(CC) $(CFLAGS) -MF .deps/$(@D)-1 -fno-pic -O -nostdinc -I. -c $B/bootmain.c -o $B/bootmain.o
	$(CC) $(CFLAGS) -MF .deps/$(@D)-2 -fno-pic -nostdinc -I. -c $B/bootasm.S -o $B/bootasm.o
	$(LD) $(LDFLAGS) -N -e start -Ttext 0x7C00 -o $B/bootblock.o $B/bootasm.o $B/bootmain.o
	$(OBJCOPY) $(STRIPNOTES) -S -O binary -j .text $B/bootblock.o $B/bootblock
	$T/sign.pl $B/bootblock

$K/entryother: $K/entryother.S
	$(MKDEPDIR)
	$(CC) $(CFLAGS) -fno-pic -nostdinc -I. -c $K/entryother.S -o $K/entryother.o
	$(LD) $(LDFLAGS) -N -e start -Ttext 0x7000 -o $B/bootblockother.o $K/entryother.o
	$(OBJCOPY) $(STRIPNOTES) -S -O binary -j .text $B/bootblockother.o $K/entryother

$U/initcode: $U/initcode.S
	$(MKDEPDIR)
	$(CC) $(CFLAGS) -nostdinc -I. -c $U/initcode.S -o $U/initcode.o
	$(LD) $(LDFLAGS) -N -e start -Ttext 0 -o $U/initcode.out $U/initcode.o
	$(OBJCOPY) -S $(STRIPNOTES) -O binary $U/initcode.out $U/initcode

$K/kernel: $(OBJS) $K/entry.o $K/entryother $U/initcode $K/kernel.ld
	$(LD) $(LDFLAGS) -T $K/kernel.ld -o $K/kernel $K/entry.o $(OBJS) -b binary $U/initcode $K/entryother

# kernelmemfs is a copy of kernel that maintains the
# disk image in memory instead of writing to a disk.
# This is not so useful for testing persistent storage or
# exploring disk buffering implementations, but it is
# great for testing the kernel on real hardware without
# needing a scratch disk.
MEMFSOBJS = $(filter-out $K/ide.o,$(OBJS)) $K/memide.o
$K/kernelmemfs: $(MEMFSOBJS) $K/entry.o $K/entryother $U/initcode $K/kernel.ld fs.img
	$(LD) $(LDFLAGS) -T $K/kernel.ld -o $K/kernelmemfs $K/entry.o  $(MEMFSOBJS) -b binary $U/initcode $K/entryother fs.img

tags: $(OBJS) $K/entryother.S $U/_init
	etags */*.S */*.c

$K/vectors.S: $T/vectors.pl
	$T/vectors.pl > $K/vectors.S

ULIB = $U/ulib.o $U/usys.o $U/printf.o $U/umalloc.o

_%: %.o $(ULIB)
	$(LD) $(LDFLAGS) -N -e main -Ttext 0 -o $@ $^

$U/_forktest: $U/forktest.o $(ULIB)
	# forktest has less library code linked in - needs to be small
	# in order to be able to max out the proc table.
	$(LD) $(LDFLAGS) -N -e main -Ttext 0 -o $U/_forktest $U/forktest.o $U/ulib.o $U/usys.o

$T/mkfs: $T/mkfs.c $K/fs.h
	gcc -Wall -I. -o $T/mkfs $T/mkfs.c

# Prevent deletion of intermediate files, e.g. cat.o, after first build, so
# that disk image changes after first build are persistent until clean.  More
# details:
# http://www.gnu.org/software/make/manual/html_node/Chained-Rules.html
.PRECIOUS: %.o

UPROGS=\
	$U/_cat\
	$U/_echo\
	$U/_forktest\
	$U/_grep\
	$U/_init\
	$U/_kill\
	$U/_ln\
	$U/_ls\
	$U/_mkdir\
	$U/_rm\
	$U/_sh\
	$U/_stressfs\
	$U/_usertests\
	$U/_wc\
	$U/_zombie\

fs.img: $T/mkfs README $(UPROGS)
	$T/mkfs fs.img README $(UPROGS)

.PHONY: clean
clean:
	rm -f *.tex *.dvi *.idx *.aux *.log *.ind *.ilg \
	*/*.o */*.d */*.asm */*.sym $K/vectors.S $B/bootblock $K/entryother \
	$U/initcode $U/initcode.out $K/kernel xv6.img fs.img $K/kernelmemfs \
	xv6memfs.img $T/mkfs .gdbinit \
	$(UPROGS)
	rm -rf .deps

# try to generate a unique GDB port
GDBPORT = $(shell expr `id -u` % 5000 + 25000)
# QEMU's gdb stub command line changed in 0.11
QEMUGDB = $(shell if $(QEMU) -help | grep -q '^-gdb'; \
	then echo "-gdb tcp::$(GDBPORT)"; \
	else echo "-s -p $(GDBPORT)"; fi)
ifndef CPUS
CPUS := 1
endif
QEMUOPTS = -drive file=fs.img,index=1,media=disk,format=raw -drive file=xv6.img,index=0,media=disk,format=raw -smp $(CPUS) -m 512 $(QEMUEXTRA)

.PHONY: qemu
qemu: fs.img xv6.img
	$(QEMU) $(QEMUOPTS)

.PHONY: qemu-memfs
qemu-memfs: xv6memfs.img
	$(QEMU) -drive file=xv6memfs.img,index=0,media=disk,format=raw -smp $(CPUS) -m 256

.PHONY: qemu-nox
qemu-nox: fs.img xv6.img
	$(QEMU) -serial mon:stdio -nographic $(QEMUOPTS)

.gdbinit: .gdbinit.tmpl
	sed "s/localhost:1234/localhost:$(GDBPORT)/" < $^ > $@

.PHONY: qemu-gdb
qemu-gdb: fs.img xv6.img .gdbinit
	@echo "*** Now run 'gdb'." 1>&2
	$(QEMU) $(QEMUOPTS) -S $(QEMUGDB)

.PHONY: qemu-nox-gdb
qemu-nox-gdb: fs.img xv6.img .gdbinit
	@echo "*** Now run 'gdb'." 1>&2
	$(QEMU) -serial mon:stdio -nographic $(QEMUOPTS) -S $(QEMUGDB)

# Include the -MMD dependency files.
-include $(shell [ -d .deps ] && find .deps -type f)
