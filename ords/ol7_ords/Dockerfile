# ------------------------------------------------------------------------------
# Dockerfile to build basic Oracle REST Data Services (ORDS) images
# Based on the following:
#   - Oracle Linux 7 - Slim
#   - Java 12 :
#       http://jdk.java.net/12/
#   - Tomcat 9.0.x :
#       https://tomcat.apache.org/download-90.cgi
#   - Oracle REST Data Services (ORDS) 19.x :
#       http://www.oracle.com/technetwork/developer-tools/rest-data-services/downloads/index.html
#   - Oracle Application Express (APEX) 19.x :
#       http://www.oracle.com/technetwork/developer-tools/apex/downloads/index.html
#   - Oracle SQLcl 19.x :
#       http://www.oracle.com/technetwork/developer-tools/sqlcl/downloads/index.html
#
# Example build and run. Assumes Docker network called "my_network" to connect to DB.
#
# docker build -t ol7_ords:latest .
# docker build --squash -t ol7_ords:latest .
#
# docker run -dit --name ol7_ords_con -p 8080:8080 -p 8443:8443 --network=my_network -e DB_HOSTNAME=ol7_183_con ol7_ords:latest
# Pure CATALINA_BASE on a persistent volume.
# docker run -dit --name ol7_ords_con -p 8080:8080 -p 8443:8443 --network=my_network -e DB_HOSTNAME=ol7_183_con -v /home/docker_user/volumes/ol7_183_ords_tomcat:/u01/config/instance1 ol7_ords:latest
#
# docker logs --follow ol7_ords_con
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
ENV JAVA_SOFTWARE="openjdk-12.0.1_linux-x64_bin.tar.gz"                        \
    TOMCAT_SOFTWARE="apache-tomcat-9.0.21.tar.gz"                              \
    ORDS_SOFTWARE="ords-19.1.0.092.1545.zip"                                   \
    APEX_SOFTWARE="apex_19.1_en.zip"                                           \ 
    SQLCL_SOFTWARE="sqlcl-19.1.0.094.1619.zip"                                 \
    SOFTWARE_DIR="/u01/software"                                               \
    SCRIPTS_DIR="/u01/scripts"                                                 \
    KEYSTORE_DIR="/u01/keystore"                                               \
    ORDS_HOME="/u01/ords"                                                      \
    ORDS_CONF="/u01/ords/conf"                                                 \
    JAVA_HOME="/u01/java/latest"                                               \
    CATALINA_HOME="/u01/tomcat/latest"                                         \
    CATALINA_BASE="/u01/config/instance1"

# ------------------------------------------------------------------------------
# Define config (runtime) environment variables.
ENV DB_HOSTNAME="ol7-183.localdomain"                                          \
    DB_PORT="1521"                                                             \
    DB_SERVICE="pdb1"                                                          \
    APEX_PUBLIC_USER_PASSWORD="ApexPassword1"                                  \
    APEX_TABLESPACE="APEX"                                                     \
    TEMP_TABLESPACE="TEMP"                                                     \
    APEX_LISTENER_PASSWORD="ApexPassword1"                                     \
    APEX_REST_PASSWORD="ApexPassword1"                                         \
    PUBLIC_PASSWORD="ApexPassword1"                                            \
    SYS_PASSWORD="SysPassword1"                                                \
    KEYSTORE_PASSWORD="KeystorePassword1"                                      \
    APEX_IMAGES_REFRESH="true"                                                 \
    PROXY_IPS="123.123.123.123\|123.123.123.124"

# ------------------------------------------------------------------------------
# Get all the files for the build.
COPY software/* ${SOFTWARE_DIR}/
COPY scripts/* ${SCRIPTS_DIR}/

# ------------------------------------------------------------------------------
# Unpack all the software and remove the media.
# No config done in the build phase.
RUN sh ${SCRIPTS_DIR}/install_os_packages.sh                                && \
    sh ${SCRIPTS_DIR}/ords_software_installation.sh

# Perform the following actions as the tomcat user
USER tomcat

VOLUME [${CATALINA_BASE}]
EXPOSE 8080 8443
HEALTHCHECK --interval=1m --start-period=1m \
   CMD ${SCRIPTS_DIR}/healthcheck.sh >/dev/null || exit 1

# ------------------------------------------------------------------------------
# The start script performs all config based on runtime environment variables,
# and starts tomcat.
CMD exec ${SCRIPTS_DIR}/start.sh

# End
