@echo off
setlocal

rem -------------------------------------------------------------------------------------
rem
rem This script will create all database schemas and fill them with all the initial data.
rem
rem Before using this script you need to set or change the following variables below:
rem         * DB_HOST
rem         * DBADMIN_PASSWORD
rem         * SERVERDB_USER
rem         * SERVERDB_PASSWORD
rem         * PSQL_PATH
rem
rem -------------------------------------------------------------------------------------

rem Set this variable to the hostname of the PostgreSQL instance
set DB_HOST=%1

rem Set these variables to the username and password of a database user
rem with permissions to create users and databases
set DBADMIN_NAME=postgres
set DBADMIN_PASSWORD=%2

rem Set these variables to the name of the database to be created for the TIBCO Spotfire
rem Server, and the user to be created for TIBCO Spotfire Server to access the database.
rem Note that the password is entered here in plain text, you might want to delete
rem any sensitive information once the script has been run.
set SERVERDB_NAME=%3
set SERVERDB_USER=%4
set SERVERDB_PASSWORD=%5

rem Set this variable to the bin directory of the PostgreSQL installation
rem where psql.exe can be found
set PSQL_PATH=%~6

rem Create the database and user
@echo Creating TIBCO Spotfire Server database and user
set PGPASSWORD=%DBADMIN_PASSWORD%
"%PSQL_PATH%\psql" -h %DB_HOST% -U %DBADMIN_NAME% -f create_server_env.sql -v db_name=%SERVERDB_NAME% -v db_user=%SERVERDB_USER% -v db_pass=%SERVERDB_PASSWORD% > log.txt  2>&1
if %errorlevel% neq 0 (
  @echo Error while running SQL script 'create_server_env.sql'
  @echo For more information consult the log.txt file
  exit /B 1
)

rem Create the tables and fill them with initial data
@echo Creating TIBCO Spotfire Server tables
set PGPASSWORD=%SERVERDB_PASSWORD%
"%PSQL_PATH%\psql" -h %DB_HOST% -U %SERVERDB_USER% -d %SERVERDB_NAME% -f create_server_db.sql >> log.txt  2>&1
if %errorlevel% neq 0 (
  @echo Error while running SQL script 'create_server_db.sql'
  @echo For more information consult the log.txt file
  exit /B 1
)

@echo Populating TIBCO Spotfire Server tables
"%PSQL_PATH%\psql" -h %DB_HOST% -U %SERVERDB_USER% -d %SERVERDB_NAME% -f populate_server_db.sql >> log.txt  2>&1
if %errorlevel% neq 0 (
  @echo Error while running SQL script 'populate_server_db.sql'
  @echo For more information consult the log.txt file
  exit /B 1
)

@echo -----------------------------------------------------------------
@echo Please review the log file (log.txt) for any errors or warnings!
endlocal
