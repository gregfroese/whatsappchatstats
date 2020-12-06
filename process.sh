#!/bin/bash
## TODO remove non-message lines

## cut out the beginning of the lines up to the first colon (:)
cut -d : -f 1,2 "$1" | cut -d - -f 1,2,4 > work_date_and_name.txt

## output the year and month along with name to a comma separated list
awk  -F '- ' '{print $1", "$2}' work_date_and_name.txt > work_formatted_date_and_name.txt

## remove lines that don't start with 2000+
awk '($1+0)>2000 && ($1+0) < 2100' work_formatted_date_and_name.txt > work_formatted_date_and_name_clean.txt

## get just the names
cut -d , -f 2 work_formatted_date_and_name_clean.txt | sort | uniq > work_unique_names.txt

## get the unique year-months
cut -d , -f 1 work_formatted_date_and_name_clean.txt | sort | uniq > work_unique_dates.txt

echo -n "Date" > results.csv
while read n; do
	echo -n ", $n" >> results.csv
done <work_unique_names.txt
echo >> results.csv

## loop through all the dates
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

if [ "run" = "run" ]; then
	## get the data by hour
	cut -d : -f 1,2 "$1" | cut -d " " -f 2,3,5,6 > work_time_and_name.txt
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
	echo -n "Hour" > times.csv
	while read n; do
		echo -n ", $n" >> times.csv
	done <work_unique_names.txt
	echo >> times.csv

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
fi

## works on small data sets, not the whole thing
echo "Processing search terms:"
while read s; do
	echo " - Searching for ${s}"
	grep -rin "$s" "$1" | cut -d : -f 3-10 > work_term.txt
	paste -d ":" <(cut -d , -f 1 work_term.txt | cut -d : -f 3 | cut -d - -f 1,2) <(cut -d " " -f 5,6 work_term.txt | cut -d : -f 1) > work_term_clean.txt
	## remove lines that don't start with 2000+
	awk '($1+0)>2000 && ($1+0) < 2100' work_term_clean.txt > work_term_clean2.txt

	echo -n "Date" > $s.csv
	while read n; do
		echo -n ", $n" >> $s.csv
	done <work_unique_names.txt	
	echo >> $s.csv

	while read d; do
		echo -n "$d" >> $s.csv
		## loop through all the names and count instances for the term
		while read n; do
			OUTPUT=$(grep "$d:$n" work_term_clean2.txt | wc -l)	
			echo -n ", ${OUTPUT}" >> $s.csv
		done <work_unique_names.txt
		echo >> $s.csv
	done <work_unique_dates.txt
done <search_terms.txt

## clean up work files
rm work*.txt
