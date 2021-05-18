PKGNAME ?= FilterDelay
PKGVERSION ?= 0.0.1
ER301_SRC ?= ../../er-301/

ASSETS = $(wildcard *.lua)
PACKAGE_FILE = $(PKGNAME)-$(PKGVERSION).pkg

all: $(PACKAGE_FILE)

$(PACKAGE_FILE): $(ASSETS)
	@echo [ZIP $@]
	@rm -f $@
	@zip -j $@ $(ASSETS)

list: $(PACKAGE_FILE)
	@unzip -l $(PACKAGE_FILE)

clean:
	rm -rf $(PACKAGE_FILE)

emu-install: $(PACKAGE_FILE)
	cp $(PACKAGE_FILE) $(HOME)/.od/rear

start-emu:
	cd $(ER301_SRC); ./testing/darwin/emu/emu.elf

emu: emu-install start-emu