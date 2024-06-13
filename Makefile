SHELL = /bin/bash

INSTALL = $(shell type -P install)
SUDO ?=

ifneq ($(shell id -u),0)
  SUDO = sudo
endif

DESTDIR ?=

PREFIX     = $(DESTDIR)/usr
SYSCONFDIR = $(DESTDIR)/etc
BINDIR     = $(PREFIX)/bin

# Version checking logic/message gratefully borrowed from the Linux kernel's
# top-level Makefile:
#
#   <https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/Makefile>
#
ifeq ($(filter undefine,$(.FEATURES)),)
  $(error GNU Make >= 3.82 is required. Your Make version is $(MAKE_VERSION))
endif

ifeq ("$(origin V)", "command line")
  ifeq ("$(V)", "1")
    VERBOSE = 1
  endif
endif

Q ?=
ifndef VERBOSE
  Q = @
endif

.PHONY: all
all:

.PHONY: install
install: install-bin install-systemd-service

.PHONY: install-systemd-service
install-systemd-service:
	$(Q)[[ -d $(SYSCONFDIR)/systemd/system ]] || $(INSTALL) -m 0755 -d $(SYSCONFDIR)/systemd/system
	$(Q)$(INSTALL) -m 0644 cloud-to-ram.service $(SYSCONFDIR)/systemd/system/

.PHONY: install-bin
install-bin:
	$(Q)[[ -d $(BINDIR) ]] || $(INSTALL) -m 0755 -d $(BINDIR)
	$(Q)$(INSTALL) -m 0755 cloud-to-ram.bash $(BINDIR)/cloud-to-ram

##
# vim: ts=8 sw=8 noet fdm=marker :
##
