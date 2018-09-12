#!/bin/bash

# Field constants
IP=1
HTTP_CODE=9
BYTES=10

function showHelp() {
		cat << EOF
${0} [-n N] (-c|-2|-r|-F|-t|-f) <filename>
	-n: Limit the number of results to N
	-c: Which IP address makes the most number of connection attempts?
	-2: Which address makes the most number of successful attempts?
	-r: What are the most common results codes and where do they come from?
	-F: What are the most common result codes that indicate failure (no auth, not found etc) and where do they come from?
	-t: Which IP number get the most bytes sent to them?
	<filename> refers to the logfile. If ’-’ is given as a filename, or no filename is given, then standard input should be read. This enables the script to be used in a pipeline.
EOF
}


# $1 File
function getFileData() {
		cat $1
}

# $1 Fields wanted
function filterOutData() {
		cut -d' ' -f$1
}


# $1 Rows wanted
function limitOutput() {
		if [ $1 == -1 ]; then
				cat
		else
				head -n$1
		fi
}

file="-"
mode=help
resultLimit=-1

# Process the arguments
while getopts n:c2rFt arg
do
		case $arg in
				n)
						resultLimit="$OPTARG"
				;;
				c) mode="c"	;;
				2) mode="2"	;;
				r) mode="r"	;;
				F) mode="F"	;;
				t) mode="t"	;;
				?)
				showHelp
				exit -2;;
		 esac
done

# Remove the processed arguments
shift $(($OPTIND - 1))

# Get the filename, incase it exist
if [ $1 ]; then
		file=$1
		shift 1
fi

# Too many arguments
if [ -z $# ]; then
		echo "TOO MANY ARGS $#: $*"
		#showHelp
		exit -1
fi

if [ $mode == "help" ]; then
		getFileData
		exit 0
elif [ $mode == "c" ]; then
		# Task: Which IP address makes the most number of connection attempts?
		# Output: xxx.xxx.xxx.xxx yyy, where yyy is the number of connection attempts

		printf "%-15s  %8s\n" "IP" "Attempts"
		getFileData $file | filterOutData "$IP" | # Get only IP
				sort | uniq -c | # Count the repeated IPs
				sort -nr | # Biggest number first
				limitOutput $resultLimit | # Limit the output according to -n <number>
				awk '{ printf "%-15s  %8s\n", $2, $1}' # Format the output
elif [ $mode == "2" ]; then
		# Task: Which address makes the most number of successful attempts?
		# Output: xxx.xxx.xxx.xxx yyy, where yyy is the number of successful attempts

		printf "%-15s  %8s\n" "IP" "Attempts"
		getFileData $file | filterOutData "$IP,$HTTP_CODE" | # Get both IP and http code
				grep " [123][0-9]\{2\}" | # Get only http status codes that are inside of 1xx, 2xx and 3xx
				cut -d' ' -f1 | # Remove the http code
				sort | uniq -c | # Count the repeated IPs
				sort -nr | # Biggest number first
				limitOutput $resultLimit | # Limit the output according to -n <number>
				awk '{ printf "%-15s  %8s\n", $2, $1 }' # Format the output
elif [ $mode == "r" ]; then
		# Task: What are the most common results codes and where do they come from?
		#   You are allowed to output multiple lines with the same result code or count, but groups must be sorted
		#   There should still only be one ip address per line.
		# Output: yyyy xxx.xxx.xxx.xxx, where yyy is the result code, one ip per line

		printf "%4s  %-15s  %5s\n" "Code" "IP" "Count"
		getFileData $file | filterOutData "$IP,$HTTP_CODE" | # Get both IP and http code
				awk '{ print $2, $1 }' | # Flip IP and HTTP Code location
				sort | uniq -c -f 1 | # Count and uniq by IPs
				sort -k2,2n -k1,1rn | # Sort by http code and then by count
				limitOutput $resultLimit | # Limit the output according to -n <number>
				awk '{ printf "%4s  %-15s  %5s\n", $2, $3, $1 }' # Format the output
elif [ $mode == "F" ]; then
		# Task: What are the most common result codes that indicate failure (no auth, not found etc) and where do they come from?
		# Output: yyyy xxx.xxx.xxx.xxx, where yyy is the result code indicating failure, one ip per line

		printf "%4s  %-15s  %5s\n" "Code" "IP" "Count"
		getFileData $file | filterOutData "$IP,$HTTP_CODE" | # Get both IP and http code
				grep " [45][0-9]\{2\}" | # Get only entries that have status code 4xx or 5xx
				awk '{ print $2, $1 }' | # Flip IP and HTTP Code location
				sort | uniq -c -f 1 | # Count and uniq by IPs
				sort -k2,2n -k1,1rn | # Sort by http code and then by count
				limitOutput $resultLimit | # Limit the output according to -n <number>
				awk '{ printf "%4s  %-15s  %5s\n", $2, $3, $1 }' # Format the output
elif [ $mode == "t" ]; then
		# Task: Which IP number get the most bytes sent to them?
		# Output: xxx.xxx.xxx.xxx yyy, where yyy is the number of bytes sent from the server

		printf "%-15s  %10s\n" "IP" "Bytes"
		getFileData $file | filterOutData "$IP,$BYTES" | # Get both IP and totaly bytes sent
				grep -v -- - | # Remove log entries that don't have a size (where size is '-')
				awk '
						{
								byteSum[$1] += $2
						}
						END {
								for (ip in byteSum)
										printf "%-15s  %10s\n", ip, byteSum[ip]
						}' |
				# The first awk block will add the bytes sent to the map entry for that IP
				# The END awk block will pretty print each entry inside the map
				sort -k2,2rn | # Sort by the bytes sent
				limitOutput $resultLimit # Limit the output according to -n <number>
else
		showHelp
		exit -1
fi
