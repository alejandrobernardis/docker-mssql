# DOCKER MSSQL (LINUX)

Visit the [Microsoft Docker Hub page](https://hub.docker.com/u/microsoft) for more information and additional images.

## How to use this image

### start a mssql instance

```bash
co=14001
if ! docker ps -a --format "{{.Ports}}"| grep -oP "\:$co\-"; then
    [[ ! -d "/data/db/mssql/$co" ]] && mkdir -p "/data/db/mssql/$co"
    chmod -R 0755 "/data/db/mssql/$co"
    docker run -ti \
      --restart unless-stopped \
      --cpus 2 --memory 2048m \
      --memory-swap 2048m \
      --storage-opt size=5G \
      -p $co:1433 \
      -v /data/transfer:/transfer \
      --name mssql-$co \
      -d mssql:2017
    echo "Done."
fi
unset co
docker ps --filter "name=mssql"
```

### start a mssql instance with external persistence of data

```bash
co=14001
if ! docker ps -a --format "{{.Ports}}"| grep -oP "\:$co\-"; then
    [[ ! -d "/data/db/mssql/$co" ]] && mkdir -p "/data/db/mssql/$co"
    chmod -R 0755 "/data/db/mssql/$co"
    docker run -ti \
      --restart unless-stopped \
      --cpus 2 --memory 2048m \
      --memory-swap 2048m \
      --storage-opt size=5G \
      -p $co:1433 \
      -v /data/db/mssql/$co:/var/opt/mssql \
      -v /data/transfer:/transfer \
      --name mssql-$co \
      -d mssql:2017-volume
    echo "Done."
fi
unset co
docker ps --filter "name=mssql"
```

### start a mssql sqlagent

```bash
co=14000
if docker ps -a --format "{{.Ports}}"| grep -oP "\:$co\-"; then
    docker exec -ti mssql-$co bash -c "/opt/mssql/bin/mssql-conf set sqlagent.enabled true"
    docker restart mssql-$co
    echo "Done."
    echo
fi
unset co
```

### connect to it from an application

```bash
$ docker run --name some-app --link some-mssql00:mssql -d some-app-image:latest
```

# BUILD

## How to build this image

```bash
# Source Directory
mkdir -p /data/src

# Get Source
git clone -b master --single-branch https://github.com/alejandrobernardis/docker-mssql.git /data/src/docker-mssql

# Source Directory
cd /data/src/docker-mssql/2017-linux

# Local Storage
docker build -t mssql:2017 -f wov.Dockerfile .

# External Storage
docker build -t mssql:2017-volume -f wv.Dockerfile .
```

# HELPERS

## Login creation (with roles)

```sql
-- Arguments
-- ~~~~~~~~~
--    username      > Usuario ([IA]=AySA; X=Externo) Ex: A0123789
--    password      > Contraseña (default='PassW0rd')
--    service       > Usuario de Servicio (0=NO (default), 1=YES)
--
--    # Roles
--    sysadmin      > Administrador (0=DROP (default), 1=ADD)
--    bulkadmin     > Craga Masiva (0=DROP (default), 1=ADD)
--    dbcreator     > Creación de Bases de Datos (0=DROP (default), 1=ADD)
--    processadmin  > Procesos (0=DROP (default), 1=ADD)
--    securityadmin > Seguridad (0=DROP (default), 1=ADD)
--    setupadmin    > Linked Server (0=DROP (default), 1=ADD)
--
sp_create_login
      '<username:str>'
    , '<password:str>'
    , '<service:[0|1]>'
    , '<sysadmin:[0|1]>'
    , '<bulkadmin:[0|1]>'
    , '<dbcreator:[0|1]>'
    , '<processadmin:[0|1]>'
    , '<securityadmin:[0|1]>'
    , '<setupadmin:[0|1]>'
```

## Add login to database (with roles)

```sql
-- Arguments
-- ~~~~~~~~~
--    username > Usuario ([IA]=AySA; X=Externo) Ex: A0123789
--    database > Base de Datos ([STRING]=N'db_name';
--                              [JSON]=N'{"databases": ["db_name", "..."]}')
--
--    # Roles
--    owner    > Dueño (0=DROP (default), 1=ADD)
--    reader   > Lectura (0=DROP (default), 1=ADD)
--    writer   > Escritura (0=DROP (default), 1=ADD)
--    security > Seguridad (0=DROP (default), 1=ADD)
--    access   > Acceso (0=DROP (default), 1=ADD)
--    execute  > Ejecución (0=DENY (default), 1=GRANT)
--    backup   > Backuup (0=DENY (default), 1=GRANT)
--
sp_add_login
       '<username:str>'
    ,  '<database:[str:json]>'
    ,  '<owner:[0|1]>'
    ,  '<reader:[0|1]>'
    ,  '<writer:[0|1]>'
    ,  '<security:[0|1]>'
    ,  '<access:[0|1]>'
    ,  '<execute:[0|1]>'
    ,  '<backup:[0|1]>'

```

---

# Documentation

- [Getting started guide for the SQL Server on Linux container](https://docs.microsoft.com/en-us/sql/linux/quickstart-install-connect-docker)

- [Best practices guide](https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-configure-docker)

## Issues

For any issues, please file under this GitHub project on the [Issues section](https://github.com/Microsoft/mssql-docker/issues).

There is also a [Gitter channel for SQL Server in DevOps](https://gitter.im/Microsoft/mssql-devops?utm_source=share-link&utm_medium=link&utm_campaign=share-link) that you can join and discuss interesting topics with other container, SQL Server, and DevOps enthusiasts.

## Troubleshooting & Frequently Asked Questions

- "Unknown blob" error code: You are probably trying to run the Windows Containers-based Docker image on a Linux-based Docker Engine. If you want to continue running the Windows Container-based image, we recommend reading the following community article: [Run Linux and Windows Containers on Windows 10](https://stefanscherer.github.io/run-linux-and-windows-containers-on-windows-10/).

- When using the Windows Docker CLI you must use double quotes instead of single ticks for the environment variables, else the mssql-server-linux image won't find the `ACCEPT_EULA` or `SA_PASSWORD` variables which are required to start the container.

- The 'sa' password has a minimum complexity requirement (8 characters, uppercase, lowercase, alphanumerical and/or non-alphanumerical)

- Licensing for SQL Server in Docker: Regardless of where you run it - VM, Docker, physical, cloud, on prem - the licensing model is the same and it depends on which edition of SQL Server you are using. The Express and Developer Editions are free. Standard and Enterprise have a cost. More information here: [https://www.microsoft.com/en-us/sql-server/sql-server-2016-editions](https://www.microsoft.com/en-us/sql-server/sql-server-2016-editions)

## License

The Docker resource files for SQL Server are licensed under the MIT license.  See the [LICENSE file](LICENSE) for more details.
