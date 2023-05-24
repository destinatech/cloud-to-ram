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

.PHONY: all
all:

.PHONY: install
install: install-bin install-systemd-service

.PHONY: install-systemd-service
install-systemd-service:
	[[ -d $(SYSCONFDIR)/systemd/system ]] || $(INSTALL) -m 0755 -d $(SYSCONFDIR)/systemd/system
	$(INSTALL) -m 0644 cloud-to-ram.service $(SYSCONFDIR)/systemd/system/

.PHONY: install-bin
install-bin:
	[[ -d $(BINDIR) ]] || $(INSTALL) -m 0755 -d $(BINDIR)
	$(INSTALL) -m 0755 cloud-to-ram.bash $(BINDIR)/cloud-to-ram

##
# vim: ts=8 sw=8 noet fdm=marker :
##
