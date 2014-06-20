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
	git commit -m "$$(git status -s -- labels | grep '^A' | perl -pe 's|A  labels/(.*?)_.*|\1|' | sort | sed -n '1p;$$p' | sed 's/-/\//g' | paste -sd "—" -)"

assoc:
	tail -n+3 newsflash-labels.csv | while read line; do \
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

object_ids:
	tail -n+3 newsflash-labels.csv | while read line; do \
		acc=$$(csvcut -c4 <<<$$line | sed 's/[[:space:]]*$$//; s/^[[:space:]]*//'); \
		if [ -n "$$acc" -a '""' == $$(csvcut -c5 <<<$$line) -o -z $$(csvcut -c5 <<<$$line) ]; then \
			result=$$(curl --silent "https://collections.artsmia.org/search_controller.php" -d 'page=search' --data-urlencode "query=$$acc"); \
			if egrep -q "no result" <<<$$result; then \
				echo $$acc -- no match; \
			else \
				object=$$(jq -r '.message[0]' <<<$$result | cut -d'_' -f1); \
				sed -i'.bak' "s/$$acc[ ]*,,/$$acc,$$object,/" newsflash-labels.csv; \
				echo $$acc -- $$object; \
			fi; \
		fi; \
	done

posts:
	@tail -n+3 newsflash-labels.csv | while read line; do \
		date=$$(gdate --date="$$(csvcut -c6 <<<$$line)" '+%Y-%m-%d'); \
		title=$$(csvcut -c1 <<<$$line); \
		slug=$$(echo $$title | sed -e 's/[^[:alnum:]]/-/g' | tr -s '-' | tr A-Z a-z | sed -e 's/--/-/; s/^-//; s/-$$//'); \
		id=$$(csvcut -c5 <<<$$line); \
		file="labels/$$(csvcut -c9 <<<$$line).md"; \
		post=$$date-$$slug.md; \
		if [ -f "$$file" ] && [ ! -f "_posts/$$post" ]; then \
			echo $$post; \
			echo -e "---\\nlayout: post\\n\\ntitle: $$title\\nobject: $$id\\n---" \
			| cat - "$$file" > _posts/$$post; \
		fi; \
	done
# slug thanks to http://automatthias.wordpress.com/2007/05/21/slugify-in-a-shell-script/

rsync:
	rsync -avz _site/ dx:/var/www/newsflash
