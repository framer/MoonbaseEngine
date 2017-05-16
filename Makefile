TEMPDIR := $(shell mktemp -d)

publish: git-check
	npm publish

test:
	cd $(TEMPDIR); git clone https://github.com/motif/Moonbase.git my-project
	cd $(TEMPDIR)/my-project; yarn; make

### Utilities

git-check:
	@status=$$(git status --porcelain); \
	if test "x$${status}" = x; then \
		git push; \
	else \
		echo "\n\n!!! Working directory is dirty, commit/push first !!!\n\n" >&2; exit 1 ; \
	fi


.PHONY: npm build clean watch upload git-check
