<%
  @path = "#{rubber_env.mount_directory}/db-backup-tools/rubber-xtrarestore.sh"
	@perms = 0755
	@backup = false
%>#!/bin/bash
# Variables
LOGFILE="/tmp/rubber-xtrarestore-log"

# the buckets on S3 where database backups are stored
BACKUP_BUCKET="<%=rubber_env.cloud_providers.aws.backup_bucket%>"

# Lets get our command line parameter
while getopts ":u:p:t:db:" opt; do
  case $opt in
    t)
      BACKUPFILE="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

if [[ -z "$BACKUPFILE" ]]; then
  echo "Required parameters missing. Please supply -t (backup file to use to restore database)"
  exit 1
fi

# Take the filename from STDIN and download it from amazon s3

rm -rf <%=rubber_env.mount_directory%>/db_restore
mkdir -p <%=rubber_env.mount_directory%>/db_restore
cd <%=rubber_env.mount_directory%>/db_restore

# Download file from amazon s3
#cat > /mnt/archon/db_restore/current.tar.gz
s3cmd get s3://logix.cz-test/addrbook.xml addressbook-2.xml
s3cmd get --config="<%=rubber_env.mount_directory%>/archon/db-backup-tools/rubber-s3cmd.s3cfg" "s3://$BACKUP_BUCKET/db/$BACKUPFILE" "current.tar.gz"

# extract the downloaded file, service mysql stop,
# then mkdir /mnt/archon/mysql/data & /mnt/archon/mysql/log (move old ones out of the way)
# then innobackupex --copy-back . in the extracted folder, then service mysql start
# Create a temporary folder

tar xzvf current.tar.gz
echo 'Stopping MySQL'
if [ -z "`service mysql stop | grep 'done'`" ] ; then
	echo "ERROR: Couldn't stop mysql daemon."
	exit 1
fi
rm -rf <%=rubber_env.mount_directory%>/mysql/old
mkdir -p <%=rubber_env.mount_directory%>/mysql/old
echo 'Moving Data/Log Directories to /old'
mv <%=rubber_env.mount_directory%>/mysql/data <%=rubber_env.mount_directory%>/mysql/log <%=rubber_env.mount_directory%>/mysql/old
mkdir <%=rubber_env.mount_directory%>/mysql/data <%=rubber_env.mount_directory%>/mysql/log
echo 'Copying back'
innobackupex --copy-back . 2> $LOGFILE
if [ -z "`tail -1 $LOGFILE | grep 'completed OK!'`" ] ; then
	echo "ERROR: Innobackupex couldn't copy back."
	exit 1
fi
chown -R mysql.mysql <%=rubber_env.mount_directory%>/mysql/data
chown -R mysql.mysql <%=rubber_env.mount_directory%>/mysql/log
echo 'Starting MySQL'
if [ -z "`service mysql start | grep 'done'`" ] ; then
	echo "ERROR: Couldn't start mysql daemon."
	exit 1
fi
echo 'Cleaning up'
rm -rf <%=rubber_env.mount_directory%>/mysql/old
rm -rf <%=rubber_env.mount_directory%>/db_restore
echo "Success."
exit 0