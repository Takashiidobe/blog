POSTS=$(shell ./finalized.py)
# OUT contains all names of static HTML targets corresponding to markdown files
# in the posts directory.
OUT_DIR=site
OUT=$(patsubst posts/%.md, site/gen/%.html, $(POSTS))
PREVIEW_DIR=preview
PREVIEW_OUT=$(patsubst posts/%.md, $(PREVIEW_DIR)/gen/%.html, $(wildcard posts/*.md))
PANDOC_FLAGS=-f markdown+fenced_divs -s --table-of-contents --mathjax --lua-filter ~/.local/share/pandoc/filters/pandoc-sidenote.lua --lua-filter bin/table-wrap.lua --section-divs --template templates/post.html

all: mkdirs $(OUT) site/index.html

deploy: all $(OUT_DIR)/robots.txt $(OUT_DIR)/sitemap.xml $(OUT_DIR)/rss.xml

$(OUT_DIR)/gen/%.html: posts/%.md templates/post.html bin/build_post.py bin/table-wrap.lua
	./bin/build_post.py $< $@ $(PANDOC_FLAGS)

$(PREVIEW_DIR)/gen/%.html: posts/%.md templates/post.html bin/build_post.py bin/table-wrap.lua
	@mkdir -p $(PREVIEW_DIR)/gen
	INCLUDE_DRAFTS=1 ./bin/build_post.py $< $@ $(PANDOC_FLAGS)

# Adds each post as a prerequisite of just its adjacent (older/newer) posts'
# targets, so adding/editing one post only rebuilds the neighbors whose
# prev/next arrow it affects, not the whole site.
$(OUT_DIR)/.deps.mk: bin/gen_deps.py $(POSTS)
	@mkdir -p $(OUT_DIR)
	./bin/gen_deps.py > $@

-include $(OUT_DIR)/.deps.mk

$(OUT_DIR)/index.html: $(OUT) make_index.py templates/index.html
	python3 make_index.py
	pandoc -s index.md -o site/index.html --template templates/index.html --metadata title="Takashi's Blog"
	rm index.md

$(OUT_DIR)/robots.txt:
	@echo "User-agent: *" > $@
	@echo "Allow: *" >> $@
	@echo "Sitemap: $(BASE_URL)/sitemap.xml" >> $@

$(OUT_DIR)/sitemap.xml: $(OUT)
	./bin/sitemap.py > site/sitemap.xml

$(OUT_DIR)/rss.xml: $(OUT)
	./bin/rss.sh

.PHONY: mkdirs
mkdirs:
	mkdir -p site/gen
	cp -r assets site
	cp templates/*.css site

# Builds every post, drafts included, into preview/ (never deployed)
preview: $(PREVIEW_OUT)
	cp -r assets $(PREVIEW_DIR)
	cp templates/*.css $(PREVIEW_DIR)

# Shortcuts
open: all
	open site/index.html

clean:
	rm -rf site $(PREVIEW_DIR)

.PHONY: install preview
install:
	pip install -r requirements.txt

define HELP_TEXT
make                  generate site
make site/index.html  generate just index.html
make clean            Delete all generated files
make deploy           Deploys the site to production
make preview          generate all posts, drafts included, into preview/
endef

export HELP_TEXT

help:
	@echo "$$HELP_TEXT"
