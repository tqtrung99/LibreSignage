##
##  LibreSignage makefile
##

# Note: This makefile assumes that $(ROOT) always has a trailing
# slash. (which is the case when using the makefile $(dir ...)
# function) Do not use the shell dirname command here as that WILL
# break things since it doesn't add the trailing slash to the path.
ROOT := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

SASS_DEP := build/scripts/sassdep.py
SASS_IPATHS := $(ROOT) $(ROOT)src/common/css $(ROOT)/src/node_modules
SASS_FLAGS := --no-source-map $(addprefix -I,$(SASS_IPATHS))

COMPOSER_DEP := build/scripts/composer_prod_deps.sh
COMPOSER_DEP_FLAGS := --self

POSTCSS_FLAGS := --config postcss.config.js --replace --no-map

PHPUNIT_API_HOST ?= http://localhost:80
PHPUNIT_CONFIG := tests/phpunit.xml
PHPUNIT_FLAGS := -c "$(PHPUNIT_CONFIG)" --testdox --color=auto

JSDOC_CONFIG := jsdoc.json

# Define required dependency versions.
NPM_REQ_VER := 6.4.0
COMPOSER_REQ_VER := 1.8.0
MAKE_REQ_VER := 4.0
PANDOC_REQ_VER := 2.0
DOXYGEN_REQ_VER := 1.8.0
RSVG_REQ_VER := 2.40.0


# Caller supplied build settings.
VERBOSE ?= Y
NOHTMLDOCS ?= N
CONF ?= ""
TARGET ?=
PASS ?=
INITCHK_WARN ?= N

# Don't search for dependencies when certain targets with no deps are run.
# The if-statement below is some hacky makefile magic. Don't be scared.
NODEP_TARGETS := clean realclean LOC configure configure-build \
	configure-system initchk install doxygen-docs
ifneq ($(filter \
	0 $(shell expr $(words $(MAKECMDGOALS)) '*' '2'),\
	$(words \
		$(filter-out \
			$(NODEP_TARGETS),\
			$(MAKECMDGOALS)\
		) $(MAKECMDGOALS)\
	)\
),)

# PHP autoload files from vendor/composer/.
PHP_AUTOLOAD := $(shell find vendor/composer/ -type f -name '*.php') vendor/autoload.php

# Production PHP libraries.
PHP_LIBS := $(shell find $(addprefix vendor/,\
	$(shell "./$(COMPOSER_DEP)" "$(COMPOSER_DEP_FLAGS)"|cut -d' ' -f1)\
) -type f) $(PHP_AUTOLOAD)

# Production JavaScript libraries.
JS_LIBS := $(filter-out \
	$(shell printf "$(ROOT)\n"|sed 's:/$$::g'), \
	$(shell npm ls --prod --parseable|sed 's/\n/ /g') \
)

# Non-compiled sources.
SRC_NO_COMPILE := $(shell find src \
	\( -type f -path 'src/node_modules/*' -prune \) \
	-o \( -type f -path 'src/public/api/endpoint/*' -prune \) \
	-o \( \
		-type f ! -name '*.swp' \
		-a -type f ! -name '*.save' \
		-a -type f ! -name '.\#*' \
		-a -type f ! -name '\#*\#*' \
		-a -type f ! -name '*~' \
		-a -type f ! -name '*.js' \
		-a -type f ! -name '*.scss' \
		-a -type f ! -name '*.rst' -print \
	\) \
)

# RST sources.
SRC_RST := $(shell find src \
	\( -type f -path 'src/node_modules/*' -prune \) \
	-o -type f -name '*.rst' -print \
) README.rst CONTRIBUTING.rst AUTHORS.rst

# SCSS sources.
SRC_SCSS := $(shell find src \
	\( -type f -path 'src/node_modules/*' -prune \) \
	-o -type f -name '*.scss' -a ! -name '_*' -print \
)

# JavaScript sources.
SRC_JS := $(shell find src \
	\( -type f -path 'src/node_modules/*' -prune \) \
	-o \( -type f -name 'main.js' -print \) \
)

# API endpoint sources.
SRC_ENDPOINT := $(shell find src/public/api/endpoint \
	\( -type f -path 'src/node_modules/*' -prune \) \
	-o \( -type f -name '*.php' -print \) \
)

# Generated PNG logo paths.
GENERATED_LOGOS := $(addprefix dist/public/assets/images/logo/libresignage_,16x16.png 32x32.png 96x96.png text_466x100.png)

endif

#
# Command definitions.
#

#
# Print a status message.
#
# $(1) = The program doing the work. (cp, rm, etc.)
# $(2) = The source file.
# $(3) = The destination file.
#
status = \
	if [ "`printf '$(VERBOSE)'|cut -c1|sed 's/\n//g'|\
		tr '[:upper:]' '[:lower:]'`" = "y" ]; then \
		printf "$(1): $(2) >> $(3)\n"|tr -s ' '|sed 's/^ *$///g'; \
	fi

#
# Recursively create the directory path for a file.
#
# $(1) = The filepath to use.
#
makedir = mkdir -p $(dir $(1))

#
# Print the initialization check info/warning.
#
# $(1) = The status code of the initialization checks.
#
initchk_warn =\
	if [ ! "$(1)" = "0" ]; then\
		case "$(INITCHK_WARN)" in \
			[nN]*)\
				echo "[Info] To continue anyway, pass INITCHK_WARN=Y to make.";\
				exit 1;\
				;;\
			*)\
				echo "[Warning] Continuing anyway. You're on your own.";\
				;;\
		esac;\
	fi


ifeq ($(NOHTMLDOCS),$(filter $(NOHTMLDOCS),y Y))
$(info [Info] Not going to generate HTML documentation.)
endif

.PHONY: $(NODEP_TARGETS) dirs server js css api config libs \
	docs htmldocs $(PHP_AUTOLOAD)

.ONESHELL:

all:: initchk server docs htmldocs js css api js_libs php_libs logo; @:
server:: $(subst src,dist,$(SRC_NO_COMPILE)); @:
js:: $(subst src,dist/public,$(SRC_JS)); @:
api:: $(subst src,dist,$(SRC_ENDPOINT)); @:
docs:: $(addprefix dist/doc/rst/,$(notdir $(SRC_RST))) dist/doc/rst/api_index.rst; @:
htmldocs:: $(addprefix dist/public/doc/html/,$(notdir $(SRC_RST:.rst=.html))); @:
css:: $(subst src,dist/public,$(SRC_SCSS:.scss=.css)); @:
js_libs:: $(subst $(ROOT)node_modules/,dist/public/libs/,$(JS_LIBS)); @:
php_libs:: $(subst vendor/,dist/vendor/,$(PHP_LIBS)); @:
logo:: $(GENERATED_LOGOS); @:

# Copy over non-compiled, non-PHP sources.
$(filter-out %.php,$(subst src,dist,$(SRC_NO_COMPILE))):: dist%: src%
	@:
	set -e
	$(call status,cp,$<,$@)
	$(call makedir,$@)
	cp -p $< $@

# Copy and prepare PHP files and check the syntax.
$(filter %.php,$(subst src,dist,$(SRC_NO_COMPILE))):: dist%: src%
	@:
	set -e
	$(call status,cp,$<,$@)
	$(call makedir,$@)
	cp -p $< $@
	php -l $@ > /dev/null

# Copy API endpoint PHP files and generate corresponding docs.
$(subst src,dist,$(SRC_ENDPOINT)):: dist%: src%
	@:
	set -e
	php -l $< > /dev/null

	$(call status,cp,$<,$@)
	$(call makedir,$@)
	cp -p $< $@

	if [ ! "$$NOHTMLDOCS" = "y" ] && [ ! "$$NOHTMLDOCS" = "Y" ]; then
		# Generate reStructuredText documentation.
		mkdir -p dist/doc/rst
		mkdir -p dist/public/doc/html
		$(call status,\
			gendoc.sh,\
			<generated>,\
			dist/doc/rst/$(notdir $(@:.php=.rst))\
		)
		./build/scripts/gendoc.sh $(CONF) $@ dist/doc/rst/

		# Compile rst docs into HTML.
		$(call status,\
			pandoc,\
			dist/doc/rst/$(notdir $(@:.php=.rst)),\
			dist/public/doc/html/$(notdir $(@:.php=.html))\
		)
		pandoc -f rst -t html \
			-o dist/public/doc/html/$(notdir $(@:.php=.html)) \
			dist/doc/rst/$(notdir $(@:.php=.rst))
	fi

# Generate the API endpoint documentation index.
dist/doc/rst/api_index.rst:: $(SRC_ENDPOINT)
	@:
	set -e
	$(call status,makefile,<generated>,$@)
	$(call makedir,$@)

	. build/scripts/conf.sh
	printf "LibreSignage API documentation (Ver: $$API_VER)\n" > $@
	printf '###############################################\n\n' >> $@

	printf "This document was automatically generated by the" >> $@
	printf "LibreSignage build system on `date`.\n\n" >> $@

	for f in $(SRC_ENDPOINT); do
		printf "\``basename $$f` </doc?doc=`basename -s '.php' $$f`>\`_\n\n" >> $@
	done

	# Compile into HTML.
	if [ ! "$$NOHTMLDOCS" = "y" ] && [ ! "$$NOHTMLDOCS" = "Y" ]; then
		$(call status,pandoc,$(subst /rst/,/html/,$($:.rst=.html)),$@)
		$(call makedir,$(subst /rst/,/html/,$@))
		pandoc -f rst -t html -o $(subst /rst/,/html/,$(@:.rst=.html)) $@
	fi

# Copy over RST sources. Try to find prerequisites from
# 'src/doc/rst/' first and then fall back to './'.
dist/doc/rst/%.rst:: src/doc/rst/%.rst
	@:
	set -e
	$(call status,cp,$<,$@)
	$(call makedir,$@)
	cp -p $< $@

dist/doc/rst/%.rst:: %.rst
	@:
	set -e
	$(call status,cp,$<,$@)
	$(call makedir,$@)
	cp -p $< $@

# Compile RST sources into HTML. Try to find prerequisites
# from 'src/doc/rst/' first and then fall back to './'.
dist/public/doc/html/%.html:: src/doc/rst/%.rst
	@:
	set -e
	if [ ! "$$NOHTMLDOCS" = "y" ] && [ ! "$$NOHTMLDOCS" = "Y" ]; then
		$(call status,pandoc,$<,$@)
		$(call makedir,$@)
		pandoc -o $@ -f rst -t html $<
	fi

dist/public/doc/html/%.html:: %.rst
	@:
	set -e
	if [ ! "$$NOHTMLDOCS" = "y" ] && [ ! "$$NOHTMLDOCS" = "Y" ]; then
		$(call status,pandoc,$<,$@)
		$(call makedir,$@)
		pandoc -o $@ -f rst -t html $<
	fi

# Generate JavaScript deps.
dep/%/main.js.dep: src/%/main.js
	@:
	set -e
	$(call status,deps-js,$<,$@)
	$(call makedir,$@)

	TARGET="$(subst src,dist/public,$(<))"
	SRC="$(<)"
	DEPS=`npx browserify --list $$SRC | tr '\n' ' ' | sed 's:$(ROOT)::g'`

	# Printf dependency makefile contents.
	printf "$$TARGET:: $$DEPS\n" > $@
	printf "\t@:\n" >> $@
	printf "\t\$$(call status,compile-js,$$SRC,$$TARGET)\n" >> $@
	printf "\t\$$(call makedir,$$TARGET)\n" >> $@
	printf "\tnpx browserify $$SRC -o $$TARGET\n" >> $@

# Generate SCSS deps.
dep/%.scss.dep: src/%.scss
	@:
	set -e
	# Don't create deps for partials.
	if [ ! "`basename '$(<)' | cut -c 1`" = "_" ]; then
		$(call status,deps-scss,$<,$@)
		$(call makedir,$@)

		TARGET="$(subst src,dist/public,$(<:.scss=.css))"
		SRC="$(<)"
		DEPS=`./$(SASS_DEP) -l $$SRC $(SASS_IPATHS)|sed 's:$(ROOT)::g'`

		# Printf dependency makefile contents.
		printf "$$TARGET:: $$SRC $$DEPS\n" > $@
		printf "\t@:\n" >> $@
		printf "\t\$$(call status,compile-scss,$$SRC,$$TARGET)\n" >> $@
		printf "\t\$$(call makedir,$$SRC)\n" >> $@

		printf "\tnpx sass $(SASS_FLAGS) $$SRC $$TARGET\n" >> $@
		printf "\tnpx postcss $$TARGET $(POSTCSS_FLAGS)\n" >> $@
	fi

# Install deps from NPM.
node_modules:
	@:
	set -e
	npm install

# Copy production node modules to 'dist/public/libs/'.
dist/public/libs/%:: node_modules/%
	@:
	set -e
	mkdir -p $@
	$(call status,cp,$<,$@)
	cp -Rp $</* $@

# Install deps from Composer.
vendor:
	@:
	set -e
	composer install

# Dump composer autoload files. Make all the autoload files in vendor/composer
# depend on vendor/autoload.php so that composer dump-autoload is only run
# once and not for every autoload file. $(PHP_AUTOLOAD) is also marked PHONY
# so that autoload files are created every time make is invoked. This makes sure
# that the correct autoload files are created for unit testing and production
# versions.
#
# Note that the autoload files are not copied into dist/ if $(PHP_AUTOLOAD) is
# directly specified as a prerequisite (see test-api). This is because the paths
# in $(PHP_AUTOLOAD) refer to vendor/composer/* and vendor/autoload.php. That
# means the dist/vendor/% target below is skipped. When make is invoked normally,
# however, the php_libs target prefixes $(PHP_LIBS) with dist/ so that all the
# libs and autoload files are copied into dist/ aswell in the dist/vendor/% target.
$(filter-out vendor/autoload.php,$(PHP_AUTOLOAD)): vendor/autoload.php
vendor/autoload.php:
	@:
	case "$(MAKECMDGOALS)" in
		*test-api*)
			echo "[Info] Dump development autoload."
			composer dump-autoload --no-ansi
			;;
		*)
			echo "[Info] Dump production autoload."
			composer dump-autoload --no-ansi --no-dev --optimize
			;;
	esac

# Copy Composer libraries to dist/vendors.
dist/vendor/%:: vendor/%
	@:
	set -e
	$(call status,cp,$<,$@)
	mkdir -p $$(dirname $@)
	cp -Rp $< $@

# Convert the LibreSignage SVG logos to PNG logos of various sizes.
.SECONDEXPANSION:
$(GENERATED_LOGOS): dist/%.png: src/$$(shell printf '$$*\n' | rev | cut -f 2- -d '_' | rev).svg
	@:
	set -e
	. build/scripts/convert_images.sh
	SRC_DIR=`dirname $(@) | sed 's:dist:src:g'`
	DEST_DIR=`dirname $(@)`
	NAME=`basename $(lastword $^)`
	SIZE=`printf "$(@)\n" | rev | cut -f 2 -d '.' | cut -f 1 -d '_' | rev`
	svg_to_png "$$SRC_DIR" "$$DEST_DIR" "$$NAME" "$$SIZE"

##
##  PHONY targets
##

configure-build: initchk
	@:
	set -e
	if [ -z "$(TARGET)" ]; then
		printf "[Error] Please specify a build target using 'TARGET=[target]'.\n" > /dev/stderr
		exit 1
	fi

	./build/scripts/configure_build.sh --target="$(TARGET)" --pass $(PASS)

configure-system: initchk
	@:
	set -e
	./build/scripts/configure_system.sh --config="$(CONF)"

configure: initchk vendor node_modules configure-build configure-system

install: initchk
	@:
	set -e
	./build/scripts/install.sh --config="$(CONF)" --pass $(PASS)

clean: initchk
	@:
	set -e
	$(call status,rm,dist,none)
	rm -rf dist
	$(call status,rm,dep,none)
	rm -rf dep
	$(call status,rm,*.log,none)
	rm -f *.log

	for f in '__pycache__' '.sass-cache' '.mypy_cache'; do
		TMP="`find . -type d -name $$f -printf '%p '`"
		if [ ! -z "$$TMP" ]; then
			$(call status,rm,$$TMP,none)
			rm -rf $$TMP
		fi
	done

realclean: initchk clean
	@:
	set -e
	$(call status,rm,build/*.conf,none);
	rm -f build/*.conf
	$(call status,rm,build/link,none);
	rm -rf build/link
	$(call status,rm,node_modules,none);
	rm -rf node_modules
	$(call status,rm,package-lock.json,none);
	rm -f package-lock.json
	$(call status,rm,vendor,none)
	rm -rf vendor
	$(call status,rm,composer.lock,none)
	rm -f composer.lock
	$(call status,rm,server,none)
	rm -rf server
	$(call status,rm,.phpunit.result.cache,none)
	rm -f .phpunit.result.cache

	# Remove temporary nano files.
	TMP="`find . \
		\( -type d -path './node_modules/*' -prune \) \
		-o \( \
			-type f -name '*.swp' -printf '%p ' \
			-o  -type f -name '*.save' -printf '%p ' \
		\)`"
	if [ ! -z "$$TMP" ]; then
		$(call status,rm,$$TMP,none)
		rm -f $$TMP
	fi

	# Remove temporary emacs files.
	TMP="`find . \
		\( -type d -path './node_modules/*' -prune \) \
		-o \( \
			 -type f -name '\#*\#*' -printf '%p ' \
			-o -type f -name '*~' -printf '%p ' \
		\)`"
	if [ ! -z "$$TMP" ]; then
		$(call status,rm,$$TMP,none)
		rm -f $$TMP
	fi


# Count the lines of code in LibreSignage.
LOC: initchk
	@:
	set -e
	printf 'Lines Of Code: \n'
	wc -l `find . \
		\( \
			-path "./dist/*" \
			-o -path "./node_modules/*" \
			-o -path "./vendor/*" \
			-o -path "./doxygen_docs/*" \
		\) -prune \
		-o -name ".#*" -printf '' \
		-o -name 'package-lock.json' -printf '' \
		-o -name 'composer.lock.json' -printf '' \
		-o -name "Dockerfile" -print \
		-o -name "makefile" -print \
		-o -name "*.py" -print \
		-o -name "*.php" -print \
		-o -name "*.js" -print \
		-o -name "*.html" -print \
		-o -name "*.css" -print \
		-o -name "*.scss" -print \
		-o -name "*.sh" -print \
		-o -name "*.json" -print`

test-api: initchk $(PHP_AUTOLOAD)
	@:
	set -e
	printf '[Info] Running API integration tests...\n'

	if [ ! -d 'dist/' ]; then
		echo "[Error] 'dist'/ doesn't exist. Did you compile first?"
		exit 1
	fi

	sh tests/setup.sh "API"

	export PHPUNIT_API_HOST="$(PHPUNIT_API_HOST)"
	vendor/bin/phpunit $(PHPUNIT_FLAGS) $(PASS) --testsuite "API"

	sh tests/cleanup.sh "API"

doxygen-docs: initchk
	@:
	set +e

	./build/scripts/dep_checks/doxygen_version.sh $(DOXYGEN_REQ_VER)
	$(call initchk_warn,$$?)

	set -e
	doxygen Doxyfile

jsdoc-docs: initchk
	@:
	set -e
	npx jsdoc -c "$(JSDOC_CONFIG)"

initchk:
	@:
	set +e

	tmp=0
	./build/scripts/check_shell.sh
	tmp=$$(expr $$tmp + $$?)
	./build/scripts/dep_checks/npm_version.sh $(NPM_REQ_VER)
	tmp=$$(expr $$tmp + $$?)
	./build/scripts/dep_checks/composer_version.sh $(COMPOSER_REQ_VER)
	tmp=$$(expr $$tmp + $$?)
	./build/scripts/dep_checks/make_version.sh $(MAKE_REQ_VER)
	tmp=$$(expr $$tmp + $$?)
	./build/scripts/dep_checks/pandoc_version.sh $(PANDOC_REQ_VER)
	tmp=$$(expr $$tmp + $$?)
	./build/scripts/dep_checks/rsvg_version.sh $(RSVG_REQ_VER)
	tmp=$$(expr $$tmp + $$?)

	$(call initchk_warn,$$tmp)

# Include the dependency makefiles from dep/. If the files don't
# exist, they are built by running the required targets.
ifeq (,$(filter LOC clean realclean configure initchk,$(MAKECMDGOALS)))
include $(subst src,dep,$(SRC_JS:.js=.js.dep))
include $(subst src,dep,$(SRC_SCSS:.scss=.scss.dep))
endif
