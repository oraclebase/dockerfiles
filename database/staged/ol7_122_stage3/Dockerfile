# ------------------------------------------------------------------------------
# Dockerfile to build basic Oracle database images
# Based on the following:
#   - ol7_122_stage2:latest
#
# Example build and run.
#
# docker build -t ol7_122_stage3:latest .
#
# Non-persistent storage.
# docker run -dit --name ol7_122_con -p 1521:1521 -p 5500:5500 ol7_122_stage3:latest
#
# Persistent storage.
# docker run -dit --name ol7_122_con -p 1521:1521 -p 5500:5500 -v /home/docker_user/volumes/ol7_122_con_u02/:/u02 ol7_122_stage3:latest
#
# docker logs --follow ol7_122_con
# docker exec -it ol7_122_con bash
#
# docker stop --time=30 ol7_122_con
# docker start ol7_122_con
# 
# docker rm -vf ol7_122_con 
#
# ------------------------------------------------------------------------------

# Set the base image to ol7_122_stage2:latest
FROM ol7_122_stage2:latest

# File Author / Maintainer
# Use LABEL rather than deprecated MAINTAINER
# MAINTAINER Tim Hall (tim@oracle-base.com)
LABEL maintainer="tim@oracle-base.com"

# ------------------------------------------------------------------------------
# Define fixed (build time) environment variables.
ENV ORACLE_BASE=/u01/app/oracle                                                \
    ORACLE_HOME=/u01/app/oracle/product/12.2.0.1/db_1                          \
    ORA_INVENTORY=/u01/app/oraInventory                                        \
    DATA_HOME=/u02/oradata                                                     \
    SCRIPTS_DIR=/u01/scripts                                                   \
    ORAENV_ASK=NO

# Separate ENV call to allow existing variables to be referenced.
ENV PATH=${ORACLE_HOME}/bin:${PATH}

# ------------------------------------------------------------------------------
# Define config (runtime) environment variables.
ENV ORACLE_SID="cdb1"                                                          \
    SYS_PASSWORD="SysPassword1"                                                \
    PDB_NAME="pdb1"                                                            \
    PDB_PASSWORD="PdbPassword1"

# ------------------------------------------------------------------------------
# Get all the files for the build.
COPY scripts/* ${SCRIPTS_DIR}/

# ------------------------------------------------------------------------------
# Unpack all the software and remove the media.

USER root

RUN chown -R oracle.oinstall ${SCRIPTS_DIR}                                 && \
    chmod u+x ${SCRIPTS_DIR}/*.sh

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
