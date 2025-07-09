K=kernel
S=system
B=build-aarch64

OBJS = \
  $K/entry.o \
  $K/start.o \
  $K/console.o \
  $K/printf.o \
  $K/uart.o \
  $K/kalloc.o \
  $K/spinlock.o \
  $K/string.o \
  $K/main.o \
  $K/vm.o \
  $K/proc.o \
  $K/swtch.o \
  $K/trap.o \
  $K/syscall.o \
  $K/sysproc.o \
  $K/bio.o \
  $K/fs.o \
  $K/log.o \
  $K/sleeplock.o \
  $K/file.o \
  $K/exec.o \
  $K/sysfile.o \
  $K/trapasm.o \
  $K/timer.o \
  $K/virtio_disk.o \
  $K/gicv3.o \

# Try to infer the correct TOOLPREFIX if not set
ifndef TOOLPREFIX
TOOLPREFIX := $(shell if aarch64-unknown-elf-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'aarch64-unknown-elf-'; \
	elif aarch64-linux-gnu-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'aarch64-linux-gnu-'; \
	elif aarch64-unknown-linux-gnu-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'aarch64-unknown-linux-gnu-'; \
	else echo "***" 1>&2; \
	echo "*** Error: Couldn't find a aarch64 version of GCC/binutils." 1>&2; \
	echo "*** To turn off this error, run 'gmake TOOLPREFIX= ...'." 1>&2; \
	echo "***" 1>&2; exit 1; fi)
endif

QEMU = qemu-system-aarch64

CC = $(TOOLPREFIX)gcc
AS = $(TOOLPREFIX)gas
LD = $(TOOLPREFIX)ld

CFLAGS = -Wall -Werror -Os -g -fno-omit-frame-pointer -mcpu=cortex-a72+nofp
CFLAGS += -MD
CFLAGS += -ffreestanding -fno-common -nostdlib
CFLAGS += -I.
CFLAGS += $(shell $(CC) -fno-stack-protector -E -x c /dev/null >/dev/null 2>&1 && echo -fno-stack-protector)

LDFLAGS = -z max-page-size=4096
ASFLAGS = -Og -ggdb -mcpu=cortex-a72 -MD -I.

$B/kernel: $(OBJS) $K/kernel.ld $S/initcode
	$(LD) $(LDFLAGS) -T $K/kernel.ld -o $B/kernel $(OBJS)

$S/initcode: $S/initcode.S
	$(CC) $(CFLAGS) -nostdinc -I. -Ikernel -c $S/initcode.S -o $S/initcode.o
	$(LD) $(LDFLAGS) -N -e start -Ttext 0 -o $S/initcode.out $S/initcode.o

ULIB = $S/ulib.o $S/usys.o $S/printf.o $S/umalloc.o

_%: %.o $(ULIB)
	$(LD) $(LDFLAGS) -N -e main -Ttext 0 -o $@ $^

$S/usys.S : $S/usys.pl
	perl $S/usys.pl > $S/usys.S

$S/usys.o : $S/usys.S
	$(CC) $(CFLAGS) -c -o $S/usys.o $S/usys.S

mkfs/mkfs: mkfs/mkfs.c $K/fs.h $K/param.h
	gcc -Werror -Wall -I. -o mkfs/mkfs mkfs/mkfs.c

# Prevent deletion of intermediate files, e.g. cat.o, after first build, so
# that disk image changes after first build are persistent until clean.  More
# details:
# http://www.gnu.org/software/make/manual/html_node/Chained-Rules.html
.PRECIOUS: %.o

UPROGS=\
	$S/_cat\
	$S/_echo\
	$S/_init\
	$S/_kill\
	$S/_ls\
	$S/_sh\
	$S/_ps\
	$S/_shutdown\

$B/fs.img: mkfs/mkfs LICENSE $(UPROGS)
	mkfs/mkfs $B/fs.img LICENSE $(UPROGS)

-include kernel/*.d system/*.d

CPUS := 4

QEMUOPTS = -cpu cortex-a72 -machine virt,gic-version=3 -kernel $B/kernel -m 128M -smp $(CPUS) -nographic
QEMUOPTS += -drive file=$B/fs.img,if=none,format=raw,id=x0
QEMUOPTS += -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0

qemu: $B/kernel $B/fs.img
	$(QEMU) $(QEMUOPTS)

clean: 
	rm -f */*.o */*.d */*.asm */*.sym \
	$S/usys.S $S/initcode $S/initcode.out \
	$B/kernel $B/fs.img \
	mkfs/mkfs $(UPROGS) \
