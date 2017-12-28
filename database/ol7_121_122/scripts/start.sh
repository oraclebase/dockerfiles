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

# Startup 12.1 database,
fixConfig;
dbstart $ORACLE_HOME

# Prepare for the preupgrade checks.
sqlplus / as sysdba <<EOF
purge dba_recyclebin;
exec dbms_stats.gather_dictionary_stats;
@?/rdbms/admin/utlrp.sql
alter session set container = ${PDB_NAME};
purge dba_recyclebin;
exec dbms_stats.gather_dictionary_stats;
@?/rdbms/admin/utlrp.sql
EXIT;
EOF

# Run the preupgrade checks. There shouldn't be any failures in this example.
$ORACLE_HOME/jdk/bin/java -jar ${ORACLE_HOME_2}/rdbms/admin/preupgrade.jar TERMINAL TEXT -c "${PDB_NAME}"

# Get the uppercase version of the PDB name.
export PDB_NAME_UPPER=`echo ${PDB_NAME} | tr /a-z/ /A-Z/`

# There shouldn't be any fixups, but just in case.
sqlplus / as sysdba <<EOF
alter session set container=${PDB_NAME};
@/u01/app/oracle/cfgtoollogs/c/preupgrade/preupgrade_fixups.sql
EXIT;
EOF

# Unplug the PDB.
mkdir -p /u02/config/${ORACLE_SID}/unplug
sqlplus / as sysdba <<EOF
ALTER PLUGGABLE DATABASE ${PDB_NAME} CLOSE;
ALTER PLUGGABLE DATABASE ${PDB_NAME} UNPLUG INTO '/u02/config/${ORACLE_SID}/unplug/${PDB_NAME}.xml';
EXIT;
EOF

# Zip the files to keep them safe.
cat /u02/config/${ORACLE_SID}/unplug/${PDB_NAME}.xml | grep path | sed -e 's/<[^>]*>//g' > /tmp/datafiles.txt
zip /u02/config/${ORACLE_SID}/unplug/datafiles.zip  `cat /tmp/datafiles.txt`

# Remove the 12.1 instance.
dbca -silent -deleteDatabase -sourceDB ${ORACLE_SID} -sysDBAUserName sys -sysDBAPassword ${ORACLE_PASSWORD}
lsnrctl stop

# Switch to the 12.2 home.
export ORACLE_HOME=${ORACLE_HOME_2}
export PATH=${ORACLE_HOME}/bin:$PATH

# Start the listener and recreate the instance.
lsnrctl start

dbca -silent -createDatabase                                                    \
     -templateName General_Purpose.dbc                                          \
     -gdbname ${ORACLE_SID} -sid ${ORACLE_SID} -responseFile NO_VALUE           \
     -characterSet AL32UTF8                                                     \
     -sysPassword ${SYS_PASSWORD}                                               \
     -systemPassword ${SYS_PASSWORD}                                            \
     -createAsContainerDatabase true                                            \
     -numberOfPDBs 0                                                            \
     -databaseType MULTIPURPOSE                                                 \
     -automaticMemoryManagement false                                           \
     -totalMemory 1536                                                          \
     -storageType FS                                                            \
     -datafileDestination "/u02/oradata/"                                       \
     -redoLogFileSize 50                                                        \
     -emConfiguration NONE                                                      \
     -ignorePreReqs

# Store config for the new instance.
dbshut $ORACLE_HOME
mkdir -p /u02/config/${ORACLE_SID}
  
cp /etc/oratab /u02/config/
# Flip the auto-start flag.
sed -i -e "s|${ORACLE_SID}:${ORACLE_HOME}:N|${ORACLE_SID}:${ORACLE_HOME}:Y|g" /u02/config/oratab
cp -f /u02/config/oratab /etc/oratab 
  
mv ${ORACLE_HOME}/dbs/orapw${ORACLE_SID} /u02/config/${ORACLE_SID}
mv ${ORACLE_HOME}/dbs/spfile${ORACLE_SID}.ora /u02/config/${ORACLE_SID}
fixConfig;
dbstart $ORACLE_HOME

# Create the PDB from the zip file.
cd /
unzip /u02/config/${ORACLE_SID}/unplug/datafiles.zip

sqlplus / as sysdba <<EOF
alter system set db_create_file_dest='/u02/oradata';
create pluggable database ${PDB_NAME} using '/u02/config/${ORACLE_SID}/unplug/${PDB_NAME}.xml';
alter pluggable database ${PDB_NAME} open upgrade;
exit;
EOF

# Remove the unplug location.
# I commented this out during development.
#rm -Rf /u02/config/${ORACLE_SID}/unplug

# Upgrade the new PDB.
cd ${ORACLE_HOME}/rdbms/admin 
${ORACLE_HOME}/perl/bin/perl catctl.pl -c "${PDB_NAME}" -l /tmp catupgrd.sql

# Run post-upgrade fixups.
sqlplus / as sysdba <<EOF
alter session set container=pdb1;
startup;

@${ORACLE_HOME}/rdbms/admin/utlrp.sql
@/u01/app/oracle/cfgtoollogs/${ORACLE_SID}/preupgrade/postupgrade_fixups.sql
EXECUTE DBMS_STATS.gather_fixed_objects_stats;
exit;
EOF


# Tail the alert log file as a background process
# and wait on the process so script never ends.
tail -f ${ORACLE_BASE}/diag/rdbms/${ORACLE_SID}/${ORACLE_SID}/trace/alert_${ORACLE_SID}.log &
bgPID=$!
wait $bgPID
