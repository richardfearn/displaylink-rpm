#
# Versions
#

DAEMON_VERSION := 4.1.9
DOWNLOAD_ID    := 1087    # This id number comes off the link on the displaylink website
VERSION        := 1.5.0
RELEASE        := 2

#
# Dependencies
#

DAEMON_PKG := DisplayLink\ USB\ Graphics\ Software\ for\ Ubuntu\ $(DAEMON_VERSION).zip
EVDI_PKG   := v$(VERSION).tar.gz
SPEC_FILE  := displaylink.spec
LIBSTDCXX_I386 := libstdc++6_6.3.0-12ubuntu2_i386.deb
LIBSTDCXX_X86_64 := libstdc++6_6.3.0-12ubuntu2_amd64.deb

# The following is a little clunky, but we need to ensure the resulting
# tarball expands the same way as the upstream tarball
EVDI_DEVEL_BRANCH   := devel
EVDI_DEVEL_BASE_DIR := /var/tmp
EVDI_DEVEL          := $(EVDI_DEVEL_BASE_DIR)/evdi-$(VERSION)

BUILD_DEPS := $(DAEMON_PKG) $(EVDI_PKG) $(LIBSTDCXX_I386) $(LIBSTDCXX_X86_64) $(SPEC_FILE)

#
# Targets
#

i386_RPM   := i386/displaylink-$(VERSION)-$(RELEASE).i386.rpm
x86_64_RPM := x86_64/displaylink-$(VERSION)-$(RELEASE).x86_64.rpm
SRPM       := displaylink-$(VERSION)-$(RELEASE).src.rpm

TARGETS    := $(i386_RPM) $(x86_64_RPM) $(SRPM)

#
# Upstream checks
#

EDVI_GITHUB := https://api.github.com/repos/DisplayLink/evdi

define get_latest_prerelease
	curl -s $(EDVI_GITHUB)/releases?per_page=1 \
		-H "Accept: application/vnd.github.full+json" |\
		grep tag_name | sed s/[^0-9\.]//g
endef

define get_devel_date
	curl -s $(EDVI_GITHUB)/branches/devel \
		-H "Accept: application/vnd.github.full+json" |\
		grep date | head -1 | cut -d: -f 2- |\
		sed s/[^0-9TZ]//g
endef

#
# PHONY targets
#

.PHONY: all rpm srpm devel rawhide clean clean-rawhide clean-mainline clean-all versions

all: $(TARGETS)

rpm: $(i386_RPM) $(x86_64_RPM)

srpm: $(SRPM)

devel: $(EVDI_DEVEL)
	cd $(EVDI_DEVEL) && git pull
	tar -z -c -f $(EVDI_PKG) -C $(EVDI_DEVEL_BASE_DIR) evdi-$(VERSION)

rawhide:
	@echo Checking last upstream commit date...
	@rawhide=$(RELEASE).rawhide.`$(get_devel_date)`; \
	$(MAKE) RELEASE=$$rawhide devel all

clean-rawhide:
	@echo Checking last upstream commit date...
	@rawhide=$(RELEASE).rawhide.`$(get_devel_date)`; \
	$(MAKE) RELEASE=$$rawhide clean-mainline

clean-mainline:
	rm -rf $(TARGETS) $(EVDI_DEVEL) $(EVDI_PKG)

clean: clean-mainline clean-rawhide

clean-all:
	rm -rf i386/*.rpm x86_64/*.rpm displaylink*.src.rpm $(EVDI_PKG) $(EVDI_DEVEL)

# for testing our version construction
versions:
	@echo VERSION: $(VERSION)
	@echo Checking upstream version...
	@version=`$(get_latest_prerelease)` && echo UPSTREAM: $$version
	@echo Checking upstream version...done
	@echo
	@echo Checking last upstream commit date...
	@devel_date=`$(get_devel_date)` && echo DEVEL_DATE: $$devel_date
	@echo Checking last upstream commit date...done

#
# Real targets
#

$(EVDI_DEVEL):
	git clone --depth 1 -b $(EVDI_DEVEL_BRANCH) \
		https://github.com/DisplayLink/evdi.git $(EVDI_DEVEL)

$(DAEMON_PKG):
	wget --post-data="fileId=$(DOWNLOAD_ID)&accept_submit=Accept" -O $(DAEMON_PKG) \
		 http://www.displaylink.com/downloads/file?id=$(DOWNLOAD_ID)

$(EVDI_PKG):
	wget -O v$(VERSION).tar.gz \
		https://github.com/DisplayLink/evdi/archive/v$(VERSION).tar.gz

$(LIBSTDCXX_X86_64):
	wget http://mirrors.kernel.org/ubuntu/pool/main/g/gcc-6/libstdc++6_6.3.0-12ubuntu2_amd64.deb

$(LIBSTDCXX_I386):
	wget http://mirrors.kernel.org/ubuntu/pool/main/g/gcc-6/libstdc++6_6.3.0-12ubuntu2_i386.deb

BUILD_DEFINES =                                                     \
    --define "_topdir `pwd`"                                        \
    --define "_sourcedir `pwd`"                                     \
    --define "_rpmdir `pwd`"                                        \
    --define "_specdir `pwd`"                                       \
    --define "_srcrpmdir `pwd`"                                     \
    --define "_buildrootdir `mktemp -d /var/tmp/displayportXXXXXX`" \
    --define "_builddir `mktemp -d /var/tmp/displayportXXXXXX`"     \
    --define "_release $(RELEASE)"                                  \
    --define "_daemon_version $(DAEMON_VERSION)"                    \
    --define "_version $(VERSION)"                                  \
    --define "_tmppath `mktemp -d /var/tmp/displayportXXXXXX`"      \

$(i386_RPM): $(BUILD_DEPS)
	rpmbuild -bb $(BUILD_DEFINES) displaylink.spec --target=i386

$(x86_64_RPM): $(BUILD_DEPS)
	rpmbuild -bb $(BUILD_DEFINES) displaylink.spec --target=x86_64

$(SRPM): $(BUILD_DEPS)
	rpmbuild -bs $(BUILD_DEFINES) displaylink.spec
