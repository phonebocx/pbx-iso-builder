SHELL=/bin/bash
BRANCH=$(shell date +%Y.%m)
BUILDNUM=1
BUILD=$(BRANCH)-$(shell printf "%03d" $(BUILDNUM))
SRCDIR=$(shell pwd)/src
DEBDEST=$(shell pwd)/debs

# This should match pbx-kernel-builder
KERNELVER=6.6.25
KERNELREL=1
export KERNELVER KERNELREL BRANCH BUILDNUM BUILD SRCDIR

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

