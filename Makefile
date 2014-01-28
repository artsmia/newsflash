SHELL := /usr/local/bin/bash

sync:
	rsync -avz /Volumes/Design/PRINT\ PUBLICATIONS/Publications\ 2014/DSN\ Design\ \&\ Editorial_14/NewsFlash_Labels/Edited\ Text/ docxs

markdownify:
	ls docxs/* | while read doc; do \
			textutil -convert html "$$doc" -stdout | \
			~/.cabal/bin/pandoc -r html -w markdown_github --atx-headers -o labels/"$${doc:6:-5}".md; \
			done
