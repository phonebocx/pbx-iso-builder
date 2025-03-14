# Default theme makefile. This is mainly for testing and demonstration of
# how themes work
#
FORCEDERROR=
ifdef FORCEDERROR
$(error Error forced by setting FORCEDERROR to $(FORCEDERROR) in $(lastword $(MAKEFILE_LIST)))
endif

# If you add something to immutablepackages, it'll automatically be pulled
# and merged into the ISO. This is a fake package, purely for demonstration
#IMMUTABLEPACKAGES += quack
GITSRC_immutable-quack=https://github.com/phonebocx/pbxpackage-quack.git
GITBRANCH_immutable-quack=main

# THEMEFILES are files that needs to be generated. They will be triggered
# prefixed by $(THEMEDESTDIR), as demonstrated below
#THEMEFILES += herp/the/derp

$(THEMEDESTDIR)/herp/the/derp:
	@echo I am doing nothing
