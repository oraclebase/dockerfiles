echo "******************************************************************************"
echo "Check if this is the first run." `date`
echo "******************************************************************************"
FIRST_RUN="false"
if [ ! -f ~/CONTAINER_ALREADY_STARTED_FLAG ]; then
  echo "First run."
  FIRST_RUN="true"
  touch ~/CONTAINER_ALREADY_STARTED_FLAG
else
  echo "Not first run."
fi

echo "******************************************************************************"
echo "Handle shutdowns." `date`
echo "docker stop --time=30 {container}" `date`
echo "******************************************************************************"
function gracefulshutdown {
  ${CATALINA_HOME}/bin/shutdown.sh
}

trap gracefulshutdown SIGINT
trap gracefulshutdown SIGTERM
trap gracefulshutdown SIGKILL

echo "******************************************************************************"
echo "Check DB is available." `date`
echo "******************************************************************************"
export PATH=${PATH}:${JAVA_HOME}/bin

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

CONNECTION="APEX_PUBLIC_USER/${APEX_PUBLIC_USER_PASSWORD}@//${DB_HOSTNAME}:${DB_PORT}/${DB_SERVICE}"
check_db ${CONNECTION}
while [ ${DB_OK} -eq 1 ]
do
  echo "DB not available yet. Waiting for 30 seconds."
  sleep 30
  check_db ${CONNECTION}
done

if [ ! -d ${CATALINA_BASE}/conf ]; then
  echo "******************************************************************************"
  echo "New CATALINA_BASE location." `date`
  echo "******************************************************************************"
  cp -r ${CATALINA_HOME}/conf ${CATALINA_BASE}
  cp -r ${CATALINA_HOME}/logs ${CATALINA_BASE}
  cp -r ${CATALINA_HOME}/temp ${CATALINA_BASE}
  cp -r ${CATALINA_HOME}/webapps ${CATALINA_BASE}
  cp -r ${CATALINA_HOME}/work ${CATALINA_BASE}
fi

if [ ! -d ${CATALINA_BASE}/webapps/i ]; then
  echo "******************************************************************************"
  echo "First time APEX images." `date`
  echo "******************************************************************************"
  mkdir -p ${CATALINA_BASE}/webapps/i/
  cp -R ${SOFTWARE_DIR}/images/* ${CATALINA_BASE}/webapps/i/
  APEX_IMAGES_REFRESH="false"
fi

if [ "${APEX_IMAGES_REFRESH}" == "true" ]; then
  echo "******************************************************************************"
  echo "Overwrite APEX images." `date`
  echo "******************************************************************************"
  cp -R ${SOFTWARE_DIR}/images/* ${CATALINA_BASE}/webapps/i/
fi

if [ "${FIRST_RUN}" == "true" ]; then
  echo "******************************************************************************"
  echo "Prepare the ORDS parameter file." `date`
  echo "******************************************************************************"
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
restEnabledSql.active=true
feature.sdw=true
database.api.enabled=true
EOF

  echo "******************************************************************************"
  echo "Configure ORDS." `date`
  echo "******************************************************************************"
  cd ${ORDS_HOME}
  $JAVA_HOME/bin/java -jar ords.war configdir ${ORDS_CONF}
  $JAVA_HOME/bin/java -jar ords.war

  echo "******************************************************************************"
  echo "Install ORDS. Safe to run on DB with existing config." `date`
  echo "******************************************************************************"
  cp ords.war ${CATALINA_BASE}/webapps/
fi

if [ ! -f ${KEYSTORE_DIR}/keystore.jks ]; then
  echo "******************************************************************************"
  echo "Configure HTTPS." `date`
  echo "******************************************************************************"
  mkdir -p ${KEYSTORE_DIR}
  cd ${KEYSTORE_DIR}
  ${JAVA_HOME}/bin/keytool -genkey -keyalg RSA -alias selfsigned -keystore keystore.jks \
     -dname "CN=${HOSTNAME}, OU=My Department, O=My Company, L=Birmingham, ST=West Midlands, C=GB" \
     -storepass ${KEYSTORE_PASSWORD} -validity 3600 -keysize 2048 -keypass ${KEYSTORE_PASSWORD}

  sed -i -e "s|###KEYSTORE_DIR###|${KEYSTORE_DIR}|g" ${SCRIPTS_DIR}/server.xml
  sed -i -e "s|###KEYSTORE_PASSWORD###|${KEYSTORE_PASSWORD}|g" ${SCRIPTS_DIR}/server.xml
  sed -i -e "s|###AJP_SECRET###|${AJP_SECRET}|g" ${SCRIPTS_DIR}/server.xml
  sed -i -e "s|###AJP_ADDRESS###|${AJP_ADDRESS}|g" ${SCRIPTS_DIR}/server.xml
  sed -i -e "s|###PROXY_IPS###|${PROXY_IPS}|g" ${SCRIPTS_DIR}/server.xml
  cp ${SCRIPTS_DIR}/server.xml ${CATALINA_BASE}/conf
  cp ${SCRIPTS_DIR}/web.xml ${CATALINA_BASE}/conf
fi;

echo "******************************************************************************"
echo "Start Tomcat." `date`
echo "******************************************************************************"
${CATALINA_HOME}/bin/startup.sh

echo "******************************************************************************"
echo "Tail the catalina.out file as a background process" `date`
echo "and wait on the process so script never ends." `date`
echo "******************************************************************************"
tail -f ${CATALINA_BASE}/logs/catalina.out &
bgPID=$!
wait $bgPID
