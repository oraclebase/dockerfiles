# ------------------------------------------------------------------------------
# Dockerfile to build basic Oracle database images
# Based on the following:
#   - Oracle Linux 7 - Slim
#   - Oracle Database
#       http://www.oracle.com/technetwork/database/enterprise-edition/downloads/index.html
#   - The "preupgrade.jar" file is downloaded from MOS 884522.1
#       https://support.oracle.com/epmos/faces/DocContentDisplay?id=884522.1
#
# Example build and run.
#
# docker build -t ol7_121_122:latest .
# docker build --squash -t ol7_121_122:latest .
#
# Persistent storage.
# docker run -dit --name ol7_121_122_con -p 1521:1521 -p 5500:5500 --shm-size="1G" -v /u01/volumes/ol7_121_con_u02/:/u02 ol7_121_122:latest
#
# docker logs --follow ol7_121_122_con
# docker exec -it ol7_121_122_con bash
#
# docker stop --time=30 ol7_121_122_con
# docker start ol7_121_122_con
# 
# docker rm -vf ol7_121_122_con 
#
# ------------------------------------------------------------------------------

# Set the base image to Oracle Linux 7 - Slim
FROM ol7_121:latest

# File Author / Maintainer
# Use LABEL rather than deprecated MAINTAINER
# MAINTAINER Tim Hall (tim@oracle-base.com)
LABEL maintainer="tim@oracle-base.com"

# ------------------------------------------------------------------------------
# Define fixed (build time) environment variables.
ENV ORACLE_BASE=/u01/app/oracle                                                \
    ORACLE_HOME=/u01/app/oracle/product/12.1.0.2/db_1                          \
    ORACLE_HOME_2=/u01/app/oracle/product/12.2.0.1/db_1                        \
    ORA_INVENTORY=/u01/app/oraInventory                                        \
    SOFTWARE_DIR=/u01/software                                                 \
    DB_SOFTWARE="linuxx64_12201_database.zip"                                  \
    ORACLE_PASSWORD="oracle"                                                   \
    SCRIPTS_DIR=/u01/scripts                                                   \
    ORAENV_ASK=NO

# Separate ENV call to allow existing variables to be referenced.
ENV PATH=${ORACLE_HOME_1}/bin:${PATH}

# ------------------------------------------------------------------------------
# Define config (runtime) environment variables.
ENV ORACLE_SID="cdb1"                                                          \
    SYS_PASSWORD="SysPassword1"                                                \
    PDB_NAME="pdb1"

# ------------------------------------------------------------------------------
# Get all the files for the build.
COPY software/* ${SOFTWARE_DIR}/
COPY scripts/* ${SCRIPTS_DIR}/

# ------------------------------------------------------------------------------
# Unpack all the software and remove the media.
# No config done in the build phase.
USER root

RUN mkdir -p ${ORACLE_HOME_2}                                               && \
    mkdir -p /u02/oradata                                                   && \
    chown -R oracle.oinstall /u01                                           && \
    chmod u+x ${SCRIPTS_DIR}/*.sh                                           && \
    chown oracle:docker_fg /u02                                             && \
    chmod 775 /u02                                                          && \
    chmod g+s /u02

# Perform the following actions as the oracle user
USER oracle

# Unzip software
RUN cd ${SOFTWARE_DIR}                                                      && \
    unzip -oq "${DB_SOFTWARE}"                                              && \
    rm ${DB_SOFTWARE}

# Do software-only installation
RUN ${SOFTWARE_DIR}/database/runInstaller -ignoreSysPrereqs -ignorePrereq      \
    -waitforcompletion -showProgress -silent                                   \
    -responseFile $SOFTWARE_DIR/database/response/db_install.rsp               \
    oracle.install.option=INSTALL_DB_SWONLY                                    \
    ORACLE_HOSTNAME=${HOSTNAME}                                                \
    UNIX_GROUP_NAME=oinstall                                                   \
    INVENTORY_LOCATION=${ORA_INVENTORY}                                        \
    SELECTED_LANGUAGES=en,en_GB                                                \
    ORACLE_HOME=${ORACLE_HOME_2}                                               \
    ORACLE_BASE=${ORACLE_BASE}                                                 \
    oracle.install.db.InstallEdition=EE                                        \
    oracle.install.db.OSDBA_GROUP=dba                                          \
    oracle.install.db.OSBACKUPDBA_GROUP=dba                                    \
    oracle.install.db.OSDGDBA_GROUP=dba                                        \
    oracle.install.db.OSKMDBA_GROUP=dba                                        \
    oracle.install.db.OSRACDBA_GROUP=dba                                       \
    SECURITY_UPDATES_VIA_MYORACLESUPPORT=false                                 \
    DECLINE_SECURITY_UPDATES=true

# Remove source software and put the latest "preupgrade.jar" file in place.
RUN rm -Rf ${SOFTWARE_DIR}/database

# Run the root scripts
USER root

RUN sh ${ORACLE_HOME_2}/root.sh

# Perform the following actions as the oracle user
USER oracle

VOLUME ["/u02"]
EXPOSE 1521 5500
HEALTHCHECK --interval=5m --start-period=10m \
   CMD ${SCRIPTS_DIR}/healthcheck.sh >/dev/null || exit 1

# ------------------------------------------------------------------------------
# The start script performs all config based on runtime environment variables.
# First run creates the database.
CMD exec ${SCRIPTS_DIR}/start.sh

# End
