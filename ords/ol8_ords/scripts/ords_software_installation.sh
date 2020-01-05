echo "******************************************************************************"
echo "ORDS Software Installation." `date`
echo "******************************************************************************"
echo "Create docker_fg group and tomcat user."
groupadd -g 1042 docker_fg
useradd tomcat -u 501 -G docker_fg

echo "Java setup."
mkdir -p /u01/java
cd /u01/java
tar -xzf ${SOFTWARE_DIR}/${JAVA_SOFTWARE}
rm -f ${SOFTWARE_DIR}/${JAVA_SOFTWARE}
TEMP_FILE=`ls`
ln -s ${TEMP_FILE} latest

echo "Tomcat setup."
mkdir -p /u01/tomcat
cd /u01/tomcat
tar -xzf ${SOFTWARE_DIR}/${TOMCAT_SOFTWARE}
rm -f  ${SOFTWARE_DIR}/${TOMCAT_SOFTWARE}
TEMP_FILE=`ls`
ln -s ${TEMP_FILE} latest

echo "ORDS setup."
mkdir -p ${ORDS_HOME}
cd ${ORDS_HOME}
unzip -oq ${SOFTWARE_DIR}/${ORDS_SOFTWARE}
rm -f ${SOFTWARE_DIR}/${ORDS_SOFTWARE}
mkdir -p ${ORDS_CONF}

echo "SQLcl setup."
cd /u01
unzip -oq ${SOFTWARE_DIR}/${SQLCL_SOFTWARE}
rm -f ${SOFTWARE_DIR}/${SQLCL_SOFTWARE}

echo "APEX Images."
cd ${SOFTWARE_DIR}
unzip -oq ${SOFTWARE_DIR}/${APEX_SOFTWARE}
rm -f ${SOFTWARE_DIR}/${APEX_SOFTWARE}
mv ${SOFTWARE_DIR}/apex/images .
rm -Rf ${SOFTWARE_DIR}/apex

echo "Set file permissions."
chmod u+x ${SCRIPTS_DIR}/*.sh
chown -R tomcat:tomcat /u01

echo "CATALINA_BASE : Make directory and change ownership to group docker_fg."
mkdir -p ${CATALINA_BASE}
chown :docker_fg ${CATALINA_BASE}
chmod 775 ${CATALINA_BASE}
chmod g+s ${CATALINA_BASE}
