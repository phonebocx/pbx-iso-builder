SHELL=/bin/bash
BUILDROOT := $(shell pwd)
BUILDUTIME := $(shell date +%s)
BRANCH ?= $(shell date +%Y.%m)
# TODO: Fix this
BUILDNUM ?= 2
BUILD ?= $(BRANCH)-$(shell printf "%03d" $(BUILDNUM))
export BUILD BRANCH BUILDNUM BUILDROOT BUILDUTIME

# Everything needs secondexpansion
.SECONDEXPANSION:

# This is exported for use by the pbx-kernel-builder toolset
KERNELVER=6.6.62
KERNELREL=1
KFIRMWARE=20240610
export KERNELVER KERNELREL KFIRMWARE

# This should be in a totally different filesystem to THIS
# builder, to avoid things like vscode trying to explore everything
# inside a full system chroot. Everything in here can be thrown away
# without any consequences. I strongly suggest a different volume.
# The faster the better.
COREBUILD ?= /usr/local/build
ISOBUILDROOT=$(COREBUILD)/live-build-workspace
export COREBUILD ISOBUILDROOT

# This is where things are staged.
SRCDIR=$(BUILDROOT)/src
# This is the directory that packages are staged to, before being squashfs'ed
PKGBUILDDIR=$(SRCDIR)/pkgbuild
# This is the directory that is copied into /live/packages on the ISO
PKGDESTDIR=$(COREBUILD)/packages
# Any debs placed here get injected by build-live-iso.sh
DEBDEST=$(SRCDIR)/debs
# This is everything that gets overlaid over the default config in
# ISOBUILDROOT *before* the STAGING folder is applied. This allows
# something in staging to override a default (eg, a theme)
LIVEBUILDSRC=$(BUILDROOT)/livebuild
# This is the staging directory for anything that should be merged
# on top of $(ISOBUILDROOT)/config in build-live-iso.sh
STAGING=$(SRCDIR)/staging
# Where isos are placed when built
ISODEST=$(BUILDROOT)/isos
export SRCDIR PKGBUILDDIR PKGDESTDIR DEBDEST LIVEBUILDSRC STAGING

# Various misc components and tools that are checked into git but shouldn't
# be in the root of this repo. Basically, just to keep things tidy.
ISOCOMPONENTS=$(BUILDROOT)/components
export ISOCOMPONENTS

# Anything here can, and is, automatically made by the $(MKDIRS) target below
# Other makefiles should add to this.
MKDIRS = $(SRCDIR) $(DEBDEST) $(ISOBUILDROOT) $(PKGDESTDIR)

# Anything in prereqs is made by `make setup`
PREREQS = $(MKDIRS)

# This is only here for testing, to use local-tests instead
LOCALDIR=$(SRCDIR)/local
#LOCALDIR=$(ISOCOMPONENTS)/local-tests

# If there is a local Makefile.early, include it before the theme
# compiler, so it can configure things
include $(wildcard $(LOCALDIR)/Makefile.early)

# This is a setting-only makefile, to figure out what the theme
# SHOULD be, and possibly download it if needed. This is included
# early before anything else
include $(ISOCOMPONENTS)/Makefile.theme

# If the theme has a settings makefile, include that to add
# anything that might be needed by other includes. Currently
# this is only used for adding fonts to the system.
include $(wildcard $(THEMEDIR)/Makefile.settings)

# This is used in liveiso to take all the vars in default, and then
# overwrite anything provided by the non-default theme.
# This is a ?= setting just in case something ELSE wanted to override
# it for some reasons.
DEFAULTTHEMEDIR ?= $(BUILDROOT)/theme/default

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

# And if there is a Makefile.final in local, include that LAST
include $(wildcard $(LOCALDIR)/Makefile.final)

# This is anything that's in TOOLS or STOOLS
PKGS=$(addprefix /usr/bin/,$(TOOLS))
SPKGS=$(addprefix /usr/sbin/,$(STOOLS))

STARGETS += $(PKGS) $(SPKGS)

# And now trigger them
.PHONY: setup
setup: $(STARGETS) $(PREREQS) | $(SRCDIR)

build: setup $(PREREQS)
	@echo "Build: There are $(PREREQS)"

.PHONY: debug
debug:
	@echo "I want to trigger $(STARGETS) in setup"

# This installs whatever is needed by PKGS or SPKGS
/usr/bin/% /usr/sbin/%:
	@p="$(PKG_$*)"; p=$${p:=$*}; apt-get -y install $$p || ( echo "Don't know how to install $*, add PKG_$*=dpkgname to the makefile"; exit 1 )

# Just make anything in MKDIRS, easy DRY.
$(MKDIRS):
	@echo 'pbx-iso-builder is mkdiring $@'
	@mkdir -p $@

