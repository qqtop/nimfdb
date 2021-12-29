# nimfdb   -  Firebird


Firebird database driver for Nim 
with help from the official python firebird-driver and nimpy


Linux only


Requirements
-------------------

 - latest Nim , tested mainly against the current devel version
 - python3.8.x or python3.9.x
 - a Firebird3 or firebird4 server installation from your distro
   or see [firebird](https://firebirdsql.org/en/firebird-4-0-1/)
 
Notes 
------------------- 
 - Tested on a firebird database with abt 7 million rows of [tatoeba](https://tatoeba.org/eng/) sentences

   with a tatoeba links table which has abt 17 million rows. 
   
   The Firebird 4.0  Server lives on a Raspberry 4 8GB  with Ubuntu 20.4 LTS.  
  

Installation
-------------------
 - pip install firebird-driver
 - nimble install nimcx
 - nimble install nimpy
 - nimble install https://github.com/qqtop/nimfdb 
 - some test programs benefit from zenity , nimcx has a cxzenity module available

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
|  - [X] modifyUser          | modify a user                                                    |
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
need more testing against the underlying python api.
Connections via embedded or tcp tested ok.



The python driver lives here [firebird-driver](https://github.com/FirebirdSQL/python3-driver) 

Read the [firebird-driver-documentation](https://firebird-driver.readthedocs.io/en/latest/index.html)

Read latest wisdom about [Backup/Restore ](https://ib-aid.com/articles/firebird-gbak-backup-tips-and-tricks)

For intensive administration use [Flamerobin](https://github.com/mariuz/flamerobin) 

Learn about the [Firebird Project](https://www.firebirdsql.org/en/start/)

Read the [Firebird News](https://www.firebirdnews.org/)

Thank You for [Nimpy](https://github.com/yglukhov/nimpy)


![Image](http://qqtop.github.io/qqtop1.png?raw=true)

January 2022


