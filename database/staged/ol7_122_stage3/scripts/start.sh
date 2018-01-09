# Handle shutdowns
# docker stop --time=30 {container}
function gracefulshutdown {
  dbshut $ORACLE_HOME
}

trap gracefulshutdown SIGINT
trap gracefulshutdown SIGTERM
trap gracefulshutdown SIGKILL

# Fixes the config using the contents of the volume.
# Necessary when using persistent volume as "rm" and "run" will reset the config
# under the ORACLE_HOME.
function fixConfig {
  cp -f /u02/config/oratab /etc/oratab 
  ln -s /u02/config/${ORACLE_SID}/orapw${ORACLE_SID} ${ORACLE_HOME}/dbs/orapw${ORACLE_SID}
  ln -s /u02/config/${ORACLE_SID}/spfile${ORACLE_SID}.ora ${ORACLE_HOME}/dbs/spfile${ORACLE_SID}.ora
  ln -s /u02/config/${ORACLE_SID}/admin ${ORACLE_BASE}/admin
  rm -Rf ${ORACLE_BASE}/diag
  ln -s /u02/config/${ORACLE_SID}/diag ${ORACLE_BASE}/diag
}

# Create a listener.ora file if it doesn't already exist.
if [ ! -f ${ORACLE_HOME}/network/admin/listener.ora ]; then
echo "LISTENER = 
(DESCRIPTION_LIST = 
  (DESCRIPTION = 
    (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1)) 
    (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521)) 
  ) 
) 
USE_SID_AS_SERVICE_listener=on
" > ${ORACLE_HOME}/network/admin/listener.ora
fi

# Check if database already exists.
if [ ! -d /u02/oradata/${ORACLE_SID} ]; then

  # The database files don't exist, so create a new database.
  lsnrctl start

  dbca -silent -createDatabase                                                 \
    -templateName General_Purpose.dbc                                          \
    -gdbname ${ORACLE_SID} -sid ${ORACLE_SID} -responseFile NO_VALUE           \
    -characterSet AL32UTF8                                                     \
    -sysPassword ${SYS_PASSWORD}                                               \
    -systemPassword ${SYS_PASSWORD}                                            \
    -createAsContainerDatabase true                                            \
    -numberOfPDBs 1                                                            \
    -pdbName ${PDB_NAME}                                                       \
    -pdbAdminPassword ${PDB_PASSWORD}                                          \
    -databaseType MULTIPURPOSE                                                 \
    -automaticMemoryManagement false                                           \
    -totalMemory 1536                                                          \
    -storageType FS                                                            \
    -datafileDestination "/u02/oradata/"                                       \
    -redoLogFileSize 50                                                        \
    -emConfiguration NONE                                                      \
    -ignorePreReqs

  # Set the PDB to auto-start.
  sqlplus / as sysdba <<EOF
alter pluggable database ${PDB_NAME} save state;
exit;
EOF

  # Store config files in case persistent volume is used.
  mkdir -p /u02/config/${ORACLE_SID}
    
  cp /etc/oratab /u02/config/
  # Flip the auto-start flag.
  sed -i -e "s|${ORACLE_SID}:${ORACLE_HOME}:N|${ORACLE_SID}:${ORACLE_HOME}:Y|g" /u02/config/oratab
  cp -f /u02/config/oratab /etc/oratab 
    
  mv ${ORACLE_HOME}/dbs/orapw${ORACLE_SID} /u02/config/${ORACLE_SID}
  mv ${ORACLE_HOME}/dbs/spfile${ORACLE_SID}.ora /u02/config/${ORACLE_SID}
  mv ${ORACLE_BASE}/admin /u02/config/${ORACLE_SID}
  mv ${ORACLE_BASE}/diag /u02/config/${ORACLE_SID}
  fixConfig;

else

  # The database already exists, so start it.
  fixConfig;

  dbstart $ORACLE_HOME

fi

# Tail the alert log file as a background process
# and wait on the process so script never ends.
tail -f ${ORACLE_BASE}/diag/rdbms/${ORACLE_SID}/${ORACLE_SID}/trace/alert_${ORACLE_SID}.log &
bgPID=$!
wait $bgPID
