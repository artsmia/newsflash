SHELL := /usr/local/bin/bash

sync:
	rsync -avz /Volumes/Design/PRINT\ PUBLICATIONS/Publications\ 2014/DSN\ Design\ \&\ Editorial_14/NewsFlash_Labels/Edited\ Text/ docxs

markdownify:
	ls docxs/* | while read doc; do \
			name="$${doc:6:-5}"; \
			echo $$name; \
			textutil -convert html "$$doc" -stdout | \
			~/.cabal/bin/pandoc -r html -w markdown_github --atx-headers -o "labels/$$name.md"; \
			image=$$(unzip -l "$$doc" | grep media | awk '{print $$4}' | head -1); \
			unzip -p "$$doc" "$$image" > images/$$name.jpg; \
			echo "" >> labels/$$name.md; \
			echo "![](../images/$$name.jpg)" >> labels/$$name.md; \
			done
