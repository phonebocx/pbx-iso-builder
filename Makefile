SHELL=/bin/bash
BUILDNUM=1
BUILDROOT=$(shell pwd)
export BUILDNUM BUILDROOT

# This is exported for use by the pbx-kernel-builder toolset
KERNELVER=6.6.39
KERNELREL=1
KFIRMWARE=20240610
export KERNELVER KERNELREL KFIRMWARE

SRCDIR=$(BUILDROOT)/src
BUILDUTIME=$(shell date +%s)
BRANCH=$(shell date +%Y.%m)
BUILD=$(BRANCH)-$(shell printf "%03d" $(BUILDNUM))
PKGBUILDDIR=$(BUILDROOT)/packages
DEBDEST=$(BUILDROOT)/debs
PKGDESTDIR=$(SRCDIR)/packages
THEME ?= default
THEMEDIR ?= $(BUILDROOT)/theme/$(THEME)

# This is used in liveiso to take all the vars in default, and then
# overwrite anything provided by the non-default theme
DEFAULTTHEMEDIR ?= $(BUILDROOT)/theme/default

export KERNELVER KERNELREL BRANCH BUILDNUM BUILD SRCDIR THEME THEMEDIR BUILDUTIME PKGDESTDIR

# Anything here can be automatically made by the $(MKDIRS) target below
MKDIRS=$(SRCDIR) $(DEBDEST)

# Things that are always needed
TOOLS += curl vim ping wget netstat syslinux figlet toilet
PKG_ping=iputils-ping
PKG_netstat=net-tools

# This is first so we always have a default that is harmless (assuming
# you think that 'make setup' is harmless, which I think it is!)
.PHONY: halp
halp: setup
	@echo "No help yet"

# Drag in any includes
include $(wildcard includes/Makefile.*)

# This is anything that's in TOOLS or STOOLS
PKGS=$(addprefix /usr/bin/,$(TOOLS))
SPKGS=$(addprefix /usr/sbin/,$(STOOLS))

STARGETS += $(PKGS) $(SPKGS)

# And now trigger them
.PHONY: setup
setup: $(STARGETS) $(PREREQS) | $(SRCDIR)
	@echo "There are $(PREREQS)"

build: setup $(PREREQS)
	@echo "There are $(PREREQS)"


.PHONY: debug
debug:
	@echo "I want to trigger $(STARGETS) in setup"

# This installs whatever is needed by PKGS or SPKGS
/usr/bin/% /usr/sbin/%:
	p="$(PKG_$*)"; p=$${p:=$*}; apt-get -y install $$p || ( echo "Don't know how to install $*, fix the makefile"; exit 1 )

# Just make anything in MKDIRS, easy DRY.
$(MKDIRS):
	mkdir -p $@

