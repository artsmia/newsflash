SHELL := /usr/local/bin/bash

default: sync markdownify update_log

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

log=https://docs.google.com/a/artsmia.org/spreadsheet/ccc?key=0AkKauoZFdwf9dHVPa1J6OTJlZEVnY1lVMEF6SlVlSUE&usp=drive_web

update_log: download_log
	@open '$(log)'
	@echo "Update the log then \`make commit\`"

download_log:
	wget --no-check-certificate --output-document=newsflash-labels.csv "$(log)&output=csv"
	echo "" >> newsflash-labels.csv
	make stage_files_in_log

stage_files_in_log:
	cat newsflash-labels.csv | tail -10 | \
		csvcut -c9 | grep -v '""' | \
		while read name; do echo $$name; git add "labels/$$name.md" "images/$$name*"; done
	git add newsflash-labels.csv

commit: download_log
	make stage_files_in_log
	git commit -m "$$(git status -s -- labels | grep '^A' | perl -pe 's|A  labels/(.*?)_.*|\1|' | sort | sed -n '1p;$$p' | sed 's/-/\//g' | paste -sd "—" -)"

assoc:
	sed 1d newsflash-labels.csv | while read line; do \
		file=$$(echo $$line | csvcut -c 9); \
		if [ '""' == "$$file" ]; then \
			echo $$(tput setaf 1) $$line $$(tput sgr0); \
			terms=$$(echo $$line | csvcut -c 1); \
			author=$$(echo $$line | csvcut -c 2 | cut -d' ' -f2); \
			for term in $$terms; do \
				echo $$(tput setaf 2) $$term $$(tput sgr0); \
				mdfind "$$term AND $$author" -onlyin labels/; \
			done; \
			echo; \
		fi; \
	done
