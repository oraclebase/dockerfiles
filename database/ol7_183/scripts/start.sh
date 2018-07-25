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
  ln -s /u02/config/${ORACLE_SID}/fast_recovery_area ${ORACLE_BASE}/fast_recovery_area
  rm -Rf ${ORACLE_BASE}/diag
  ln -s /u02/config/${ORACLE_SID}/diag ${ORACLE_BASE}/diag
}

echo "******************************************************************************"
echo "Create a listener.ora file if it doesn't already exist." `date`
echo "******************************************************************************"
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

echo "******************************************************************************"
echo "Check if database already exists." `date`
echo "******************************************************************************"
if [ ! -d /u02/oradata/${ORACLE_SID^^} ]; then

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

  echo "******************************************************************************"
  echo "Set the PDB to auto-start." `date`
  echo "******************************************************************************"
  sqlplus / as sysdba <<EOF
alter system set db_create_file_dest='/u02/oradata';
alter pluggable database ${PDB_NAME} save state;
alter system set local_listener='localhost';
exit;
EOF

  echo "******************************************************************************"
  echo "Store config files in case persistent volume is used." `date`
  echo "******************************************************************************"
  dbshut ${ORACLE_HOME}
  mkdir -p /u02/config/${ORACLE_SID}
    
  cp /etc/oratab /u02/config/
  echo "******************************************************************************"
  echo "Flip the auto-start flag." `date`
  echo "******************************************************************************"
  sed -i -e "s|${ORACLE_SID}:${ORACLE_HOME}:N|${ORACLE_SID}:${ORACLE_HOME}:Y|g" /u02/config/oratab
  cp -f /u02/config/oratab /etc/oratab 
    
  mv ${ORACLE_HOME}/dbs/orapw${ORACLE_SID} /u02/config/${ORACLE_SID}
  mv ${ORACLE_HOME}/dbs/spfile${ORACLE_SID}.ora /u02/config/${ORACLE_SID}
  mv ${ORACLE_BASE}/admin /u02/config/${ORACLE_SID}
  # Make sure FRA is present, in case it has not been created yet.
  mkdir -p ${ORACLE_BASE}/fast_recovery_area
  mv ${ORACLE_BASE}/fast_recovery_area /u02/config/${ORACLE_SID}
  mv ${ORACLE_BASE}/diag /u02/config/${ORACLE_SID}
  fixConfig;
  dbstart ${ORACLE_HOME}

  echo "******************************************************************************"
  echo "Install APEX." `date`
  echo "******************************************************************************"
  cd ${ORACLE_HOME}/apex

  sqlplus / as sysdba <<EOF
alter session set container = ${PDB_NAME};
create tablespace apex datafile size 1m autoextend on next 1m;
@apexins.sql APEX APEX TEMP /i/

BEGIN
    APEX_UTIL.set_security_group_id( 10 );
    
    APEX_UTIL.create_user(
        p_user_name       => 'ADMIN',
        p_email_address   => '${APEX_EMAIL}',
        p_web_password    => '${APEX_PASSWORD}',
        p_developer_privs => 'ADMIN' );
        
    APEX_UTIL.set_security_group_id( null );
    COMMIT;
END;
/

@apex_rest_config.sql ${APEX_PASSWORD} ${APEX_PASSWORD}
@apex_epg_config.sql ${ORACLE_HOME}

alter user APEX_PUBLIC_USER identified by ${APEX_PASSWORD} account unlock;

exit;
EOF

else

  echo "******************************************************************************"
  echo "The database already exists, so start it." `date`
  echo "******************************************************************************"
  fixConfig;

  dbstart $ORACLE_HOME

fi

echo "******************************************************************************"
echo "Tail the alert log file as a background process" `date`
echo "and wait on the process so script never ends." `date`
echo "******************************************************************************"
tail -f ${ORACLE_BASE}/diag/rdbms/${ORACLE_SID}/${ORACLE_SID}/trace/alert_${ORACLE_SID}.log &
bgPID=$!
wait $bgPID
