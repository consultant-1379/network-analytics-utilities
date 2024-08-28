@ECHO OFF

REM ********************************************************************
REM Ericsson Radio Systems AB                                     MODULE
REM ********************************************************************
REM
REM
REM (c) Ericsson Radio Systems AB 2021 - All rights reserved.
REM
REM The copyright to the computer program(s) herein is the property
REM of Ericsson Radio Systems AB, Sweden. The programs may be used
REM and/or copied only with the written permission from Ericsson Radio
REM Systems AB or in accordance with the terms and conditions stipulated
REM in the agreement/contract under which the program(s) have been
REM supplied.
REM
REM ********************************************************************
REM Name    : pg_dump_restore.bat
REM Date    : 19/08/2021
REM Purpose : Script used to backup and restore netanserver_repdb and netanserver_pmdb (postgresql)
REM

SET PGPASSWORD=<postgresql_password>
SET backup_location=C:\Ericsson\Backup\postgresql_backup

IF "%1"=="backup" GOTO backup
IF "%1"=="restore" GOTO restore

:backup

"<postgresql_install_dir>\bin\pg_dump.exe" -h localhost -p 5432 -U netanserver -d "%2" -t \"%3\" -a > %backup_location%\%3.sql

GOTO :EOF

:restore

"<postgresql_install_dir>\bin\psql.exe" -h localhost -p 5432 -U netanserver -d "%2" -a < %backup_location%\%3.sql
 
GOTO :EOF
	
