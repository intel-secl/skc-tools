SUBDIRS := authservice certificate-management-service sgx-ah sgx-caching-service sgx-hvs sgx-verification-service

all: $(SUBDIRS)
$(SUBDIRS):
	$(MAKE) installer -C $@
.PHONY: all $(SUBDIRS)
