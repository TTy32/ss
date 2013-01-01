ss - Snapshot backup tool using rsync, written in bash
------------------------------------------------------

= Overview

ss operates using a user config file (.ss_config) stored in a directory, from which the ss command can be run. In technical terms ss only sources the ".ss_config" file in the directory from which ss is invoked. This config file can be created using "ss createconfig". One can then use "ss initial" to create an initial full backup. This backup is stored on the destination in a directory called "0". After the "ss initial" command is run once, one can repeatedly call "ss incremental" (using cron for example) to create incremental snapshot's (ss uses rsync's --link-dest option to create hard links). This creates directory's on the destination starting from the initial "0", so the first incremental snapshot directory will be called "1", the next one "2" etc. Use "ss list" to retrieve a listing of all the snapshots made on the destination, including dates and transfer sizes that are sed'd by this script.

ss stores the snapshot date and other info in a file called "snapshot.info" in the snapshot directory. "ss list" uses this information to create a listing.

ss stores specific (non-user config) in a file called ".ss_vars", in the same directory where ".ss_config" is stored. In this version only one variable is used to keep track of the snapshot directory numbers.

= Installation

Copy the ss bash script somewhere in your $PATH, or add it's location to your (user) $PATH. Make it executable using __chmod u+x ss__ or __chmod ugo+x ss__ and run one of the following command line options explained below.

= Command line options

== ss 

ss without any options displays all the command line options.

== ss createconfig

ss creates a default config file named __.ss_config__ in the current directory. Adjust as needed (self explainatory).

== ss list

ss produces a list of all the snapshots made in a file __list.ss__ in the current directory.

== ss initial

Create the first initial backup. This option also creates a file __.ss_vars__ used for housekeeping.

== ss incremental

Create snapshot.

= Dependencies

* GNU sed

