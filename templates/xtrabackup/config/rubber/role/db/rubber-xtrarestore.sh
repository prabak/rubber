<%
  @path = "#{rubber_env.mount_directory}/db-backup-tools/rubber-xtrarestore.sh"
	@perms = 0755
	@backup = false
%>#!/bin/bash
# Variables
LOGFILE="/tmp/rubber-xtrarestore-log"
# Take the file from STDIN, write it into a real file, extract it, service mysql stop,
# then mkdir <%=rubber_env.mount_directory%>/mysql/data & <%=rubber_env.mount_directory%>/mysql/log (move old ones out of the way)
# then innobackupex --copy-back . in the extracted folder, then service mysql start
# Create a temporary folder
rm -rf <%=rubber_env.mount_directory%>/db_restore
mkdir -p <%=rubber_env.mount_directory%>/db_restore
# Write STDIN into file
cat > <%=rubber_env.mount_directory%>/db_restore/current.tar.gz
cd <%=rubber_env.mount_directory%>/db_restore
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