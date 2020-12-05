#!/bin/bash
## cut out the beginning of the lines up to the first colon (:)
cut -d : -f 1,2 "$1" | cut -d - -f 1,2,4 > date_and_name.txt

## output the year and month along with name to a comma separated list
awk  -F '- ' '{print $1", "$2}' date_and_name.txt > formatted_date_and_name.txt

## remove lines that don't start with 2000+
awk '($1+0)>2000 && ($1+0) < 2100' formatted_date_and_name.txt > formatted_date_and_name_clean.txt

## get just the names
cut -d , -f 2 formatted_date_and_name_clean.txt | sort | uniq > unique_names.txt

## get the unique year-months
cut -d , -f 1 formatted_date_and_name_clean.txt | sort | uniq > unique_dates.txt

echo -n "Date" > results.csv
while read n; do
	echo -n ", $n" >> results.csv
done <unique_names.txt
echo >> results.csv

## loop through all the dates
while read d; do
	echo "Processing $d...."
	echo -n "$d" >> results.csv
	## loop through all the names and count instances for the date range
	while read n; do
		OUTPUT=$(grep "$d, $n" formatted_date_and_name_clean.txt | wc -l)	
		echo -n ", ${OUTPUT}" >> results.csv
	done <unique_names.txt
	echo >> results.csv
done <unique_dates.txt

## get the data by hour
cut -d : -f 1,2 "$1" | cut -d " " -f 2,3,5,6 > time_and_name.txt
awk '($1+0) > 0 && ($1+0) < 13' time_and_name.txt > time_and_name_clean.txt

echo -n "Processing times"
COUNTER=0
echo "" > times.txt
while read t; do
	echo "$t" > line.txt
	HOUR=$(cut -d : -f 1 line.txt)
	AMPM=$(cut -d " " -f 2 line.txt)
	NAME=$(cut -d " " -f 3,4 line.txt)
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

	echo "${HOUR}, ${NAME}" >> times.txt
	COUNTER=$((COUNTER+1))
	if [ $(( $COUNTER % 100 )) -eq 0 ] ; then
		echo -n "."
	fi
done <time_and_name_clean.txt
echo

echo "Counting messages by hour and name"
echo -n "Hour" > times.csv
while read n; do
	echo -n ", $n" >> times.csv
done <unique_names.txt
echo >> times.csv

HOUR=0
echo -n "Processing time data hour ${HOUR}: "
while ((HOUR < 24)); do
	echo -n "${HOUR}" >> times.csv
	echo -n "${HOUR} "

	while read n; do
		COUNT=$(grep ^"$HOUR, $n" times.txt | wc -l)
		echo -n ", ${COUNT}" >> times.csv
	done <unique_names.txt
	echo >> times.csv

	HOUR=$((HOUR+1))
done
echo

## clean up work files
rm date_and_name.txt formatted_date_and_name.txt formatted_date_and_name_clean.txt unique_names.txt unique_dates.txt time_and_name.txt time_and_name_clean.txt times.txt line.txt
