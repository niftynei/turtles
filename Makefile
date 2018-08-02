.NOTPARALLEL :
SOURCES_PATH ?= $(BASEDIR)/sources
BASE_CACHE ?= $(BASEDIR)/built
SDK_PATH ?= $(BASEDIR)/SDKs
NO_QT ?=
NO_WALLET ?=
NO_UPNP ?=
FALLBACK_DOWNLOAD_PATH ?= https://bitcoincore.org/depends-sources

BUILD = $(shell ./config.guess)
HOST ?= $(BUILD)
PATCHES_PATH = $(BASEDIR)/patches
BASEDIR = $(CURDIR)
HASH_LENGTH:=11
DOWNLOAD_CONNECT_TIMEOUT:=10
DOWNLOAD_RETRIES:=3
HOST_ID_SALT ?= salt
BUILD_ID_SALT ?= salt

host:=$(BUILD)
ifneq ($(HOST),)
host:=$(HOST)
endif

ifneq ($(DEBUG),)
release_type=debug
else
release_type=release
endif

base_build_dir=$(BASEDIR)/work/build
base_staging_dir=$(BASEDIR)/work/staging
base_download_dir=$(BASEDIR)/work/download
canonical_host:=$(shell ./config.sub $(HOST))
build:=$(shell ./config.sub $(BUILD))

build_arch =$(firstword $(subst -, ,$(build)))
build_vendor=$(word 2,$(subst -, ,$(build)))
full_build_os:=$(subst $(build_arch)-$(build_vendor)-,,$(build))
build_os:=$(findstring linux,$(full_build_os))
build_os+=$(findstring darwin,$(full_build_os))
build_os:=$(strip $(build_os))
ifeq ($(build_os),)
build_os=$(full_build_os)
endif

host_arch=$(firstword $(subst -, ,$(canonical_host)))
host_vendor=$(word 2,$(subst -, ,$(canonical_host)))
full_host_os:=$(subst $(host_arch)-$(host_vendor)-,,$(canonical_host))
host_os:=$(findstring linux,$(full_host_os))
host_os+=$(findstring darwin,$(full_host_os))
host_os+=$(findstring mingw32,$(full_host_os))
host_os:=$(strip $(host_os))
ifeq ($(host_os),)
host_os=$(full_host_os)
endif

$(host_arch)_$(host_os)_prefix=$(BASEDIR)/host/$(host)
$(host_arch)_$(host_os)_host=$(host)
host_prefix=$($(host_arch)_$(host_os)_prefix)
build_prefix=$(BASEDIR)/host/$(host)/native
build_toolchain_prefix=$(BASEDIR)/build_toolchain
host_toolchain_prefix=$(BASEDIR)/build_toolchain
old_build_toolchain_prefix=$(BASEDIR)/build_toolchain/old
build_host=$(build)
build_toolchain_os=$(build_os)
build_toolchain_arch=$(build_os)
host_toolchain_os=$(host_os)
host_toolchain_arch=$(host_arch)
$(host_arch)_$(host_os)_arch=$(host_arch)
$(host_arch)_$(host_os)_os=$(host_os)

build_toolchain_storage_type=build/$(build)
build_storage_type=build/$(build)/host/$(host)
host_toolchain_storage_type=build/$(build)/host/$(host)
$(host_arch)_$(host_os)_storage_type=build/$(build)/host/$(host)

build_work_dir=$(BASEDIR)/work/$(build)
build_toolchain_work_dir=$(BASEDIR)/work/$(build)
host_toolchain_work_dir=$(BASEDIR)/work/$(host)
$(host_arch)_$(host_os)_work_dir=$(BASEDIR)/work/$(host)

AT_$(V):=
AT_:=@
AT:=$(AT_$(V))

all: install

include hosts/$(host_os).mk
include hosts/default.mk
include builders/$(build_os).mk
include builders/default.mk
include packages/packages.mk

build_id_string:=$(BUILD_ID_SALT)
build_id_string+=$(shell $(build_CC) --version 2>/dev/null)
build_id_string+=$(shell $(build_AR) --version 2>/dev/null)
build_id_string+=$(shell $(build_CXX) --version 2>/dev/null)
build_id_string+=$(shell $(build_RANLIB) --version 2>/dev/null)
build_id_string+=$(shell $(build_STRIP) --version 2>/dev/null)

$(host_arch)_$(host_os)_id_string:=$(HOST_ID_SALT)
$(host_arch)_$(host_os)_id_string+=$(shell $(host_CC) --version 2>/dev/null)
$(host_arch)_$(host_os)_id_string+=$(shell $(host_AR) --version 2>/dev/null)
$(host_arch)_$(host_os)_id_string+=$(shell $(host_CXX) --version 2>/dev/null)
$(host_arch)_$(host_os)_id_string+=$(shell $(host_RANLIB) --version 2>/dev/null)
$(host_arch)_$(host_os)_id_string+=$(shell $(host_STRIP) --version 2>/dev/null)

qt_packages_$(NO_QT) = $(qt_packages) $(qt_$(host_os)_packages) $(qt_$(host_arch)_$(host_os)_packages)
wallet_packages_$(NO_WALLET) = $(wallet_packages)
upnp_packages_$(NO_UPNP) = $(upnp_packages)

packages += $($(host_arch)_$(host_os)_packages) $($(host_os)_packages) $(qt_packages_) $(wallet_packages_) $(upnp_packages_)
native_packages += $($(host_arch)_$(host_os)_native_packages) $($(host_os)_native_packages)

ifneq ($(qt_packages_),)
native_packages += $(qt_native_packages)
endif


meta_depends = builders/default.mk hosts/default.mk hosts/$(host_os).mk builders/$(build_os).mk

$(build_arch)_$(build_os)_build_toolchain?=$($(build_os)_build_toolchain)
$(build_arch)_$(build_os)_build_toolchain?=$(build_toolchain)

#$(host_arch)_$(host_os)_host_toolchain?=$($(host_os)_host_toolchain)
#$(host_arch)_$(host_os)_host_toolchain?=$(host_toolchain)
host_toolchain = $($(host_os)_host_toolchain) $($(host_arch)_$(host_os)_host_toolchain)


$($(host_arch)_$(host_os)_host_toolchain): $($(build_arch)_$(build_os)_build_toolchain)
$(native_packages): $($(build_arch)_$(build_os)_build_toolchain)
$(packages): $($(host_arch)_$(host_os)_host_toolchain)
$(host_toolchain) : $(build_toolchain_packages)
$(native_packages) : $(build_toolchain_packages)
$(packages) : $(host_toolchain_packages)
all_packages = $(packages) $(native_packages) $(host_toolchain) $($(build_arch)_$(build_os)_build_toolchain)
include funcs.mk

final_build_id_long+=$(shell $(build_SHA256SUM) config.site.in)
final_build_id+=$(shell echo -n "$(final_build_id_long)" | $(build_SHA256SUM) | cut -c-$(HASH_LENGTH))
$(host_prefix)/.stamp_$(final_build_id): $(host_toolchain_packages) $(host_toolchain_packages) $(native_packages) $(packages)
	$(AT)rm -rf $(@D)
	$(AT)mkdir -p $(@D)
	$(AT)echo copying packages: $^
	$(AT)echo to: $(@D)
	$(AT)cd $(@D); $(foreach package,$^, tar xf $($(package)_cached); )
	$(AT)touch $@

$(host_prefix)/share/config.site : config.site.in $(host_prefix)/.stamp_$(final_build_id)
	$(AT)@mkdir -p $(@D)
	$(AT)sed -e 's|@HOST@|$(host)|' \
            -e 's|@CC@|$(host_CC)|' \
            -e 's|@CXX@|$(host_CXX)|' \
            -e 's|@AR@|$(host_AR)|' \
            -e 's|@RANLIB@|$(host_RANLIB)|' \
            -e 's|@NM@|$(host_NM)|' \
            -e 's|@STRIP@|$(host_STRIP)|' \
            -e 's|@build_os@|$(build_os)|' \
            -e 's|@host_os@|$(host_os)|' \
            -e 's|@CFLAGS@|$(strip $(host_CFLAGS) $(host_$(release_type)_CFLAGS))|' \
            -e 's|@CXXFLAGS@|$(strip $(host_CXXFLAGS) $(host_$(release_type)_CXXFLAGS))|' \
            -e 's|@CPPFLAGS@|$(strip $(host_CPPFLAGS) $(host_$(release_type)_CPPFLAGS))|' \
            -e 's|@LDFLAGS@|$(strip $(host_LDFLAGS) $(host_$(release_type)_LDFLAGS))|' \
            -e 's|@no_qt@|$(NO_QT)|' \
            -e 's|@no_wallet@|$(NO_WALLET)|' \
            -e 's|@no_upnp@|$(NO_UPNP)|' \
            -e 's|@debug@|$(DEBUG)|' \
            $< > $@
	$(AT)touch $@


define check_or_remove_cached
  mkdir -p $(BASE_CACHE)/$($($(package)_type)_storage_type)/$(package) && cd $(BASE_CACHE)/$($($(1)_type)_storage_type)/$(package); \
  $(build_SHA256SUM) -c $($(package)_cached_checksum) >/dev/null 2>/dev/null || \
  ( rm -f $($(package)_cached_checksum); \
    if test -f "$($(package)_cached)"; then echo "Checksum mismatch for $(package). Forcing rebuild.."; rm -f $($(package)_cached_checksum) $($(package)_cached); fi )
endef

define check_or_remove_sources
  mkdir -p $($(package)_source_dir); cd $($(package)_source_dir); \
  test -f $($(package)_fetched) && ( $(build_SHA256SUM) -c $($(package)_fetched) >/dev/null 2>/dev/null || \
    ( echo "Checksum missing or mismatched for $(package) source. Forcing re-download."; \
      rm -f $($(package)_all_sources) $($(1)_fetched))) || true
endef

check-packages:
	@$(foreach package,$(all_packages),$(call check_or_remove_cached,$(package));)
check-sources:
	@$(foreach package,$(all_packages),$(call check_or_remove_sources,$(package));)

$(host_prefix)/share/config.site: check-packages

check-packages: check-sources

install: check-packages $(host_prefix)/share/config.site


download-one: check-sources $(all_sources)

download-osx:
	@$(MAKE) -s HOST=x86_64-apple-darwin11 download-one
download-linux:
	@$(MAKE) -s HOST=x86_64-unknown-linux-gnu download-one
download-win:
	@$(MAKE) -s HOST=x86_64-w64-mingw32 download-one
download: download-osx download-linux download-win

.PHONY: install cached download-one download-osx download-linux download-win download check-packages check-sources
