#!/bin/sh

# Global configuration directory. Defaults to $DEFAULT_CONFIG below, unless specified in the command line
# Files:
# -- include.lst
# List of directories/files to backup, one per line.
# -- vars
# Configuration variables for this backup task. Currently:
#   * BACKUP_HOST=username@backup_server
#   * BACKUP_PATH=path/to/the/backup
#   * PER_USER_CONFIG_DIR=path/to/config/dir
#   * AUTO_BACKUP_PER_USER_CONFIG=y
# If the PER_USER_CONFIG_DIR is specified, this directory (relative to the user's homedir) will be scanned for 
# per-user configuration options
#
# Per-user configuration directory
# -- include.lst
#   List of files/directories to back up, one per line, relative to the user's home. Entries containing ".." will be ignored.
#   To backup the whole home directory, use "/". If a per-user configuration directory is found, and the variable AUTO_BACKUP_PER_USER_CONFIG
#   contains "y", the per-user configuration dir will be added to the bakcup.
#


DEFAULT_CONFIG=/usr/local/etc/push_backup

if test -n "$1"; then
    GLOBAL_CONFIG=$1
else
    GLOBAL_CONFIG=$DEFAULT_CONFIG
fi
echo Reading main configuration from $GLOBAL_CONFIG

. $GLOBAL_CONFIG/vars

DATE=`date +%Y-%m-%d_%H%M%S`
FILE_LIST=/tmp/simple_backup.list.$$
touch $FILE_LIST
chmod og-rwx $FILE_LIST
# Truncate the file, just in case.
echo > $FILE_LIST
test -f $GLOBAL_CONFIG/include.lst && cat $GLOBAL_CONFIG/include.lst > $FILE_LIST
# Look for the configuration in the home directories
if test -n "$PER_USER_CONFIG_DIR"; then
    echo "Including home directories in the backup"
    for homedir in `cut -d: -f6 /etc/passwd`; do
       if [ "$AUTO_BACKUP_PER_USER_CONFIG"x = "y"x -a -d $homedir/$PER_USER_CONFIG_DIR ]; then
           echo $homedir/$PER_USER_CONFIG_DIR >> $FILE_LIST
       fi
       if test -f $homedir/$PER_USER_CONFIG_DIR/include.lst; then
           grep -E -v '(^\s*$)|(^\.\./)|(/\.\./)|(^\.\.$)|(^\s*#)' $homedir/$PER_USER_CONFIG_DIR/include.lst | while read entry; do
               echo $homedir/$entry >> $FILE_LIST
           done
       fi
    done 
fi

echo "Paths to sync:"
cat $FILE_LIST

# Now, rsync to the server
ssh $BACKUP_HOST "mv $BACKUP_DIR/current $BACKUP_DIR/current.prev; mkdir -p $BACKUP_DIR/current/rootfs"
#rsync --rsync-path="rsync --fake-super" -avr -x --delete --files-from=$FILE_LIST / $BACKUP_HOST:$BACKUP_DIR/current/rootfs
echo rsync -avr -x --delete --link-dest=../../current.prev/rootfs --files-from=$FILE_LIST /. $BACKUP_HOST:$BACKUP_DIR/current/rootfs
rsync -avr -x --link-dest=../../current.prev/rootfs --files-from=$FILE_LIST /. $BACKUP_HOST:$BACKUP_DIR/current/rootfs
# Take the snapshot
ssh $BACKUP_HOST mkdir -p $BACKUP_DIR/snapshots/
ssh $BACKUP_HOST cp -al $BACKUP_DIR/current/ $BACKUP_DIR/snapshots/$DATE
ssh $BACKUP_HOST rm -rf $BACKUP_DIR/current.prev

#rm $FILE_LIST

# TODO: because we are copying to another system, the users and groups will not be preserved. We should
# copy the names and permissions of every copied file to a text file in the backup.
# If I get the list of files, we can use this to get the stats. I need to figure out how to get that list
# of files.
      #xargs stat  -c "%a %U:%G %h/%i | %n" #| 
      #ssh $BACKUP_HOST "cat > $BACKUP_DIR/current/filestats"


