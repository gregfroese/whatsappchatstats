#!/bin/bash
## TODO remove non-message lines

function clean_up {
	## clean up work files
	rm work*.txt
}

function show_help_instructions {
	echo "Usage: ./process.sh -s|--source FILENAME [-t|--times] [-k|--keyword_file FILENAME]"
	exit
}

function handle_args {
	if [ "$show_help" = "1" ]; then
		show_help_instructions
		exit 1
	fi
	if [ "$source" = "" ]; then
		show_help_instructions
		exit 1
	fi
}

function setup_headers {
	echo -n "$2" > "$1"
	while read n; do
		echo -n ", $n" >> "$1"
	done <work_unique_names.txt
	echo >> "$1"
}

keyword_file="search_terms.txt"
while [[ "$#" -gt 0 ]]; do
	case $1 in
		-s|--source) source="$2"; shift ;;
		-h|--help) show_help=1 ;;
		-t|--times) times=1 ;;
		-k|--keyword_file) keyword_file="$2"; shift ;;
		*) echo "Unknown parameter passed: $1"; exit 1 ;;
	esac
	shift
done

function initial_setup {
	## cut out the beginning of the lines up to the first colon (:)
	cut -d : -f 1,2 "$source" | cut -d - -f 1,2,4 > work_date_and_name.txt

	## output the year and month along with name to a comma separated list
	awk  -F '- ' '{print $1", "$2}' work_date_and_name.txt > work_formatted_date_and_name.txt

	## remove lines that don't start with 2000+
	awk '($1+0)>2000 && ($1+0) < 2100' work_formatted_date_and_name.txt > work_formatted_date_and_name_clean.txt

	## get just the names
	cut -d , -f 2 work_formatted_date_and_name_clean.txt | sort | uniq > work_unique_names.txt

	## get the unique year-months
	cut -d , -f 1 work_formatted_date_and_name_clean.txt | sort | uniq > work_unique_dates.txt
}

function process_messages {
	setup_headers results.csv "Date"

	## loop through all the dates and count messages per user per month
	while read d; do
		echo "Processing $d...."
		echo -n "$d" >> results.csv
		## loop through all the names and count instances for the date range
		while read n; do
			OUTPUT=$(grep "$d, $n" work_formatted_date_and_name_clean.txt | wc -l)	
			echo -n ", ${OUTPUT}" >> results.csv
		done <work_unique_names.txt
		echo >> results.csv
	done <work_unique_dates.txt
}

function process_times {
	## get the data by hour
	cut -d : -f 1,2 "$source" | cut -d " " -f 2,3,5,6 > work_time_and_name.txt
	awk '($1+0) > 0 && ($1+0) < 13' work_time_and_name.txt > work_time_and_name_clean.txt

	echo -n "Processing times"
	COUNTER=0
	echo "" > work_times.txt
	while read t; do
		echo "$t" > work_line.txt
		HOUR=$(cut -d : -f 1 work_line.txt)
		AMPM=$(cut -d " " -f 2 work_line.txt)
		NAME=$(cut -d " " -f 3,4 work_line.txt)
		#echo "${HOUR} $AMPM"

		if [ "$AMPM" = "a.m." ]; then
			## reducing HOUR by 1 to make it in central time and also 24hr
			HOUR=$((HOUR-1))
		fi
		if [ "$AMPM" = "p.m." ]; then
			## reducing HOUR by 1 to make it in central time
			HOUR=$((HOUR-1))
			## add 12 hours to make it 24 hr time
			HOUR=$((HOUR+12))
		fi

		echo "${HOUR}, ${NAME}" >> work_times.txt
		COUNTER=$((COUNTER+1))
		if [ $(( $COUNTER % 100 )) -eq 0 ] ; then
			echo -n "."
		fi
	done <work_time_and_name_clean.txt
	echo

	echo "Counting messages by hour and name"
	setup_headers "times.csv" "Hour"

	HOUR=0
	echo -n "Processing time data: "
	while ((HOUR < 24)); do
		echo -n "${HOUR}" >> times.csv
		echo -n "${HOUR} "

		while read n; do
			COUNT=$(grep ^"$HOUR, $n" work_times.txt | wc -l)
			echo -n ", ${COUNT}" >> times.csv
		done <work_unique_names.txt
		echo >> times.csv

		HOUR=$((HOUR+1))
	done
	echo
}

function process_search {
	echo "Processing search terms:"
	while read s; do
		echo " - Searching for ${s}"
		grep -rin "$s" "$source" | cut -d : -f 3-10 > work_term.txt
		paste -d ":" <(cut -d , -f 1 work_term.txt | cut -d : -f 3 | cut -d - -f 1,2) <(cut -d " " -f 5,6 work_term.txt | cut -d : -f 1) > work_term_clean.txt
		## remove lines that don't start with 2000+
		awk '($1+0)>2000 && ($1+0) < 2100' work_term_clean.txt > work_term_clean2.txt

		setup_headers "${s}.csv" "Date"

		while read d; do
			echo -n "$d" >> $s.csv
			## loop through all the names and count instances for the term
			while read n; do
				OUTPUT=$(grep "$d:$n" work_term_clean2.txt | wc -l)	
				echo -n ", ${OUTPUT}" >> $s.csv
			done <work_unique_names.txt
			echo >> $s.csv
		done <work_unique_dates.txt
	done <$keyword_file
}

handle_args
initial_setup
process_messages

if [ "$times" = "1" ]; then
	process_times
fi

if test -f "$keyword_file"; then
	process_search
else
	echo "Search terms file $keyword_file does not exist.  Not searching for terms"
	show_help_instructions
fi

clean_up
