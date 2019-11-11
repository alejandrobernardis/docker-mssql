#!/bin/bash
# Author: Alejandro M. BERNARDIS
# Email: alejandro.bernardis at gmail.com
# Created: 2019/11/11 10:49

set -m

/opt/mssql/bin/sqlservr &

RESULT=0

while true; do
    [ -e /var/opt/mssql/.sysadmin ] && break
    if [ -e /var/opt/mssql/log/errorlog ]; then
        RESULT=$(tail -n 25 /var/opt/mssql/log/errorlog| grep -c "Service Broker manager has started" -)
        if [ "$RESULT" -eq "1" ]; then
            echo "RESULT >>> $RESULT"
            /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P ${SA_PASSWORD} -i /var/opt/aysa/setup.sql
            echo "$(date)" >> /var/opt/mssql/.sysadmin
            break
        fi
        sleep 15s
    fi
done

fg %1
