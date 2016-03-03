SHELL := /usr/local/bin/bash

default: sync markdownify update_log

mount:
	@if [ ! -d /Volumes/Design ]; then \
		mkdir /Volumes/Design; \
		mount_smbfs '//10.1.1.97/Design' /Volumes/Design; \
	fi

sync: mount
	rsync -avz /Volumes/Design/PRINT\ PUBLICATIONS/Publications\ 2016/DSN_Design\ Editorial_16/NEWSFLASH/ docxs

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
	@echo "Great. This part is manual…"
	@echo "Check that each line added to the spreadsheet has an associated markdown file in labels/"
	@echo "\`make object_ids posts\`, enter the object ids in the spreadsheet, then \`make commit\`."

download_log:
	wget --no-check-certificate --output-document=newsflash-labels.csv "$(log)&output=csv"
	sed -i'' -e 's/\.md//' newsflash-labels.csv
	echo "" >> newsflash-labels.csv
	make stage_files_in_log

stage_files_in_log:
	cat newsflash-labels.csv | tail -250 | \
		csvcut -c9 | grep -v '""' | sed 's/"//g' | while read name; do \
			echo $$name; \
			label="labels/$$name.md"; \
			if [[ -f "$$label" ]]; then git add "$$label" "images/$$name*"; fi; \
    done
	git add newsflash-labels.csv

commit: download_log
	git commit -m "$$(git status -s -- labels | grep '^A' | perl -pe 's|A  labels/(.*?)_.*|\1|' | sort | sed -n '1p;$$p' | sed 's/-/\//g' | paste -sd "—" -)" --author="miabot <null+github@artsmia.org>"

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

backlog = 120
object_ids:
	tail -$(backlog) newsflash-labels.csv | while read line; do \
		acc=$$(csvcut -c4 <<<$$line | sed 's/[[:space:]]*$$//; s/^[[:space:]]*//; s/"//g'); \
		if [ -n "$$acc" -a '""' == $$(csvcut -c5 <<<$$line) -o -z $$(csvcut -c5 <<<$$line) ]; then \
			result=$$(curl --silent "https://search.artsmia.org/accession_number:\"$$acc\""); \
			if egrep -q "no result" <<<$$result; then \
				echo $$acc -- no match; \
			else \
				object=$$(jq -r '.hits.hits[0]._id' <<<$$result); \
				sed -i'.bak' "s/$$acc[ ]*,,/$$acc,$$object,/" newsflash-labels.csv; \
				echo $$acc -- $$object; \
			fi; \
		fi; \
	done

input = $$(tail -$(backlog) newsflash-labels.csv)
posts:
	@echo "$(input)" | while read line; do \
		date=$$(gdate --date="$$(csvcut -c6 <<<$$line)" '+%Y-%m-%d'); \
		file=labels/$$(csvcut -c9 <<<$$line | sed 's/"//'g).md; \
		if [ -f "$$file" ]; then \
			echo $$file; \
			shortTitle=$$(csvcut -c1 <<<$$line); \
			title=$$(head -1 "$$file" | sed 's/[*]//g'); \
			slug=$$(([[ -z "$$title" || `wc -c <<<$$title` -gt 100 ]] && echo $$shortTitle || echo $$title) | sed -e 's/[^[:alnum:]]/-/g' | tr -s '-' | tr A-Z a-z | sed -e 's/--/-/; s/^-//; s/-$$//'); \
			id=$$(csvcut -c5 <<<$$line); \
			post=$$date-$$slug.md; \
			if [ ! -f "_posts/$$post" ]; then \
				echo $$post; \
				image=$$(cat "$$file" | grep '../images' | head -1 | sed 's|!\[\](\.\.\(.*\))|\1|'); \
				images=$$(cat "$$file" | grep '../images' | sed 's|!\[\](\.\.\(.*\))|\1|g; s/^/- /g'); \
        echo -e "---\\nlayout: post\\ntitle: $$title\\nobject: $$id\\nimage: $$image\\nimages:\\n$$images\\n---" \
				| cat - "$$file" > _posts/$$post; \
			fi; \
		fi; \
	done
	@gsed -i'' -e 's|!\[\](\.\.|!\[\]({{siteurl.base}}|g' _posts/*; \
# slug thanks to http://automatthias.wordpress.com/2007/05/21/slugify-in-a-shell-script/

rsync:
	jekyll build
	rsync -avz --exclude=docxs _site/ dx:/var/www/newsflash
