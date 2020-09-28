# firebird
access firebird database with Nim via python firebird-driver

Work in progress .... 

nimfdb - a utility to access firebird databases
         utilizing the official python firebird-driver
         

  - [x] fbconnect            connect to a firebird database
  - [x] fbdisconnect         disconnect from a database
  - [x] fbquery              execute a query
  - [x] showQuery            raw display of a select query output
  - [x] showDbInfo           show data a connected database
  - [x] showServerInfo       show data about the firebird server
  - [x] showTablesAndFields  show available tables and their fields of a connected database
  - [x] showCounts           show row counts of tables in a connected databases         
  - [x] getSecUsers          show users registered in security database and sec. plugin
  - [x] dropDatabase         drops the database
  - [x] fbBackup             local backup a databases
  - [x] fbRestore            local restore a ddatabase from a backup with safety feature
  - [x] fbGrant              grant user rights
  - [x] fbRevoke             revoke user rights
  - [x] manageUsers [WIP]    addUser,modifyUser,removeUser,showUsers
  - [x] getRowCount          get row count from a tables
  - [x] getPrimarkeys        returns primarkeys of a connectedion 
  - [x] showAllPrimarykeys   show all primarykeys
  - [x] getAllIndexes        fetches indexes of a database
  - [x] showAllIndexes       show all indexes of a database
  - [x] getGenerators        fetches generators of a database
  - [x] showAllGenerators    show all generators
  - [x] getViews             fetches views of a databases
  - [x] showAllViews         show all views
  - [x] getUsers             
  - [x] createFbDatabase
  - [x] createFbTable
  - [x] createFbIndex
  - [x] createGenerator
  - [x] createTrigger
  - [x] getODS
  - [x] cleanQData           clean up query output from python artifacts
  - [x] fbConStatus          shows connection status 
  - [x] various utility functions to parse python output 

Most of the main functions work fine , some of the administration functions
need more testing as the underlying python api is still moving a bit.


The python driver can be installed via pip3 install -U firebird-driver
and lives here [firebird-driver](https://github.com/FirebirdSQL/python3-driver) 



