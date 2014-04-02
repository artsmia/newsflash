SHELL := /usr/local/bin/bash

default: sync markdownify

mount:
	@if [ ! -d /Volumes/Design ]; then \
		mkdir /Volumes/Design; \
		mount_smbfs '//10.1.1.97/Design' /Volumes/Design; \
	fi

sync: mount
	rsync -avz /Volumes/Design/PRINT\ PUBLICATIONS/Publications\ 2014/DSN\ Design\ \&\ Editorial_14/NewsFlash_Labels/Edited\ Text/ docxs

markdownify:
	ls docxs/*doc* | while read doc; do \
      name="$${doc:6:-5}"; \
      if [ ! -f "labels/$$name.md" ]; then \
        echo $$name; \
        textutil -convert html "$$doc" -stdout | \
        ~/.cabal/bin/pandoc -r html -w markdown_github --atx-headers -o "labels/$$name.md"; \
        images=$$(unzip -l "$$doc" | grep media | awk '{print $$4}'); \
				for image in $$images; do \
						image_name="$$name-$$(echo $$image | sed 's|word/media/image||')"; \
						unzip -p "$$doc" "$$image" > "images/$$image_name"; \
						echo "" >> "labels/$$name.md"; \
						echo "![](../images/$$image_name)" >> "labels/$$name.md"; \
				done; \
		fi; \
		done
