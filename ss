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
OPT=\"-avh --delete --password-file=file.passwd\"

# SS settings
METHOD=pull
AUTO_DELETE_SNAPSHOTS=1

" >> .ss_config

	echo "ss: Initial .ss_config created."
}

function maketemp
{
	set +e
	mkdir ./temp 2>/dev/null
	rm ./temp/* 2>/dev/null
	set -e
}

function create_symlink_latest_backup {
	# Load config
	source $PWD/.ss_config

	# Load vars
	source $PWD/.ss_vars

	maketemp

	# Create symlink to latest snapshot on destination
	ln -s ./$CONFIG_AUTO_LAST_SNAPSHOT ./temp/latest

	# Dynamically check if user is using pull or push method with rsync to provide a user supplied password file (rsync --password-file)
	if [[ $DST == *"rsync://"* && $OPT == *"--password-file"* ]]; then
		rsync --delete --recursive $OPT --links ./temp/latest $DST
	else
		rsync --delete --recursive --links ./temp/* $DST
	fi
	rm -Rf ./temp
}

function list {
	echo "ss: Retrieving snapshot info..."

	# Load config
	source $PWD/.ss_config

	# Load vars
	source $PWD/.ss_vars

	maketemp

	# Retrieve snapshot info's
	set +e
	rm $PWD/list.ss 2>/dev/null
	set -e
	for (( i=0; i<=$CONFIG_AUTO_LAST_SNAPSHOT; i++ ))
	{
		# Dynamically check if user is using pull or push method with rsync to provide a user supplied password file (rsync --password-file)
		if [[ $DST == *"rsync://"* && $OPT == *"--password-file"* ]]; then
			rsync $OPT $DST/$i/snapshot.info ./temp/info.temp
		else
			rsync $DST/$i/snapshot.info ./temp/info.temp
		fi
		echo -e -n "$i:\n" >> $PWD/list.ss
		cat ./temp/info.temp >> $PWD/list.ss
		echo "" >> $PWD/list.ss
	}

	rm -Rf ./temp

	echo ""
	echo "===================="
	echo "ss: list.ss created."
}

function lastsnapshot {
	echo "ss: Retrieving last snapshot info..."

	# Load config
	source $PWD/.ss_config

	# Load vars
	source $PWD/.ss_vars

	maketemp

	# Retrieve last snapshot
	set +e
	rm $PWD/lastsnapshot.ss 2>/dev/null
	set -e

	# Dynamically check if user is using pull or push method with rsync to provide a user supplied password file (rsync --password-file)
	if [[ $DST == *"rsync://"* && $OPT == *"--password-file"* ]]; then
		rsync $OPT $DST/$CONFIG_AUTO_LAST_SNAPSHOT/snapshot.info lastsnapshot.ss
	else
		rsync $DST/$CONFIG_AUTO_LAST_SNAPSHOT/snapshot.info lastsnapshot.ss
	fi

	rm -Rf ./temp

	echo ""
	echo "===================="
	echo "ss: lastsnapshot.ss created."
}

function initial {
	echo "ss: Creating initial (full) backup..."

	# Load config
	source $PWD/.ss_config

	maketemp

	# Transfer initial backup
	rsync $OPT $SRC $DST/0 | tee ./temp/rsync_stdout.temp

	# Transfer snapshot info for this snapshot
	touch ./temp/info.temp
	echo "Date of this snapshot: `date`" >> ./temp/info.temp
	echo "Type of this snapshot: Base" >> ./temp/info.temp
	echo -n "Data sent: " >> ./temp/info.temp
		cat ./temp/rsync_stdout.temp | sed -nr "s/sent\ ([a-zA-Z0-9\.]*?)\ bytes.*/\1/p" >> ./temp/info.temp # Sent bytes
	echo -n "Speed of transfer (bytes/sec): " >> ./temp/info.temp
		cat ./temp/rsync_stdout.temp | sed -nr "s/sent.* ([a-zA-Z0-9\.]+) [a-zA-Z0-9\/]+$/\1/p" >> ./temp/info.temp # Speed
	echo -n "Total size: " >> ./temp/info.temp
		cat ./temp/rsync_stdout.temp | sed -nr "s/total size is ([a-zA-Z0-9\.]+) .*/\1/p" >> ./temp/info.temp # Total size
	#echo "" >> ./temp/info.temp
	# Dynamically check if user is using pull or push method with rsync to provide a user supplied password file (rsync --password-file)
	if [[ $DST == *"rsync://"* && $OPT == *"--password-file"* ]]; then
		rsync $OPT ./temp/info.temp $DST/0/snapshot.info
	else
		rsync ./temp/info.temp $DST/0/snapshot.info
	fi

	# Save backup vars
	CONFIG_AUTO_LAST_SNAPSHOT="0"

	echo -n "" > $PWD/.ss_vars
	for var in CONFIG_AUTO_LAST_SNAPSHOT \
			   ; do
		declare -p $var | cut -d ' ' -f 3- >> $PWD/.ss_vars
	done

	rm -Rf ./temp

	create_symlink_latest_backup

	echo ""
	echo "========="
	echo "ss: Done."
}

function incremental {
	echo "ss: Creating snapshot..."

	WARNING=""

	# Load config
	source $PWD/.ss_config

	# Load vars
	source $PWD/.ss_vars

	maketemp

	# Increment last snapshot number
	SNAPSHOT_INCREMENT=`expr $CONFIG_AUTO_LAST_SNAPSHOT + 1`

	# Start snapshot number
	START_SNAPSHOT=`expr $CONFIG_AUTO_LAST_SNAPSHOT - 19`
    if (( $START_SNAPSHOT < 0 )); then
		START_SNAPSHOT=0
	fi


	# Check if number of past snapshots > 20 (rsync's --link-dest limitation)
	if [[ $CONFIG_AUTO_LAST_SNAPSHOT > 19 ]]; then
		if [[ $AUTO_DELETE_SNAPSHOTS == "1" && $METHOD == "pull" ]]; then
			set +e
			for (( i=0; i < $START_SNAPSHOT; i++ ))
			do
				rm -Rf $DST/$i
			done
			set -e
		else
			WARNING="WARNING: AUTO_DELETE_SNAPSHOT=0, snapshots older than 20 will not be part of new incrementals anymore"
		fi
	fi

	# Build --link-dest for all previous backups
	for (( i=$START_SNAPSHOT; i<=$CONFIG_AUTO_LAST_SNAPSHOT; i++ ))
	do
		LINKDEST+="--link-dest=../$i "
	done

	# Transfer incremental backup
	rsync -v $OPT $LINKDEST $SRC $DST/$SNAPSHOT_INCREMENT | tee ./temp/rsync_stdout.temp
	
	# Transfer snapshot info for this snapshot
	touch ./temp/info.temp
	echo "Date of this snapshot: `date`" >> ./temp/info.temp
	echo "Type of this snapshot: Incremental" >> ./temp/info.temp
	echo -n "Data sent: " >> ./temp/info.temp
		cat ./temp/rsync_stdout.temp | sed -nr "s/sent\ ([a-zA-Z0-9\.]*?)\ bytes.*/\1/p" >> ./temp/info.temp # Sent bytes
	echo -n "Speed of transfer (bytes/sec): " >> ./temp/info.temp
		cat ./temp/rsync_stdout.temp | sed -nr "s/sent.* ([a-zA-Z0-9\.]+) [a-zA-Z0-9\/]+$/\1/p" >> ./temp/info.temp # Speed
	echo -n "Total size: " >> ./temp/info.temp
		cat ./temp/rsync_stdout.temp | sed -nr "s/total size is ([a-zA-Z0-9\.]+) .*/\1/p" >> ./temp/info.temp # Total size
	#echo "" >> ./temp/info.temp
	# Dynamically check if user is using pull or push method with rsync to provide a user supplied password file (rsync --password-file)
	if [[ $DST == *"rsync://"* && $OPT == *"--password-file"* ]]; then
		rsync $OPT ./temp/info.temp $DST/$SNAPSHOT_INCREMENT/snapshot.info
	else
		rsync ./temp/info.temp $DST/$SNAPSHOT_INCREMENT/snapshot.info
	fi
	rm ./temp/rsync_stdout.temp 
	rm ./temp/info.temp

	# Save backup vars
	CONFIG_AUTO_LAST_SNAPSHOT=$SNAPSHOT_INCREMENT
	echo -n "" > $PWD/.ss_vars
	for var in CONFIG_AUTO_LAST_SNAPSHOT \
			   ; do
		declare -p $var | cut -d ' ' -f 3- >> $PWD/.ss_vars
	done

	rm -Rf ./temp

	create_symlink_latest_backup

	echo ""
	echo $WARNING
	echo "========="
	echo "ss: Done."
}

# Process command line parameters
case "$1" in
	createconfig) createconfig ;;
	list) list ;;
	lastsnapshot) lastsnapshot ;;
	initial) initial ;;
	incremental) incremental ;;

	*)
	echo -e "\nUsage: ss <parameter>\n"
	echo "Unrecognised parameter. Please provide one of the following parameters:"
	echo "    createconfig   Create initial config file (.ss_config)"
	echo "    list           List all the remote snapshots"
	echo "    lastsnapshot   List the last taken remote snapshot"
	echo "    initial        Create initial backup (full backup)"
	echo "    incremental    Create incremental backup"
	echo ""
esac

