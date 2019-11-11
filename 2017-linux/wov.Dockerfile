# ==============================================================================
# Author: Alejandro M. BERNARDIS
# Email: alejandro.bernardis at gmail.com
# Created: 2019/11/11 10:49
# Description: Contenedor para Microsoft MSSQL para Linux 2017.
#
# Change History:
# ~~~~~~~~~~~~~~~
# 2019/11/11 (i0608156): Versión inicial.
#
# ==============================================================================

FROM mcr.microsoft.com/mssql/server:2017-latest
LABEL maintainer "Alejandro M. BERNARDIS"

ENV ACCEPT_EULA="Y"
ENV MSSQL_PID="Developer"
ENV TZ="America/Argentina/Buenos_Aires"
ENV SA_PASSWORD="Password.01"

RUN mkdir -p /var/opt/aysa
COPY conf/. /var/opt/aysa/.

EXPOSE 1433

RUN ( /opt/mssql/bin/sqlservr --accept-eula & ) | grep -q "Service Broker manager has started" \
    && /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P ${SA_PASSWORD} -i /var/opt/aysa/setup.sql \
    && pkill sqlservr
