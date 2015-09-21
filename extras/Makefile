NODE_MODULES = ./node_modules/moonbase/node_modules
NODE_BIN = $(NODE_MODULES)/.bin

BREW_DEPENDENCIES = node rsync

.DEFAULT_GOAL := watch

# Global check to see if all dependencies are there
K := $(foreach exec,$(EXECUTABLES), \
	$(if $(shell which $(exec)),some string,$(error "No $(exec) in PATH, run 'make bootstrap')))

bootstrap:
	brew install $(BREW_DEPENDENCIES)
	make npm

npm:
	npm install

build: npm
	$(NODE_BIN)/gulp build

watch: npm
	$(NODE_BIN)/gulp watch

upload: build
	make git-check
	# rsync ...

# Utilities

git-check:
	@status=$$(git status --porcelain); \
	if test "x$${status}" = x; then \
		git push; \
	else \
		echo "\n\n!!! Working directory is dirty, commit/push first !!!\n\n" >&2; exit 1 ; \
	fi


.PHONY: bootstrap npm build watch upload git-check