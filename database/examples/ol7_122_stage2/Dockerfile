# ------------------------------------------------------------------------------
# Dockerfile to build basic Oracle database images
# Based on the following:
#   - ol7_122_stage1:latest
#
# Example build and run.
#
# docker build -t ol7_122_stage2:latest .
#
# ------------------------------------------------------------------------------

# Set the base image to ol7_122_stage1:latest
FROM ol7_122_stage1:latest

# File Author / Maintainer
# Use LABEL rather than deprecated MAINTAINER
# MAINTAINER Tim Hall (tim@oracle-base.com)
LABEL maintainer="tim@oracle-base.com"

# ------------------------------------------------------------------------------
# Define fixed (build time) environment variables.
ENV ORACLE_BASE=/u01/app/oracle                                                \
    ORACLE_HOME=/u01/app/oracle/product/12.2.0.1/db_1                          \
    ORA_INVENTORY=/u01/app/oraInventory                                        \
    SOFTWARE_DIR=/u01/software


# Perform the following actions as the oracle user
USER oracle

# Do software-only installation
RUN ${SOFTWARE_DIR}/database/runInstaller -ignoreSysPrereqs -ignorePrereq      \
    -waitforcompletion -showProgress -silent                                   \
    -responseFile $SOFTWARE_DIR/database/response/db_install.rsp               \
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
    DECLINE_SECURITY_UPDATES=true

# Remove source software
RUN rm -Rf ${SOFTWARE_DIR}/database

# Run the root scripts
USER root

RUN sh ${ORA_INVENTORY}/orainstRoot.sh                                      && \
    sh ${ORACLE_HOME}/root.sh

# End
