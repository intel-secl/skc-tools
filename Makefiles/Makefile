SUBDIRS := $(wildcard */.)

all: $(SUBDIRS)
$(SUBDIRS):
	$(MAKE) installer -C $@
.PHONY: all $(SUBDIRS)
