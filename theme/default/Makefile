# Default theme makefile. Mostly for testing.
FORCEDERROR=
ifdef FORCEDERROR
$(error Error forced by setting FORCEDERROR to $(FORCEDERROR) in $(lastword $(MAKEFILE_LIST)))
endif

# Test adding a package
IMMUTABLEPACKAGES += quack
GITSRC_immutable-quack=https://github.com/phonebocx/pbxpackage-quack.git
GITBRANCH_immutable-quack=main

# Add a file that needs to be generated
#THEMEFILES += herp/the/derp

$(THEMEDESTDIR)/herp/the/derp:
	@echo I am doing nothing
