# ------------------------------------------------------------------------------
# Dockerfile to build basic Oracle REST Data Services (ORDS) images
# Based on the following:
#   - Oracle Linux 7 - Slim
#   - Java 10 :
#       http://www.oracle.com/technetwork/java/javase/downloads/jdk10-downloads-4416644.html
#   - Tomcat 9.0.x :
#       https://tomcat.apache.org/download-90.cgi
#   - Oracle REST Data Services (ORDS) 18.x :
#       http://www.oracle.com/technetwork/developer-tools/rest-data-services/downloads/index.html
#   - Oracle Application Express (APEX) 18.x :
#       http://www.oracle.com/technetwork/developer-tools/apex/downloads/index.html
#   - Oracle SQLcl 18.x :
#       http://www.oracle.com/technetwork/developer-tools/sqlcl/downloads/index.html
#
# Example build and run. Assumes Docker network called "my_network" to connect to DB.
#
# docker build -t ol7_t9_j10_ords18:latest .
# docker build --squash -t ol7_t9_j10_ords18:latest .
#
# docker run -dit --name ol7_t9_j10_ords18_con -p 8080:8080 -p 8443:8443 --network=my_network -e DB_HOSTNAME=ol7_122_con ol7_t9_j10_ords18:latest
#
# docker logs --follow ol7_t9_j10_ords18_con
# docker exec -it ol7_t9_j10_ords18_con bash
#
# docker stop --time=30 ol7_t9_j10_ords18_con
# docker start ol7_t9_j10_ords18_con
#
# docker rm -vf ol7_t9_j10_ords18_con
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
ENV JAVA_SOFTWARE="jdk-10.0.1_linux-x64_bin.tar.gz"                            \
    TOMCAT_SOFTWARE="apache-tomcat-9.0.8.tar.gz"                               \
    ORDS_SOFTWARE="ords.18.1.1.95.1251.zip"                                    \
    APEX_SOFTWARE="apex_18.1_en.zip"                                           \
    SQLCL_SOFTWARE="sqlcl-18.1.1.zip"                                          \
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
RUN yum -y install unzip tar gzip                                           && \
    yum -y update                                                           && \
    rm -Rf /var/cache/yum                                                   && \
    mkdir /u01/java                                                         && \
    cd /u01/java                                                            && \
    tar -xzf ${SOFTWARE_DIR}/${JAVA_SOFTWARE}                               && \
    rm -f ${SOFTWARE_DIR}/${JAVA_SOFTWARE}                                  && \
    TEMP_FILE=`ls`                                                          && \
    mv ${TEMP_FILE}/* .                                                     && \
    rmdir ${TEMP_FILE}                                                      && \
    mkdir /u01/tomcat                                                       && \
    cd /u01/tomcat                                                          && \
    tar -xzf ${SOFTWARE_DIR}/${TOMCAT_SOFTWARE}                             && \
    rm -f ${SOFTWARE_DIR}/${TOMCAT_SOFTWARE}                                && \
    TEMP_FILE=`ls`                                                          && \
    mv ${TEMP_FILE}/* .                                                     && \
    rmdir ${TEMP_FILE}                                                      && \
    mkdir -p ${ORDS_CONF}                                                   && \
    cd ${ORDS_HOME}                                                         && \
    unzip ${SOFTWARE_DIR}/${ORDS_SOFTWARE}                                  && \
    rm -f ${SOFTWARE_DIR}/${ORDS_SOFTWARE}                                  && \
    cd /u01                                                                 && \
    unzip ${SOFTWARE_DIR}/${SQLCL_SOFTWARE}                                 && \
    rm -f ${SOFTWARE_DIR}/${SQLCL_SOFTWARE}                                 && \
    cd ${SOFTWARE_DIR}                                                      && \
    unzip ${SOFTWARE_DIR}/${APEX_SOFTWARE}                                  && \
    rm -f ${SOFTWARE_DIR}/${APEX_SOFTWARE}                                  && \
    rm -Rf ${CATALINA_HOME}/webapps/*                                       && \
    mkdir -p ${CATALINA_HOME}/webapps/i/                                    && \
    cp -R ${SOFTWARE_DIR}/apex/images/* ${CATALINA_HOME}/webapps/i/         && \
    rm -Rf ${SOFTWARE_DIR}/apex                                             && \
    useradd tomcat                                                          && \
    chmod u+x ${SCRIPTS_DIR}/*.sh                                           && \
    chown -R tomcat.tomcat /u01

# Perform the following actions as the tomcat user
USER tomcat

EXPOSE 8080 8443
HEALTHCHECK --interval=1m --start-period=1m \
   CMD ${SCRIPTS_DIR}/healthcheck.sh >/dev/null || exit 1

# ------------------------------------------------------------------------------
# The start script performs all config based on runtime environment variables,
# and starts tomcat.
CMD exec ${SCRIPTS_DIR}/start.sh

# End
