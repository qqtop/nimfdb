# firebird


Access firebird databases with Nim utilizing the new python firebird-driver



Work in progress ....

Requirements
-------------------

 - latest Nim , tested mainly against the current devel version
 - python3.8.x
  

Installation
-------------------
 - pip install -U firebird-driver
 - nimble install nimcx
 - nimble install nimpy
 - Work in progress ....


Functions Overview
-------------------

| procedures                 | description                                                      |         
|----------------------------|------------------------------------------------------------------|
|  - [x] fbconnect           | connect to a firebird database                                   |
|  - [x] fbdisconnect        | disconnect from a database                                       |
|  - [x] fbquery             | execute a query                                                  | 
|  - [x] showQuery           | raw display of a select query output                             |
|  - [x] showServerInfo      | show data about the firebird server                              |
|  - [x] showDbInfo          | show data a connected database                                   |
|  - [x] showCursorInfo      | show information about a connected select,insert cursor          |
|  - [x] showTablesAndFields | show available tables and their fields of a connected database   |
|  - [x] showCounts          | show row counts of tables in a connected databases               |
|  - [x] getSecUsers         | show users registered in security database and sec. plugin       |
|  - [x] dropDatabase        | drops the database                                               |
|  - [x] fbBackup            | local backup a databases                                         |
|  - [x] fbRestore           | local restore a database from a backup with safety feature       |
|  - [x] fbGrant             | grant user rights                                                |
|  - [x] fbRevoke            | revoke user rights                                               |
|  - [x] addUser             | add a new user                                                   |
|  - [ ] modifyUser          | modify a user                                                    |
|  - [x] deleteUser          | delete a user                                                    |
|  - [x] getRowCount         | get row count from a tables                                      |
|  - [x] getPrimarkeys       | returns primarkeys of a connectedion                             |
|  - [x] showAllPrimarykeys  | show all primarykeys                                             |
|  - [x] getAllIndexes       | fetches indexes of a database                                    |
|  - [x] showAllIndexes      | show all indexes of a database                                   |
|  - [x] getGenerators       | fetches generators of a database                                 |
|  - [x] showAllGenerators   | show all generators                                              |
|  - [x] getViews            | fetches views of a databases                                     |
|  - [x] showAllViews        | show all views                                                   |
|  - [x] getUsers            |                                                                  |
|  - [x] createFbDatabase    |                                                                  |
|  - [x] createFbTable       |                                                                  |
|  - [x] createFbIndex       |                                                                  |
|  - [x] createGenerator     |                                                                  |
|  - [x] createTrigger       |                                                                  |
|  - [x] getODS              |                                                                  |
|  - [x] cleanQData          | clean up query output from python artifacts                      |
|  - [x] fbConStatus         | shows connection status                                          |
|  - [x] utility functions   | to parse python output |                                         |


Most of the main functions work fine , some of the administration functions
need more testing as the underlying python api is still moving a bit.
Currently the more conventional functions are implemented , newer ways
to do the same thing are still work in progress.


The python driver lives here [firebird-driver](https://github.com/FirebirdSQL/python3-driver) 

Read all about it [firebird-driver-documentation](https://firebird-driver.readthedocs.io/en/latest/index.html)





![Image](http://qqtop.github.io/qqtop1.png?raw=true)

Sept 2020


