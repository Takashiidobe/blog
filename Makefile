POSTS=$(shell ./finalized.py)
# OUT contains all names of static HTML targets corresponding to markdown files
# in the posts directory.
OUT_DIR=site
OUT=$(patsubst posts/%.md, site/gen/%.html, $(POSTS))

all: mkdirs $(OUT) site/index.html

deploy: all $(OUT_DIR)/robots.txt $(OUT_DIR)/sitemap.xml $(OUT_DIR)/rss.xml
	ntl deploy --prod

$(OUT_DIR)/gen/%.html: posts/%.md templates/post.html
	/bin/pandoc -f markdown+fenced_divs -s $< -o $@ --table-of-contents --mathjax --filter pandoc-sidenote --section-divs --template templates/post.html

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

# Shortcuts
open: all
	open site/index.html

clean:
	rm -r site

.PHONY: install
install:
	pip install -r requirements.txt

define HELP_TEXT
make                  generate site
make site/index.html  generate just index.html
make clean            Delete all generated files
make deploy           Deploys the site to production
endef

export HELP_TEXT

help:
	@echo "$$HELP_TEXT"
