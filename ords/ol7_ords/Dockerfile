# ------------------------------------------------------------------------------
# Dockerfile to build basic Oracle REST Data Services (ORDS) images
# Based on the following:
#   - Oracle Linux 7 - Slim
#   - Java 8 :
#       http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html
#   - Tomcat 8.5.x :
#       https://tomcat.apache.org/download-80.cgi
#   - Oracle REST Data Services (ORDS) 3.0.x :
#       http://www.oracle.com/technetwork/developer-tools/rest-data-services/downloads/index.html
#   - Oracle Application Express (APEX) 5.1.x :
#       http://www.oracle.com/technetwork/developer-tools/apex/downloads/index.html
#
# Example build and run. Assumes Docker network called "my_network" to connect to DB.
#
# docker build -t ol7_ords:latest .
# docker run -dit --name ol7_ords_con -p 8080:8080 -p 8443:8443 --network=my_network -e DB_HOSTNAME=ol7_122_con ol7_ords:latest
# docker exec -it ol7_ords_con bash
#
# docker stop --time=30 ol7_ords_con
# docker start ol7_ords_con
#
# docker rm -vf ol7_ords_con
#
# ------------------------------------------------------------------------------

# Set the base image to Oracle Linux 7 - Slim
FROM oraclelinux:7-slim

# File Author / Maintainer
# Use LABEL rather than deprecated MAINTAINER
# MAINTAINER Tim Hall (tim@oracle-base.com)
LABEL maintainer="tim@oracle-base.com"

# ------------------------------------------------------------------------------
# Define fixed (build time) environment variables.
ENV JAVA_SOFTWARE="jdk-8u151-linux-x64.tar.gz"                                 \
    TOMCAT_SOFTWARE="apache-tomcat-8.5.23.tar.gz"                              \
    ORDS_SOFTWARE="ords.17.3.0.248.08.45.zip"                                  \
    APEX_SOFTWARE="apex_5.1.3_en.zip"                                          \
    SOFTWARE_DIR="/u01/software"                                               \
    SCRIPTS_DIR="/u01/scripts"                                                 \
    KEYSTORE_DIR="/u01/keystore"                                               \
    ORDS_HOME="/u01/ords"                                                      \
    ORDS_CONF="/u01/ords/conf"                                                 \
    JAVA_HOME="/u01/java"                                                      \
    CATALINA_HOME="/u01/tomcat"

# ------------------------------------------------------------------------------
# Define config (runtime) environment variables.
ENV DB_HOSTNAME="ol7-122.localdomain"                                          \
    DB_PORT="1521"                                                             \
    DB_SERVICE="pdb1"                                                          \
    APEX_PUBLIC_USER_PASSWORD="ApexPassword1"                                  \
    APEX_TABLESPACE="APEX"                                                     \
    TEMP_TABLESPACE="TEMP"                                                     \
    APEX_LISTENER_PASSWORD="ApexPassword1"                                     \
    APEX_REST_PASSWORD="ApexPassword1"                                         \
    PUBLIC_PASSWORD="ApexPassword1"                                            \
    SYS_PASSWORD="SysPassword1"                                                \
    KEYSTORE_PASSWORD="KeystorePassword1"

# ------------------------------------------------------------------------------
# Get all the files for the build.
COPY software/* ${SOFTWARE_DIR}/
COPY scripts/* ${SCRIPTS_DIR}/

# ------------------------------------------------------------------------------
# Unpack all the software and remove the media.
# No config done in the build phase.
RUN yum -y install unzip tar gzip                                       && \
    yum -y update                                                       && \
    yum clean all                                                       && \
    mkdir /u01/java                                                     && \
    cd /u01/java                                                        && \
    tar -xzf ${SOFTWARE_DIR}/${JAVA_SOFTWARE}                           && \
    rm -f ${SOFTWARE_DIR}/${JAVA_SOFTWARE}                              && \
    TEMP_FILE=`ls`                                                      && \
    mv ${TEMP_FILE}/* .                                                 && \
    rmdir ${TEMP_FILE}                                                  && \
    mkdir /u01/tomcat                                                   && \
    cd /u01/tomcat                                                      && \
    tar -xzf ${SOFTWARE_DIR}/${TOMCAT_SOFTWARE}                         && \
    rm -f ${SOFTWARE_DIR}/${TOMCAT_SOFTWARE}                            && \
    TEMP_FILE=`ls`                                                      && \
    mv ${TEMP_FILE}/* .                                                 && \
    rmdir ${TEMP_FILE}                                                  && \
    mkdir -p ${ORDS_CONF}                                               && \
    cd ${ORDS_HOME}                                                     && \
    unzip ${SOFTWARE_DIR}/${ORDS_SOFTWARE}                              && \
    rm -f ${SOFTWARE_DIR}/${ORDS_SOFTWARE}                              && \
    cd ${SOFTWARE_DIR}                                                  && \
    unzip ${SOFTWARE_DIR}/${APEX_SOFTWARE}                              && \
    rm -f ${SOFTWARE_DIR}/${APEX_SOFTWARE}                              && \
    rm -Rf ${CATALINA_HOME}/webapps/*                                   && \
    mkdir -p ${CATALINA_HOME}/webapps/i/                                && \
    cp -R ${SOFTWARE_DIR}/apex/images/* ${CATALINA_HOME}/webapps/i/     && \
    rm -Rf ${SOFTWARE_DIR}/apex                                         && \
    useradd tomcat                                                      && \
    chmod u+x /u01/scripts/start.sh                                     && \
    chown -R tomcat.tomcat /u01

# Perform the following actions as the tomcat user
USER tomcat

EXPOSE 8080 8443
HEALTHCHECK --interval=1m --start-period=5m \
   CMD ${SCRIPTS_DIR}/healthcheck.sh >/dev/null || exit 1

# ------------------------------------------------------------------------------
# The start script performs all config based on runtime environment variables,
# and starts tomcat.
CMD exec /u01/scripts/start.sh

# End
