#!/usr/bin/env bash

# 'Free' error checking
set -e

# Set pwd
PWD=`pwd`

function createconfig {
	echo -e "\
# Source
SRC=./files/*

# Destination (without trailing slash)
DST=rsync://user@host/module/dir

# Options
OPT=\"-avh --delete --password-file=file.passwd\"" >> .ss_config

	echo "ss: Initial .ss_config created."
}

function list {
	echo "ss: Retrieving snapshot info..."

	# Load config
	source $PWD/.ss_config

	# Load backup vars
	source $PWD/.ss_vars

	# Retrieve snapshot info's
	set +e
	rm $PWD/list.ss 2>/dev/null
	set -e
	for (( i=0; i<=$CONFIG_AUTO_LAST_SNAPSHOT; i++ ))
	{
		rsync $DST/$i/snapshot.info info.temp
		echo -e -n "$i:\n" >> $PWD/list.ss
		cat info.temp >> $PWD/list.ss
		rm info.temp
		echo "" >> $PWD/list.ss
	}
	echo ""
	echo "===================="
	echo "ss: list.ss created."
}

function initial {
	echo "ss: Creating initial (full) backup..."

	# Load config
	source $PWD/.ss_config

	# Transfer initial backup
	rsync $OPT $SRC $DST/0 | tee rsync_stdout.temp

	# Transfer snapshot info for this snapshot
	touch info.temp
	echo "Date of this snapshot: `date`" >> info.temp
	echo "Type of this snapshot: Base" >> info.temp
	echo -n "Data sent: " >> info.temp
		cat rsync_stdout.temp | sed -nr "s/sent\ ([a-zA-Z0-9\.]*?)\ bytes.*/\1/p" >> info.temp # Sent bytes
	echo -n "Speed of transfer (bytes/sec): " >> info.temp
		cat rsync_stdout.temp | sed -nr "s/sent.* ([a-zA-Z0-9\.]+) [a-zA-Z0-9\/]+$/\1/p" >> info.temp # Speed
	echo -n "Total size: " >> info.temp
		cat rsync_stdout.temp | sed -nr "s/total size is ([a-zA-Z0-9\.]+) .*/\1/p" >> info.temp # Total size
	#echo "" >> info.temp
	rsync info.temp $DST/0/snapshot.info
	rm rsync_stdout.temp 
	rm info.temp

	# Save backup vars
	CONFIG_AUTO_LAST_SNAPSHOT="0"

	echo -n "" > $PWD/.ss_vars
	for var in CONFIG_AUTO_LAST_SNAPSHOT \
			   ; do
		declare -p $var | cut -d ' ' -f 3- >> $PWD/.ss_vars
	done

	echo ""
	echo "========="
	echo "ss: Done."
}

function incremental {
	echo "ss: Creating snapshot..."

	# Load config
	source $PWD/.ss_config

	# Load backup vars
	source $PWD/.ss_vars

	# Increment last snapshot number
	SNAPSHOT_INCREMENT=`expr $CONFIG_AUTO_LAST_SNAPSHOT + 1`

	# Build --link-dest for all previous backups
	for (( i=0; i<=$CONFIG_AUTO_LAST_SNAPSHOT; i++ ))
	do
		LINKDEST+="--link-dest=../$i "
	done

	# Transfer incremental backup
	rsync -v $OPT $LINKDEST $SRC $DST/$SNAPSHOT_INCREMENT | tee rsync_stdout.temp
	
	# Transfer snapshot info for this snapshot
	touch info.temp
	echo "Date of this snapshot: `date`" >> info.temp
	echo "Type of this snapshot: Incremental" >> info.temp
	echo -n "Data sent: " >> info.temp
		cat rsync_stdout.temp | sed -nr "s/sent\ ([a-zA-Z0-9\.]*?)\ bytes.*/\1/p" >> info.temp # Sent bytes
	echo -n "Speed of transfer (bytes/sec): " >> info.temp
		cat rsync_stdout.temp | sed -nr "s/sent.* ([a-zA-Z0-9\.]+) [a-zA-Z0-9\/]+$/\1/p" >> info.temp # Speed
	echo -n "Total size: " >> info.temp
		cat rsync_stdout.temp | sed -nr "s/total size is ([a-zA-Z0-9\.]+) .*/\1/p" >> info.temp # Total size
	#echo "" >> info.temp
	rsync info.temp $DST/$SNAPSHOT_INCREMENT/snapshot.info
	rm rsync_stdout.temp 
	rm info.temp

	# Save backup vars
	CONFIG_AUTO_LAST_SNAPSHOT=$SNAPSHOT_INCREMENT
	echo -n "" > $PWD/.ss_vars
	for var in CONFIG_AUTO_LAST_SNAPSHOT \
			   ; do
		declare -p $var | cut -d ' ' -f 3- >> $PWD/.ss_vars
	done

	echo ""
	echo "========="
	echo "ss: Done."
}

# Process command line parameters
case "$1" in
	createconfig) createconfig ;;
	list) list ;;
	initial) initial ;;
	incremental) incremental ;;

	*)
	echo -e "\nUsage: ss <parameter>\n"
	echo "Unrecognised parameter. Please provide one of the following parameters:"
	echo "    createconfig   Create initial config file (.ss_config)"
	echo "    list           List all the remote snapshots and their dates"
	echo "    initial        Create initial backup (full backup)"
	echo "    incremental    Create incremental backup"
	echo ""
esac

