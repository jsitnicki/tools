KDIR ?= /lib/modules/`uname -r`/build

default:
	$(MAKE) -C $(KDIR) M=$$PWD

run:
	# FIXME: Figure out --script-{sh,exec} options
	virtme-run --installed-kernel --pwd --qemu-opts -m 512M
