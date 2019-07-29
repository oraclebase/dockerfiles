# Handle shutdowns
# docker stop --time=30 {container}
function gracefulshutdown {
  ${CATALINA_HOME}/bin/shutdown.sh
}

trap gracefulshutdown SIGINT
trap gracefulshutdown SIGTERM
trap gracefulshutdown SIGKILL

function check_db {
  CONNECTION=$1
  RETVAL=`/u01/sqlcl/bin/sql -silent ${CONNECTION} <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF TAB OFF
SELECT 'Alive' FROM dual;
EXIT;
EOF`

  RETVAL="${RETVAL//[$'\t\r\n']}"
  if [ "${RETVAL}" = "Alive" ]; then
    DB_OK=0
  else
    DB_OK=1
  fi
}

# Wait for the DB to be available.
CONNECTION="APEX_PUBLIC_USER/${APEX_PUBLIC_USER_PASSWORD}@//${DB_HOSTNAME}:${DB_PORT}/${DB_SERVICE}"
echo "Check DB is available."
check_db ${CONNECTION}
while [ ${DB_OK} -eq 1 ]
do
  echo "DB not available yet. Waiting for 1 minute."
  sleep 60
  check_db ${CONNECTION}
done

# Prep the ORDS parameter file.
cat > ${ORDS_HOME}/params/ords_params.properties <<EOF
db.hostname=${DB_HOSTNAME}
db.port=${DB_PORT}
db.servicename=${DB_SERVICE}
#db.sid=
db.username=APEX_PUBLIC_USER
db.password=${APEX_PUBLIC_USER_PASSWORD}
migrate.apex.rest=false
plsql.gateway.add=true
rest.services.apex.add=true
rest.services.ords.add=true
schema.tablespace.default=${APEX_TABLESPACE}
schema.tablespace.temp=${TEMP_TABLESPACE}
standalone.mode=false
#standalone.use.https=true
#standalone.http.port=8080
#standalone.static.images=/home/oracle/apex/images
user.apex.listener.password=${APEX_LISTENER_PASSWORD}
user.apex.restpublic.password=${APEX_REST_PASSWORD}
user.public.password=${PUBLIC_PASSWORD}
user.tablespace.default=${APEX_TABLESPACE}
user.tablespace.temp=${TEMP_TABLESPACE}
sys.user=SYS
sys.password=${SYS_PASSWORD}
EOF

# Configure ORDS. Safe to run on DB with existing config.
cd ${ORDS_HOME}
$JAVA_HOME/bin/java -jar ords.war configdir ${ORDS_CONF}
$JAVA_HOME/bin/java -jar ords.war
cp ords.war ${CATALINA_HOME}/webapps/

# Configure HTTPS
if [ ! -f ${KEYSTORE_DIR}/keystore.jks ]; then
  mkdir -p ${KEYSTORE_DIR}
  cd ${KEYSTORE_DIR}
  ${JAVA_HOME}/bin/keytool -genkey -keyalg RSA -alias selfsigned -keystore keystore.jks \
     -dname "CN=${HOSTNAME}, OU=My Department, O=My Company, L=Birmingham, ST=West Midlands, C=GB" \
     -storepass ${KEYSTORE_PASSWORD} -validity 3600 -keysize 2048 -keypass ${KEYSTORE_PASSWORD}

  sed -i -e "s|###KEYSTORE_DIR###|${KEYSTORE_DIR}|g" ${SCRIPTS_DIR}/server.xml
  sed -i -e "s|###KEYSTORE_PASSWORD###|${KEYSTORE_PASSWORD}|g" ${SCRIPTS_DIR}/server.xml
  cp ${SCRIPTS_DIR}/server.xml ${CATALINA_HOME}/conf
fi;

# Start Tomcat
${CATALINA_HOME}/bin/startup.sh

# Tail the catalina.out file as a background process
# and wait on the process so script never ends.
tail -f ${CATALINA_HOME}/logs/catalina.out &
bgPID=$!
wait $bgPID
