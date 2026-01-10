# Flowgate Makefile

PREFIX ?= /usr
SYSCONFDIR ?= /etc
LOCALSTATEDIR ?= /var
DESTDIR ?=

# Directories
BINDIR = $(PREFIX)/bin
SHAREDIR = $(PREFIX)/share
WEBDIR = $(SHAREDIR)/flowgate
CONFDIR = $(SYSCONFDIR)/flowgate
DATADIR = $(LOCALSTATEDIR)/lib/flowgate
LOGDIR = $(LOCALSTATEDIR)/log

# Init system detection
SYSTEMD_UNITDIR = $(SYSCONFDIR)/systemd/system
INITD_DIR = $(SYSCONFDIR)/init.d

# Optional components
WEB ?= 0

.PHONY: all install install-flowgate install-web install-services clean help

all: help

help:
	@echo "Flowgate Installer"
	@echo ""
	@echo "Usage:"
	@echo "  make install              Install flowgate CLI only"
	@echo "  make install WEB=1        Install flowgate + Flowgate Web UI"
	@echo ""
	@echo "Options:"
	@echo "  PREFIX=/usr              Installation prefix (default: /usr)"
	@echo "  DESTDIR=                 Staging directory for packaging"
	@echo "  WEB=0|1                  Include Flowgate Web (default: 0)"

# Main install target
install: install-flowgate install-services
ifeq ($(WEB),1)
	$(MAKE) install-web
endif
	@echo ""
	@echo "Installation complete!"

# Install flowgate CLI
install-flowgate:
	@echo "Installing flowgate..."

	# Create directories
	install -d -m 755 $(DESTDIR)$(BINDIR)
	install -d -m 755 $(DESTDIR)$(CONFDIR)
	install -d -m 750 $(DESTDIR)$(DATADIR)
	install -d -m 750 $(DESTDIR)$(DATADIR)/backups
	install -d -m 750 $(DESTDIR)/etc/sudoers.d

	# Install binary
	install -m 755 flowgate $(DESTDIR)$(BINDIR)/flowgate

	# Install sudoers
	install -m 440 flowgate.sudoers $(DESTDIR)/etc/sudoers.d/flowgate

	# Install default config
	install -m 644 flowgate.yaml.default $(DESTDIR)$(CONFDIR)/flowgate.yaml.default

	# Copy to active config if not exists (don't overwrite existing config)
	@test -f $(DESTDIR)$(CONFDIR)/flowgate.yaml || \
		(install -m 644 flowgate.yaml.default $(DESTDIR)$(CONFDIR)/flowgate.yaml && \
		echo "Created default configuration at $(CONFDIR)/flowgate.yaml")

	@echo "flowgate installed"

# Install Flowgate Web
install-web: install-flowgate
	@echo "Installing Flowgate Web..."

	# Create directories
	install -d -m 755 $(DESTDIR)$(WEBDIR)
	install -d -m 755 $(DESTDIR)$(WEBDIR)/static
	install -d -m 755 $(DESTDIR)$(WEBDIR)/templates
	install -d -m 750 $(DESTDIR)$(LOGDIR)/flowgate

	# Install files
	install -m 644 web/main.py $(DESTDIR)$(WEBDIR)/main.py
	for f in web/static/*; do install -m 644 "$$f" $(DESTDIR)$(WEBDIR)/static/; done
	for f in web/templates/*; do install -m 644 "$$f" $(DESTDIR)$(WEBDIR)/templates/; done

	# Install service
ifeq ($(INIT_SYSTEM),systemd)
	install -d -m 755 $(DESTDIR)$(SYSTEMD_UNITDIR)
	install -m 644 flowgate-web.service $(DESTDIR)$(SYSTEMD_UNITDIR)/flowgate-web.service
else
	install -d -m 755 $(DESTDIR)$(INITD_DIR)
	install -m 755 flowgate-web.init $(DESTDIR)$(INITD_DIR)/flowgate-web
endif
	@echo "Flowgate Web installed"

# Install init services
install-services:
	@echo "Installing services for $(INIT_SYSTEM)..."
ifeq ($(INIT_SYSTEM),systemd)
	install -d -m 755 $(DESTDIR)$(SYSTEMD_UNITDIR)
	install -m 644 flowgate.service $(DESTDIR)$(SYSTEMD_UNITDIR)/flowgate.service
	install -m 644 flowgate-sync.service $(DESTDIR)$(SYSTEMD_UNITDIR)/flowgate-sync.service
	install -m 644 flowgate-sync.path $(DESTDIR)$(SYSTEMD_UNITDIR)/flowgate-sync.path
else
	install -d -m 755 $(DESTDIR)$(INITD_DIR)
	install -m 755 flowgate.init $(DESTDIR)$(INITD_DIR)/flowgate
endif
	@echo "Services installed"

clean:
	rm -f *.pyc *~ .*~
