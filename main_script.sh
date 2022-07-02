#!/bin/bash

# This is a script that will download database files from
#+ database.lichess.org and convert evaluated games into a .csv file
#+ for filtering puzzles through game notation (pgn)

DOWNLOADED_FILENAME="compressedDB"

if [ -z "$1" ]
then
	echo "Error, no positional parameters found."
	echo "Usage: `basename $"0"` [URL]"
	exit 1
fi

echo "$(date) Start downloading ""$1""..." | tee -a log.txt

wget -4 -nv --show-progress "$1" -O "$DOWNLOADED_FILENAME" &&  # Downloads the file

echo "$(date) Unpacking and processing the file..." | tee -a log.txt

# Unpacks the db directly into stdout using bzcat 

bzcat "$DOWNLOADED_FILENAME" | # Pipeline expressions in order: 1. Remove unnecessary headers 2. Captures URL from a header 3. Removes an empty line between URL 
#+ and game notation 4. Connect URL and PGN onto a single line  5. Match only computer-evaluated games  6. Remove {[annotations]} and move number for black (5... c5)
#+ 7. Squeeze multiple spaces into one 8. Delete trailing whitespace at the end of the line

sed -E -e '/^\[(Event|Date|Round|White|Black|Result|UTCDate|UTCTime|WhiteElo|BlackElo|WhiteRatingDiff|BlackRatingDiff|ECO|Opening|TimeControl|Termination).*\]/d' -e 's/^\[Site "(.*)"\]$/\1/' -e '/^$/d' | paste -d, - - | grep "eval" | sed -E -e 's/(\?\?|\?\!|\?|[0-9]+\.\.\.)//g' -e 's/\{[^\}]*\}//g' -e 's/([0-1]|1\/2)-([0-1]|1\/2)//' | tr -s ' ' | sed -E 's/[ \t]*$//' > temp_evaluated_games.csv # Writes to a temporary file, which is then appended to the main .csv file

if [ "${PIPESTATUS[0]}" -ne 0 ] # Test prevents appending to the main file in case the archive was corrupted
then
echo "$(date) Bzcat has failed..." | tee -a log.txt
echo "$(date) Deleting a temp file..." | tee -a log.txt
rm temp_evaluated_games.csv
exit 2
fi

echo "$(date) $(wc -l temp_evaluated_games.csv) games added to the database..." | tee -a log.txt

echo "$(date) Appending games to the main file..." | tee -a log.txt

cat temp_evaluated_games.csv >> evaluated_games.csv # Appends temporary file to the main db

echo "$(date) Removing temporary files..." | tee -a log.txt

rm $DOWNLOADED_FILENAME temp_evaluated_games.csv

echo "$(date) Program has finished processing ""$1""..." | tee -a log.txt

exit 0
