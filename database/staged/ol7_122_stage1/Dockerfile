# ------------------------------------------------------------------------------
# Dockerfile to build basic Oracle database images
# Based on the following:
#   - Oracle Linux 7 - Slim
#   - Oracle Database
#       http://www.oracle.com/technetwork/database/enterprise-edition/downloads/oracle12c-windows-3633015.html
#
# Example build and run.
#
# docker build -t ol7_122_stage1:latest .
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
ENV ORACLE_BASE=/u01/app/oracle                                                \
    ORACLE_HOME=/u01/app/oracle/product/12.2.0.1/db_1                          \
    ORA_INVENTORY=/u01/app/oraInventory                                        \
    DATA_HOME=/u02/oradata                                                     \
    SOFTWARE_DIR=/u01/software                                                 \
    DB_SOFTWARE="linuxx64_12201_database.zip"                                  \
    ORACLE_PASSWORD="oracle"                                                   \
    SCRIPTS_DIR=/u01/scripts                                                   \
    ORAENV_ASK=NO

# ------------------------------------------------------------------------------
# Get all the files for the build.
COPY ${DB_SOFTWARE} ${SOFTWARE_DIR}/

# ------------------------------------------------------------------------------
# Unpack all the software and remove the media.
# No config done in the build phase.
# 
# Manually create user and group as preinstall package creates the with
# high IDs, which causes issues. Note 2 on link below.
# https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices/#user
#
RUN groupadd -g 500 dba                                                     && \
    groupadd -g 501 oinstall                                                && \
    useradd -d /home/oracle -g dba -G oinstall,dba -m -s /bin/bash oracle   && \
    yum -y install unzip tar gzip                                           && \
    yum -y update                                                           && \
    yum -y install oracle-rdbms-server-12cR1-preinstall                     && \
    rm -Rf /var/cache/yum                                                   && \
    mkdir -p ${ORACLE_HOME}                                                 && \
    mkdir -p ${DATA_HOME}                                                   && \
    chown -R oracle.oinstall /u01 /u02

# Perform the following actions as the oracle user
USER oracle

# Unzip software
RUN cd ${SOFTWARE_DIR}                                                      && \
    unzip ${DB_SOFTWARE}                                                    && \
    rm ${DB_SOFTWARE}

# End
