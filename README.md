# nimfdb   -  Firebird


Access Firebird databases with Nim utilizing the new python firebird-driver


Work in progress .... tested on Linux only


Requirements
-------------------

 - latest Nim , tested mainly against the current devel version
 - python3.8.x
 - a Firebird server installation from your distro
 
Notes 
------------------- 
 - our test firebird database has abt 7 million rows of [tatoeba](https://tatoeba.org/eng/) sentences
   and selects translations via the tatoeba links table with abt 17 million rows.
  

Installation
-------------------
 - pip install firebird-driver
 - nimble install nimcx
 - nimble install nimpy
 - nimble install https://github.com/qqtop/nimfdb 
 

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
|  - [x] getUsers            | registered users                                                 |
|  - [x] createFbDatabase    | database creation                                                |
|  - [x] createFbTable       | table creation                                                   |
|  - [x] createFbIndex       | index creation                                                   |
|  - [x] createGenerator     | generator creation                                               |
|  - [x] createTrigger       | trigger creation                                                 |
|  - [x] getODS              | ods version information                                          |
|  - [x] cleanQData          | clean up query output from python artifacts                      |
|  - [x] fbConStatus         | shows connection status                                          |
|  - [x] utility functions   | to parse python output                                           |
|  - [ ] transactions        | transaction handling                                             |
|  - [ ] events              | database event handling                                          |
|  - [ ] procedures          | sql procedure handling                                           |
|  - [ ] scrollableCursor    | scrollable cursor functions                                      |
|  - [ ] statistics          | database statistics reporting                                    |
|  - [ ] logging             | database logging                                                 |
|  - [ ] nbackup             | nbackup handling                                                 |
|  - [ ] nrestore            | nrestore handling                                                |
|  - [ ] shadow              | database shadowing                                               |
|  - [ ] sweep               | sweep handling                                                   |
|  - [ ] repair              | database repair handling                                         |
|  - [ ] streamblobs         | streamblobs handling                                             |
|  - [ ] hooks management    | database hooks handling                                          |
|  - [ ] timezone            | timezone handling    fb4                                         |
|  - [ ] charsetconversion   | character set handling                                           |
|  - [ ] examples            | more examples .....                                              |



Main functions work fine , some of the administration functions
need more testing as the underlying python api is still in flux.
Advanced management utilities need more testing .
Connections via embedded or tcp work fine .

The python driver lives here [firebird-driver](https://github.com/FirebirdSQL/python3-driver) 

Read the [firebird-driver-documentation](https://firebird-driver.readthedocs.io/en/latest/index.html)

Read latest wisdom about [Backup/Restore ](https://ib-aid.com/articles/firebird-gbak-backup-tips-and-tricks)

For intensive administration use [Flamerobin](https://github.com/mariuz/flamerobin) 

Learn about the [Firebird Project](https://www.firebirdsql.org/en/start/)



![Image](http://qqtop.github.io/qqtop1.png?raw=true)

Oct 2020


