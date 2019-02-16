echo "******************************************************************************"
echo "Handle shutdowns." `date`
echo "docker stop --time=30 {container}" `date`
echo "******************************************************************************"
function gracefulshutdown {
  dbshut $ORACLE_HOME
}

trap gracefulshutdown SIGINT
trap gracefulshutdown SIGTERM
trap gracefulshutdown SIGKILL

echo "******************************************************************************"
echo "Define fixConfig function." `date`
echo "Fixes the config using the contents of the volume." `date`
echo "Necessary when using persistent volume as "rm" and "run" will reset the config" `date`
echo "under the ORACLE_HOME." `date`
echo "******************************************************************************"
function fixConfig {
  cp -f /u02/config/oratab /etc/oratab
  if [ ! -L ${ORACLE_HOME}/dbs/orapw${ORACLE_SID} ]; then
    ln -s /u02/config/${ORACLE_SID}/orapw${ORACLE_SID} ${ORACLE_HOME}/dbs/orapw${ORACLE_SID}
  fi
  if [ ! -L ${ORACLE_HOME}/dbs/spfile${ORACLE_SID}.ora ]; then
    ln -s /u02/config/${ORACLE_SID}/spfile${ORACLE_SID}.ora ${ORACLE_HOME}/dbs/spfile${ORACLE_SID}.ora
  fi
  if [ ! -L ${ORACLE_BASE}/admin ]; then
    ln -s /u02/config/${ORACLE_SID}/admin ${ORACLE_BASE}/admin
  fi
  if [ ! -L ${ORACLE_BASE}/fast_recovery_area ]; then
    ln -s /u02/config/${ORACLE_SID}/fast_recovery_area ${ORACLE_BASE}/fast_recovery_area
  fi
  if [ ! -L ${ORACLE_BASE}/diag ]; then
    rm -Rf ${ORACLE_BASE}/diag
    ln -s /u02/config/${ORACLE_SID}/diag ${ORACLE_BASE}/diag
  fi
}

echo "******************************************************************************"
echo "Create networking files if they don't already exist." `date`
echo "******************************************************************************"
if [ ! -f ${ORACLE_HOME}/network/admin/listener.ora ]; then
  echo "******************************************************************************"
  echo "First start, so create networking files." `date`
  echo "******************************************************************************"

  cat > ${ORACLE_HOME}/network/admin/listener.ora <<EOF
LISTENER = 
(DESCRIPTION_LIST = 
  (DESCRIPTION = 
    (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1)) 
    (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521)) 
  ) 
) 
USE_SID_AS_SERVICE_listener=on
INBOUND_CONNECT_TIMEOUT_LISTENER=400
EOF

  cat > ${ORACLE_HOME}/network/admin/tnsnames.ora <<EOF
LISTENER = (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))

${ORACLE_SID}= 
(DESCRIPTION = 
  (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))
  (CONNECT_DATA =
    (SERVER = DEDICATED)
    (SERVICE_NAME = ${ORACLE_SID})
  )
)

${PDB_NAME}= 
(DESCRIPTION = 
  (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))
  (CONNECT_DATA =
    (SERVER = DEDICATED)
    (SERVICE_NAME = ${PDB_NAME})
  )
)
EOF

  cat > ${ORACLE_HOME}/network/admin/sqlnet.ora <<EOF
SQLNET.INBOUND_CONNECT_TIMEOUT=400
EOF
fi

echo "**************************************************************************"
echo "Startup 12.1 database."
echo "**************************************************************************"
fixConfig;
dbstart $ORACLE_HOME

echo "**************************************************************************"
echo "Prepare for the preupgrade checks."
echo "**************************************************************************"
sqlplus / as sysdba <<EOF
purge dba_recyclebin;
exec dbms_stats.gather_dictionary_stats;
drop package SYS.DBMS_PREUP;
@?/rdbms/admin/utluppkg.sql
@?/rdbms/admin/utlrp.sql
alter session set container = ${PDB_NAME};
purge dba_recyclebin;
exec dbms_stats.gather_dictionary_stats;
drop package SYS.DBMS_PREUP;
@?/rdbms/admin/utluppkg.sql
@?/rdbms/admin/utlrp.sql
EXIT;
EOF

echo "**************************************************************************"
echo "Run the preupgrade checks. There shouldn't be any failures in this example."
echo "**************************************************************************"
${ORACLE_HOME_2}/jdk/bin/java -jar ${ORACLE_HOME_2}/rdbms/admin/preupgrade.jar TERMINAL TEXT -c "${PDB_NAME}"

# Get the uppercase version of the PDB name.
export PDB_NAME_UPPER=`echo ${PDB_NAME} | tr /a-z/ /A-Z/`

echo "**************************************************************************"
echo "There shouldn't be any fixups, but run them just in case."
echo "**************************************************************************"
sqlplus / as sysdba <<EOF
alter session set container=${PDB_NAME};
@/u01/app/oracle/cfgtoollogs/${ORACLE_SID}/preupgrade/preupgrade_fixups.sql
EXIT;
EOF

echo "**************************************************************************"
echo "Unplug the PDB."
echo "**************************************************************************"
mkdir -p /u02/config/${ORACLE_SID}/unplug
sqlplus / as sysdba <<EOF
ALTER PLUGGABLE DATABASE ${PDB_NAME} CLOSE;
ALTER PLUGGABLE DATABASE ${PDB_NAME} UNPLUG INTO '/u02/config/${ORACLE_SID}/unplug/${PDB_NAME}.xml';
EXIT;
EOF

echo "**************************************************************************"
echo "Zip the files to keep them safe."
echo "**************************************************************************"
cat /u02/config/${ORACLE_SID}/unplug/${PDB_NAME}.xml | grep path | sed -e 's/<[^>]*>//g' > /tmp/datafiles.txt
zip /u02/config/${ORACLE_SID}/unplug/datafiles.zip  `cat /tmp/datafiles.txt`

echo "**************************************************************************"
echo "Remove the 12.1 instance."
echo "**************************************************************************"
dbca -silent -deleteDatabase -sourceDB ${ORACLE_SID} -sysDBAUserName sys -sysDBAPassword ${ORACLE_PASSWORD}
lsnrctl stop

echo "**************************************************************************"
echo "Switch to the 12.2 home."
echo "**************************************************************************"
export ORACLE_HOME=${ORACLE_HOME_2}
export PATH=${ORACLE_HOME}/bin:$PATH

echo "**************************************************************************"
echo "Start the listener and recreate the instance."
echo "**************************************************************************"
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

echo "**************************************************************************"
echo "Store config for the new instance."
echo "**************************************************************************"
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

echo "**************************************************************************"
echo "Create the PDB from the zip file."
echo "**************************************************************************"
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

echo "**************************************************************************"
echo "Upgrade the new PDB."
echo "**************************************************************************"
cd ${ORACLE_HOME}/rdbms/admin 
${ORACLE_HOME}/perl/bin/perl catctl.pl -c "${PDB_NAME}" -l /tmp catupgrd.sql

echo "**************************************************************************"
echo "Run post-upgrade fixups."
echo "**************************************************************************"
sqlplus / as sysdba <<EOF
alter session set container=pdb1;
startup;

@${ORACLE_HOME}/rdbms/admin/utlrp.sql
@/u01/app/oracle/cfgtoollogs/${ORACLE_SID}/preupgrade/postupgrade_fixups.sql
EXECUTE DBMS_STATS.gather_fixed_objects_stats;
exit;
EOF


echo "**************************************************************************"
echo "Complete..."
echo "**************************************************************************"
# Tail the alert log file as a background process
# and wait on the process so script never ends.
tail -f ${ORACLE_BASE}/diag/rdbms/${ORACLE_SID}/${ORACLE_SID}/trace/alert_${ORACLE_SID}.log &
bgPID=$!
wait $bgPID
