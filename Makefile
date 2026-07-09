.PHONY: install install-system uninstall test lint clean all
PREFIX ?= $(HOME)/.local
BINDIR = $(PREFIX)/bin
LIBDIR = $(PREFIX)/share/sysclean/lib

all: test

install:
	@echo "Installing to $(PREFIX)..."
	install -d $(BINDIR) $(LIBDIR)
	install -m 755 sysclean $(BINDIR)/sysclean
	install -m 644 lib/*.sh $(LIBDIR)/
	@echo "✓ Installed: $(BINDIR)/sysclean"

install-system: PREFIX = /usr/local
install-system: install
	@echo "✓ System install: $(BINDIR)/sysclean"

uninstall:
	@echo "Uninstalling from $(PREFIX)..."
	rm -f $(BINDIR)/sysclean
	rm -rf $(PREFIX)/share/sysclean
	@echo "✓ Uninstalled"

test:
	@echo "Running E2E tests..."
	@bash tests/test_e2e.sh

lint:
	@echo "Linting bash scripts..."
	@for f in sysclean lib/*.sh tests/*.sh; do \
	  bash -n "$$f" && echo "  ✓ $$f" || echo "  ✗ $$f FAILED"; \
	done

clean:
	@echo "Cleaning test artifacts..."
	rm -f /tmp/sysclean.test.* /tmp/sysclean.raw /tmp/sc.log
	rm -f tests/*.log
	@echo "✓ Cleaned"

# Show version
version:
	@./sysclean --version
