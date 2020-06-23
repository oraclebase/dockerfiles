# ------------------------------------------------------------------------------
# Dockerfile to build basic Oracle database images
# Based on the following:
#   - Oracle Linux 8 - Slim
#   - Oracle Database
#       https://www.oracle.com/technetwork/database/enterprise-edition/downloads/index.html
#   - Oracle Application Express (APEX)
#       https://www.oracle.com/technetwork/developer-tools/apex/downloads/index.html
#
# Example build and run.
#
# docker build -t ol8_19:latest .
# docker build --squash -t ol8_19:latest .
#
# Non-persistent storage.
# docker run -dit --name ol8_19_con -p 1521:1521 -p 5500:5500 --shm-size="1G" ol8_19:latest
#
# Persistent storage.
# docker run -dit --name ol8_19_con -p 1521:1521 -p 5500:5500 --shm-size="1G" -v /u01/volumes/ol8_19_con_u02/:/u02 ol8_19:latest
#
# Persistent storage and part of Docker network called "my_network".
# docker run -dit --name ol8_19_con -p 1521:1521 -p 5500:5500 --shm-size="1G" --network=my_network -v /u01/volumes/ol8_19_con_u02/:/u02 ol8_19:latest
#
# docker logs --follow ol8_19_con
# docker exec -it ol8_19_con bash
#
# docker stop --time=30 ol8_19_con
# docker start ol8_19_con
# 
# docker rm -vf ol8_19_con 
#
# ------------------------------------------------------------------------------

# Set the base image to Oracle Linux 8
FROM oraclelinux:8-slim
#FROM oraclelinux:8

# File Author / Maintainer
# Use LABEL rather than deprecated MAINTAINER
# MAINTAINER Tim Hall (tim@oracle-base.com)
LABEL maintainer="tim@oracle-base.com"

# ------------------------------------------------------------------------------
# Define fixed (build time) environment variables.
ENV ORACLE_BASE=/u01/app/oracle                                                \
    ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1                        \
    ORA_INVENTORY=/u01/app/oraInventory                                        \
    SOFTWARE_DIR=/u01/software                                                 \
    DB_SOFTWARE="LINUX.X64_193000_db_home.zip"                                 \
    APEX_SOFTWARE="apex_20.1_en.zip"                                           \
    ORACLE_PASSWORD="oracle"                                                   \
    SCRIPTS_DIR=/u01/scripts                                                   \
    ORAENV_ASK=NO

# Separate ENV call to allow existing variables to be referenced.
ENV PATH=${ORACLE_HOME}/bin:${PATH}

# ------------------------------------------------------------------------------
# Define config (runtime) environment variables.
ENV ORACLE_SID=cdb1                                                            \
    SYS_PASSWORD="SysPassword1"                                                \
    PDB_NAME="pdb1"                                                            \
    PDB_PASSWORD="PdbPassword1"                                                \
    INSTALL_APEX="true"                                                        \
    APEX_EMAIL="me@example.com"                                                \
    APEX_PASSWORD="ApexPassword1"

# ------------------------------------------------------------------------------
# Get all the files for the build.
COPY software/* ${SOFTWARE_DIR}/
COPY scripts/* ${SCRIPTS_DIR}/

# ------------------------------------------------------------------------------
# Unpack all the software and remove the media.
# No config done in the build phase.
# 
# Manually create user and group as preinstall package creates the with
# high IDs, which causes issues. Note 2 on link below.
# https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices/#user
#
RUN microdnf install -y shadow-utils                                        && \
    groupadd -g 500 dba                                                     && \
    groupadd -g 501 oinstall                                                && \
    groupadd -g 1042 docker_fg                                              && \
    useradd -d /home/oracle -u 500 -g dba -G oinstall,dba,docker_fg -m -s /bin/bash oracle   && \
    sh ${SCRIPTS_DIR}/install_os_packages.sh                                && \
    mkdir -p ${ORACLE_HOME}                                                 && \
    mkdir -p /u02/oradata                                                   && \
    chown -R oracle:oinstall /u01                                           && \
    chmod u+x ${SCRIPTS_DIR}/*.sh                                           && \
    chown -R oracle:docker_fg /u02                                          && \
    chmod -R 775 /u02                                                       && \
    chmod -R g+s /u02

# Perform the following actions as the oracle user
USER oracle

# Unzip software
RUN cd ${ORACLE_HOME}                                                       && \
    unzip -oq ${SOFTWARE_DIR}/${DB_SOFTWARE}                                && \
    rm -f ${SOFTWARE_DIR}/${DB_SOFTWARE}

# Do software-only installation
RUN export CV_ASSUME_DISTID=OEL7.6                                          && \
    ${ORACLE_HOME}/runInstaller -ignorePrereq                                  \
    -waitforcompletion -silent                                                 \
    -responseFile ${ORACLE_HOME}/install/response/db_install.rsp               \
    oracle.install.option=INSTALL_DB_SWONLY                                    \
    ORACLE_HOSTNAME=${HOSTNAME}                                                \
    UNIX_GROUP_NAME=oinstall                                                   \
    INVENTORY_LOCATION=${ORA_INVENTORY}                                        \
    SELECTED_LANGUAGES=en,en_GB                                                \
    ORACLE_HOME=${ORACLE_HOME}                                                 \
    ORACLE_BASE=${ORACLE_BASE}                                                 \
    oracle.install.db.InstallEdition=EE                                        \
    oracle.install.db.OSDBA_GROUP=dba                                          \
    oracle.install.db.OSBACKUPDBA_GROUP=dba                                    \
    oracle.install.db.OSDGDBA_GROUP=dba                                        \
    oracle.install.db.OSKMDBA_GROUP=dba                                        \
    oracle.install.db.OSRACDBA_GROUP=dba                                       \
    SECURITY_UPDATES_VIA_MYORACLESUPPORT=false                                 \
    DECLINE_SECURITY_UPDATES=true; exit 0

# Replace default APEX software with user-provided version.
RUN rm -Rf ${ORACLE_HOME}/apex                                              && \
    unzip -oqd ${ORACLE_HOME} ${SOFTWARE_DIR}/${APEX_SOFTWARE}              && \
    rm ${SOFTWARE_DIR}/${APEX_SOFTWARE}

# Run the root scripts
USER root

RUN sh ${ORA_INVENTORY}/orainstRoot.sh                                      && \
    sh ${ORACLE_HOME}/root.sh

# Perform the following actions as the oracle user
USER oracle

# Uncomment the following line if you want to apply patches.
# You must have downloaded the patches and amended the "oracle_software_patch.sh" script.
#RUN sh ${SCRIPTS_DIR}/oracle_software_patch.sh

VOLUME ["/u02"]
EXPOSE 1521 5500
HEALTHCHECK --interval=5m --start-period=10m \
   CMD ${SCRIPTS_DIR}/healthcheck.sh >/dev/null || exit 1

# ------------------------------------------------------------------------------
# The start script performs all config based on runtime environment variables.
# First run creates the database.
CMD exec ${SCRIPTS_DIR}/start.sh

# End
