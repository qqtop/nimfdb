# #####################################################################################
# Program     : nimfdb.nim  
# Status      : Development  based on the newest python firebird driver 
#               https://github.com/FirebirdSQL/python3-driver
# License     : MIT opensource  
# Version     : 0.1.0
# ProjectStart: 2020-05-29
# Last        : 2020-09-30
# Compiler    : Nim >= 1.3.5  or devel branch
# Description : Access Firebird databases via python3.8+ from nim
#               
#               Linux only 
#
#               Development for firebird 3.x & 4.x use
#
#               requires python firebird-driver installed via
#               
#               python pip install -U firebird-driver
#
#               with python3.8.x , all pulled in via nimpy
#            
#
# Tested on   : firebird3.x Superserver 
#
# Requirements: optional zenity for graphical messageboxes etc
# 
# Status      : basic functions work - see examples
#
#               
#               fdbE27.nim for testing and usage
#
#               nimfdb.nim also has a main module used for testing  
#
# Note        : default char set for createDatabase is UTF8
#
#               for datetime fields it is better to use varchar and fill them
#               with something like:  let mydatetime = quoteshellposix(cxnow()) 
#               this results in output like 2019-08-26 20:35:52+08:00
#
#               another way is to use python now.strftime("%Y-%m-%d %H:%M:%S")
#                python example or frieds formating to return a python string
#                from datetime import datetime
#                now = datetime.now()
#                print(now)
#                print(now.strftime("%Y-%m-%d %H:%M:%S"))
#                print(now.strftime("%Y-%b-%d %H:%M:%S"))
#                print(now.strftime("%Y/%b/%A %H:%M:%S"))
#                print(now.strftime("%Y-%m-%d"))
#                today = datetime.today()
#                print(today)
#                print(today.strftime("%Y-%m-%d %H:%M:%S"))
#                print(today.strftime("%Y-%m-%d %H:%M:%S.%f"))
#            
#               
#               This may change with firebird 4 as there will be timestamp with timezone 
#               fields and other improvements so above is a temporary solution
#
#               for bulk inserts or updates it is suggested to use execute block functionality
#               of the firebird server , see fdbE26.nim for an execute block
#               example which demonstrates fast inserts. But overall this topic
#               needs to be revisited.
#
#               The current commit at the end of fbquery slows bulk insert down
#
#               fbbackup/fbrestore now works but only localy for now , not over tcp
#
#               fbrestore uses gbak so make sure it is in the path
#
#               simple before insert createTrigger and createGenerator capability added
#
#               It is important to have the file permissions for the server and database set up correctly
#               or all kinds of error messages from the python fdb driver may occure . Depending on 
#               the distro usually a firebird group is available on linux installations and a user
#               should be part of this group.
#
#               In case the firebird-driver was installed into a gitified directory
#               like eg in /home/someuser/Downloads/python3-driver
#               just do git pull to update then
#               python3 setup.py install --user
#
#
#Todo         : More examples
#               some more functionality like transactions handling 
#               events,streamblobs,charset conversions,connection and other hooks, 
#               svc.database.shutdown for single user maintenance mode,nbbackup/restore
#               other functions from firebird.driver.py 
#               
# 
# Other       : https://www.ibphoenix.com/files/ConnectionStrings_Fb3.pdf
#               https://firebird-driver.readthedocs.io/en/latest/getting-started.html
# #####################################################################################
 
import nimcx 
import nimpy
export nimpy

#import "~/data5/NimStuff/NimCxDevel/cxzenity.nim"
import nimcx/cxzenity
# setup is now for new firebird-driver  , requires python3.8 and up

proc pyversion():string = 
   ## pyversion
   ##
   ## get the python version
   #
   var pyv = execCmdEx("python3 -v")
   var pyvx = pyv.output.splitLines()  # need to get the python version
   var pyv1 = pyvx[41]
   var pyv1x = pyv1.replace("Python ","")
   var pyvs = pyv1x.split(".") 
   result = "python" & pyvs[0] & "." & pyvs[1]
   
var pyversx = pyversion()

# change this line as required if you want to use the showFirebirdPythonDriver proc
let pathtopythondriver = gethomedir() & ".local/lib/" & pyversx & "/site-packages/firebird"

# we must add the driver path to the python search path if needed
# this is not required if firebird-driver is installed via pip
#var sp = pyImport("sys").path
#for p in [pathtopythondriver]:
#    discard sp.append(p)

# forward declaration
proc cleanQdata*(ares:string):string  
proc fbGrant*(acon:PyObject,username:string,atable:string ,options:string)

#required pyimports
let fdb* = pyImport("""firebird.driver""")  # import the actual python driver here
let fdbase* = pyImport("""firebird.base""") # import the driver base in case its needed 
let datetime* = pyImport("datetime")        # import the python datetime module
let pytime* = pyImport("time")              # import the python time module 
let pysys* = pyImport("sys")                # import the python driver sys module
let pyvers* = pysys.version                 # answers what python is in use question
let py* = pyBuiltinsModule()                # imports the python buildins
let os* = pyImport("os")
var connectedflag*:bool = false             # global to indicate connection status

# utility firebird query strings
let odsversion* = "SELECT RDB$GET_CONTEXT('SYSTEM','ENGINE_VERSION') FROM RDB$DATABASE"
# query to get isolation level of a connection
let isolevel* = "SELECT RDB$GET_CONTEXT('SYSTEM', 'ISOLATION_LEVEL') FROM RDB$DATABASE"
# query to get server time for reference only not much use inside nim
let servertime* = "select current_timestamp from rdb$database"
# query to get best current time and day for reference only not much use inside nim
let currenttime* = "select cast('now' as timestamp) from rdb$database"
let currentday*  = "select cast('today' as date) from rdb$database"
# query to count rows in all tables of a connected database needs sysdba or admin rights
let countall* = """
EXECUTE BLOCK
returns ( stm varchar(60), cnt integer )
as
BEGIN
   for select cast('select count(*) from "'||trim(r.RDB$RELATION_NAME)||'"' as varchar(60)) 
       from RDB$RELATIONS r
       where (r.RDB$SYSTEM_FLAG is null or r.RDB$SYSTEM_FLAG = 0) 
       and r.RDB$VIEW_BLR is null
       order by 1
   into :stm
   DO
   BEGIN
      execute statement :stm into :cnt;
      suspend;
   END
END
"""

template fbConStatus*(acon:PyObject,aconName:string) =
    ## fbConStatus
    ##
    ## display status of a connection assuming connection is called fbacon
    ## call like so : fbConStatus(fbacon,"fbacon")
    ##
    echo()
    cxprintLn(1,plum,"Connection : ",white, aconName)
    if connectedflag == false:
         printLnBiCol("Status     : Disconnected",colLeft=plum,colRight=tomato,xpos=1)
    else:
         printLnBiCol("Status     : Connected",colLeft=plum,colRight=cyan,xpos=1)    
    echo()


proc parseCxDatetime*(datestring: PyObject): string {.exportpy.} = 
    ## parseCxDatetime
    ##
    ## returns string representation of a datetime.dateime PyObject
    ## Example
    ## 
    ##.. code-block:: nim
    ##   printLnBiCol("parseCxdatetime  : " & parseCxDatetime((datetime.datetime(2019,7,15,5,10,3,2345))).strip()) 
    ## 
    result = $datestring

proc getPytime*():string =
    ## getpytime
    ##
    ## returns string representation of the current time from python
    ##
    ##.. code-block:: nim
    ##
    ##   printLnBiCol("getPytime        : " & getpytime())
    ##
    result = parseCxDatetime(datetime.datetime.fromtimestamp(pytime.time())).strip()
 
 
proc parseDatetime*(datestring:string):string =
    ## parseDatetime
    ## WIP
    ## attempt to remove artifacts which maybe returned from
    ## a fbquery run still needs more testing 
    var cds = datestring.replace("datetime.date","")
    cds.removesuffix(",")
    result = cds 
    

proc parseQrow*(dt:string,sep:string=","):string =    
     ## parseQrow
     ## 
     ## parses one row of a queryresult returned by fbquery as a string and
     ## calls the python datetime function in case the query result had a timestamp column
     ## so we get a formatted timestamp rather than a raw datetime.datetime(...) string.
     ## 
     result = ""
     var v0 = dt.split(",")
     for x in 0 ..< v0.len:  # index into v0
         try:
           if v0[x].contains("datetime.datetime"):
               # v0[x]  # this would be something like "datetime.datetime(2019"
               v0[x] = v0[x].replace("datetime.datetime(",",")
               result = result & v0[x]
           else:
               result = strip(result & sep & cleanQdata(v0[x]))
               result.removePrefix(",")
         except IndexDefect:
               printLnInfoMsg("Firebird","Unavailable index in " & $v0,truetomato)
         
  
proc parseFdbErrorMsg(fdbErrorMsg:string) =
    # here we attempt to parse the errormsg returned from the python fdb driver
    let em1 = fdbErrorMsg.split(":")
    let em11 = em1[0].replace("<class '","").replace("'>","")
    printLnErrorMsg(em11)
    printLnErrorMsg(cleanQdata(em1[1]))
    let em13 = em1[3].split("- ")
    printLnErrorMsg(cleanQdata(em1[2]) & " : " & cleanQdata(em13[0]))
    for x in 1..<em13.len:
        printLnErrorMsg(cleanQdata(em13[x]))    

proc showFirebirdPythonDriver*() = 
      ## showFirebirdPythonDriver
      ##
      ## mainly for developer use 
      ##
      decho(2)
      printLnInfoMsg("Firebird",cxpad("Python Driver Information",53),pastelorange)
      echo()
      printlnBiCol("Python Firebird Driver : " & pathtopythondriver,xpos=1)


proc showServerInfo*(host:string="localhost",user:string="sysdba", password:string = "") =
     ## showServerInfo
     ## 
     ## displays server related data via the firebird-driver info api 
     # 
     decho(2)
     printLnInfoMsg("Firebird",cxpad("Server Information " & host,53),pastelorange)
     echo()
     let svc = fdb.connect_server(host,user=user, password = password)
     printLnBiCol(" Firebird Arch.    : " & $svc.info.architecture)
     printLnBicol(" Firebird Version  : " & $svc.info.version)
     printLnBiCol(" Security Database : " & $svc.info.security_database)   
     printLnBiCol(" Home Directory    : " & $svc.info.home_directory)
     printLnBiCol(" Connection Count  : " & $svc.info.connection_count)
     printLnBiCol(" Attached Databases: " & $svc.info.attached_databases)
     decho(2)
     discard svc.close()

proc showDbInfo*(acon:PyObject) =
     ## showDbInfo 
     ##
     ## displays information about the currently connected database
     ##
     decho(2)
     printLnInfoMsg("Firebird",cxpad("Current Database Information",53),pastelorange)
     echo()
     printLnBiCol(" SQL Dialect        : " & $(acon.info.sql_dialect))
     printLnBicol(" CharSet            : " & $(acon.charset))
     printLnBiCol(" Firebird Version   : " & $(acon.info.version))
     printLnBiCol(" ODS Version        : " & $(acon.info.ods))  
     printLnBiCol(" Engine Version     : " & $(acon.info.engine_version))
     printLnBiCol(" Transactions       : " & $(acon.main_transaction))
     printLnBiCol(" QueryTransaction   : " & $(acon.query_transaction))
     printLnBiCol(" Connection active  : " & $(acon.is_active()))
     printLnBiCol(" Connection closed  : " & $(acon.is_closed()))
     printLnBiCol(" Attachment Id      : " & $(acon.info.attachment_id))
     printLnBiCol(" Database Page Size : " & $(acon.info.page_size))
     printLnBiCol(" Used pages         : " & $(acon.info.pages_used))
     printLnBiCol(" Free pages         : " & $(acon.info.pages_free))
     printLnBiCol(" Sweep Interval     : " & $(acon.info.sweep_interval))
     printLnBiCol(" Current Memory     : " & $(acon.info.current_memory))
     printLnBiCol(" Max Memory         : " & $(acon.info.max_memory))
     printLnBiCol(" Compressed         : " & $(acon.info.is_compressed()))
     # below encrypted meaning not clear , may refer to tcp connection
     printLnBiCol(" Encrypted          : " & $(acon.info.is_encrypted()))  
     echo()
     
proc fbConnect*(dsn,user,pw:string,fail:bool=true):PyObject = 
          ## fbconnect
          ## 
          ## connect to a database with dsn,user and passwd
          ## 
          ## dsn will depend on your server setup
          ## 
          ## locally this may work :  INET:///path_to_fdb
          ## 
          ## remote this could work: INET://192.168.x.x:3050/path_to_fdb
          ##
          ## or just 192.168.x.x/3050:/path_to_fdb
          ## 
          ## if all permissions etc are correct
          ##
          ## if connection cannot be established the program quits.
          ##
          ## If fail is set to false one can iterate and try several 
          ##
          ## connection strings without quitting on connection failure.
          ## 
          try:          
            result = fdb.connect(dsn,user=user,password=pw) # note syntax for the driver
            connectedflag = true
          except:
            echo()
            connectedflag = false
            let failmsg = "[nimfdb] Connection to " & dsn & " not established."
            echo()
            printLnFailMsg(cxpad("Connection attempt for user: " & user & " failed",failmsg.len))
            printLnFailMsg(cxpad("Check if credentials,permissions and path are correct.",failmsg.len))
            printLnFailMsg(failmsg)
            # for debug
            #parseFdbErrorMsg(getCurrentExceptionMsg())
            echo()
            if fail == true:  # this is the default setting, if fail = false we can skip
                              # a failing connection and maybe try another one
              doFinish()
            
            
proc fbdisconnect*(acon:PyObject):bool =
      # fbdisconnect 
      #
      # trying to close the connection
      try:
         #discard acon.commit() # cannot put this here or we do not close
         discard acon.close() 
         result = true
         connectedflag=false
      except:
         # if we come here a python error is bubbled trough
         # Error: unhandled exception: <class 'AssertionError'>:  [AssertionDefect]
         # to see this compile with -d:debug
         result = false  
         connectedflag = true                
         #raise    
         discard
 
proc queryFields*(qstring:string):int =
     # wip
     # queryfields count to separate rows in resultset of select queries 
     # basically we need to parse the fields out of a query string
     # initially look for markers select, first n and from
     # Nested selects in where-clauses are not yet considered here.
     #
     let aqstring = tolowerAscii(qstring).strip(true,false)
     if aqstring.startswith("select first "):
             var z0 = split(aqstring,"select first ")
             # now need to take care of number after first
             var z1 = z0[1].strip(true,false).split(" ")
             var z2 = z1[1]
             var z3 = z2.split("from") 
             var z4 = z3[0].split(",")
             result = z4.len 
                               
     elif aqstring.startswith("select "):
            var z0 = split(aqstring,"select ")
            var z1 = z0[1].split("from")
            var z2 = z1[0].split(",")
            #for x in z2: echo x
            result = z2.len             
     else:
           printLnInfoMsg("Firebird","Not a select query string . Queryfieldscount not established",truetomato) 
           result = -1
               
                       
proc fbquery*(acon:PyObject,qstring:string,raiseflag:bool = false):seq[string] {.discardable.} =   
          ## fbquery
          ## 
          ## send a query to the server and get results back in a seq[string]
          ## 
          let cur = acon.cursor()
          var okres = newSeq[string]()
          if (tolowerAscii(qstring).startswith("select") or tolowerAscii(qstring).startswith("execute block")) == true:
             for x in cur.execute(qstring):
                okres.add($x)
             result = okres                        
          else :
             try:
                 discard acon.execute_immediate(qstring) # no result set like insert update create etc
             except:          
                 printLnInfoMsg("Firebird","Error raised in fbquery with: " & qstring ,truetomato)
                 printLnInfoMsg("Firebird",getCurrentExceptionMsg(),truetomato) 
                 if raiseflag == true:
                    quit() # testing  or during development we exit on first error
                 else:
                    discard      

          discard acon.commit() # TODO: this would be slow for bulk inserts , 
                                # check fb docu for bulk insert best praxis execute block etc
                                # see example for EXECUTE BLOCK in fdbE26.nim for fast insert
                                
          # note: cannot close connection here due to python errors popping up
                                
proc cleanQdata*(ares:string):string =     
         # cleans most artifacts returned from the query executed in python
         # some may still resist though , change if your requirements are different
         # const Punctuation* = { ',', '(',')','{','}','.', '!', ';', '"','\'' } # just parked here
         result = ares.replace("\"","")
                      .replace("(","")
                      .replace(", \"(","")
                      .replace(",)","")
                      .replace(")","")
                      .replace("\")","")
                      .replace("\')","")
                      .replace("\\n","\L")                     
         result = strip(result)                    
         if result.startswith("\""):
                   result.removeprefix("\"")
         if result.startswith("(\""):
                   result.removeprefix("(\"")
         if result.endswith("\""):
                   result.removesuffix("\"")
         if result.endswith("\")"):
                   result.removesuffix("\")")                         
         if result.startswith("'"):
                   result.removeprefix("'")
         if result.startswith("Decimal'"):          
                    result.removeprefix("Decimal'") # for queries where driver returns Decimal'12345.23
         if result.endswith("'"):
                   result.removesuffix("'")
         result = strip(result, chars = {'\"',')'})
         
             
proc showQuery*(okres:seq[string],printit:bool = true):seq[string] {.discardable.} =
       ## showQuery
       ## 
       ## Displays query result and also returns results as a seq[string]
       ##
       ## for further processing. okres is usually the output of a fbquery run.
       ##
       ## if printing is not desired set printit to false so output will not be displayed
       ## 
       for x in 0 ..< okres.len:
         let ps = parseQrow(okres[x])
         result.add(ps)
         if printit == true:
            cxprintLn(1,ps) 
       echo()
                       

proc createFbDatabase*(dsn:string,auser:string,apassword:string,charset:string="UTF8") = 
    ## createFbDatabase
    ## 
    ## Checks if database exists , if not it will be created with given parameters
    ## 
    ## dsn depends on server setup  , usually path/to_my_database/mydata.fdb will do
    ## 
    ## see firebird database manual
    ## 
        
    try:
      # to check if database exists we just connect and close ,
      # in case of fails here fdb driver errors will be shown
      var acon = fdb.connect(dsn, user = auser, password = apassword)
      discard fbdisconnect(acon) 
      printLnInfoMsg("Firebird","Database " & dsn & " exists . Creation command failed.",truetomato)
      echo()
    except:
      printLnStatusMsg("Database does not exist we try to create. ")
      
      var acondb = fdb.create_database(#host=host,
                                     database = dsn,
                                     user = auser,
                                     password = apassword,
                                     charset = charset)  
                                                                         
      #another way to write this                           
      #var acon = fdb.create_database("create database '$1' user '$2' password '$3' DEFAULT CHARACTER SET UTF8" % [dsn,auser,apassword])
      printLnInfoMsg("Firebird", cxPad(dsn & " database created  ",40),pastelPink)
      discard fbdisconnect(acondb)  
      fbConStatus(acondb,"acondb")
      echo()
      #testing if re-connection can be established promptly
      #var acon = fdb.connect(database, user = auser, password = apassword)
      #discard fbdisconnect(acondb)  
      #fbConStatus(acondb,"acondb")
      #echo()
                                   
proc createFbTable*(acon:PyObject,tabledata:string) = 
     ## createFbTable
     ##
     ## create a table in currently connected database acon with tabledata
     ##
     #  get the expected tablename
     var tn = newSeq[string]() 
     if connectedflag == true:
        # we take care of create/recreate
        if toUpperAscii(tabledata).startswith("CREATE TABLE "):
             tn = toUpperAscii(tabledata).split("CREATE TABLE ")[1].split("(")
        elif toUpperAscii(tabledata).startswith("RECREATE TABLE "):
             tn = toUpperAscii(tabledata).split("RECREATE TABLE ")[1].split("(")
        else:
             printLnInfoMsg("Firebird","Create table sql string wrong ! Quitting ! ",red)
             cxprintLn(11,tabledata)
             doFinish()
        try: 
           discard acon.execute_immediate(tabledata) 
           discard acon.commit()
           printLnInfoMsg("Table   ",cxPad("New table " & tn[0] & " created .    ",50),yellowgreen)
           fbgrant(acon,"sysdba",tn[0],"all")
           printLnInfoMsg("Firebird",cxPad("All granted to sysdba",50),pastelPink)
           echo()
        except:
           printLnFailMsg("Creation of new table failed. Maybe existing.")  
           parseFdbErrorMsg(getCurrentExceptionMsg())
           echo() 
           discard
     else:
           printLnStatusMsg("Nothing Done. ConnectionStatus : " & $connectedflag)

proc createGenerator*(acon:PyObject,generatorName:string) =
     ## createGenerator
     ##
     ## creates a generator or sequence in the connected database
     ##
     if connectedflag == true:
        let createGen = "CREATE SEQUENCE $1;" % generatorName
        fbquery(acon,createGen)  
     

proc createTrigger*(acon:PyObject,triggername:string,tablename:string,generatorname:string,triggertype="beforeinsert") =
   ## createTrigger
   ##
   ## creates a before insert trigger for a connected database
   ##
   if connectedflag == true:
       let createTrig = """CREATE TRIGGER $1 FOR $2 ACTIVE
       BEFORE insert POSITION 0
       AS
         BEGIN
           if (NEW.ID is NULL) then NEW.ID = GEN_ID($3, 1);
       END
       """  % [triggername,tablename,generatorname]
       fbquery(acon,createTrig)
       
   
proc dropTable*(acon:PyObject,dtable:string) =
  ## dropTable
  ##
  ## function to drop a table 
  ## apparently you want to use this with care
  ##
  if connectedflag == true:
      try:
        let ds = "drop table $1" % dtable
        discard acon.execute_immediate(ds)
        discard acon.commit()
        echo()
        printLnInfoMsg("Firebird","$1 table dropped successfully" % dtable,greenyellow)
        echo() 
      except:
        echo()
        printLnInfoMsg("Firebird","Could not drop $1 table" % dtable,truetomato)
        parseFdbErrorMsg(getCurrentExceptionMsg())
        echo()
    
proc createFbIndex*(acon:PyObject,indexdata:string) = 
     ## createFbIndex
     ##
     ## create an index in current connected database acon with indexdata  
     ##
     if connectedflag == true:
         try: 
            discard acon.execute_immediate(indexdata) 
            discard acon.commit()
            printLnInfoMsg("Index",cxPad("New index created .   ",50),yellowgreen)
            echo()
         except:
            printLnFailMsg("Creation of new index failed. ")  
            parseFdbErrorMsg(getCurrentExceptionMsg())
            echo() 
            discard
    
# utility functions mainly for sysadmin use
# needs more testing due to python driver api changes

proc getOds*(acon:PyObject):string = 
   ## getOds
   ## 
   ## returns ODS version of the firebird server
   ##  
   result = cleanQdata(showQuery(fbquery(acon,odsversion),false)[0]) # do not show
   result.removeSuffix(",")     
   
proc getUsers*(host:string="localhost",user:string="sysdba", password:string = "") =
     ## getUsers
     ##
     ## returns all users registered for the server with full detail
     ## for a simpler output use getSecUsers
     #
     decho(2)
     cxprintln(1,plum,"Users registered in this server")
     let svc = fdb.connect_server(host,user=user, password = password)
     let ux = svc.user.get_all()
     var ux1 = ($ux).split("UserInfo(")
     cxprintLn(1,yellowgreen,"User Count: ",$(ux1.len - 1))
     for x in 0 ..< ux1.len:
         ux1[x] = $ux1[x].strip().replace("[","")
         ux1[x] = $ux1[x].strip().replace("UserInfo(","")
         ux1[x] = $ux1[x].strip().replace(")","")
         ux1[x] = $ux1[x].strip().replace("),","")
         ux1[x] = $ux1[x].strip().replace("]","")
         ux1[x].removeSuffix(",")
         
         let ux2 = ux1[x].split(",")
         for y in 0 ..< ux2.len:
             if y == 0:
                cxprintLn(1,yellow,ux2[y].strip())
             else:   
                cxprintLn(1,ux2[y].strip())
         echo()       
     cxprintLn(1,pastelyellow,"End of registered users list on this server")
     decho(2)    

proc getSecUsers*(acon:PyObject):string =   
     ## getSecUsers
     ##
     ## displays usernames and relative security plugin
     ##   
     result = "\n" & spaces(6) # indent the returned multiline string 
     let aix = fbquery(acon,"select SEC$USER_NAME, SEC$PLUGIN from sec$users")
     for x in 0 ..< aix.len:
         result = result & cleanQdata(aix[x]).replace(spaces(6),"").replace("', '",", ") & newline() & spaces(6)  
              
proc allTables*(acon:PyObject):seq[string] =
     ## allTables
     ## returns all tables in connected database
     ##
     result = fbquery(acon,"select rdb$relation_name from rdb$relations where rdb$view_blr is null and (rdb$system_flag is null or rdb$system_flag = 0)")   
    
proc allFields*(acon:PyObject,atable:string):seq[string] =
     ## allFields
     # returns fields of a certain table in the connected db   
     let qfields = "select rdb$field_name from rdb$relation_fields where rdb$relation_name = '" & atable & "' order by rdb$field_position;"
     result = fbquery(acon,qFields)
      
proc showTablesAndFields*(acon:PyObject) =
     ## showTablesAndFields
     ##
     ## displays tables and fields in connected database
     ##
     cxprintLn(0,plum,"Table and Fields in Database")
     echo()
     let atf = alltables(acon)
     for x in 0 ..< atf.len:
        printLnBiCol((cleanQdata(atf[x])).replace("\\L","").strip(true,true),colLeft=lime)
        let afi = strip(cleanQdata(atf[x]).replace("\\L",""),true,true)
        showQuery(allfields(acon,afi))

           
proc allViews*(acon:PyObject): seq[string]  =
     ## allViews
     ##
     ## returns allViews in database
     ##
     result = fbquery(acon,"select rdb$relation_name from rdb$relations where rdb$view_blr is not null and (rdb$system_flag is null or rdb$system_flag = 0)")  
     if result.len == 0:
        result = @["None"] 
     
proc showAllViews*(acon:PyObject) =
     ## showAllViews
     ## 
     ## shows views in the connected db
     ##
     cxprintLn(0,plum,"Views in Database ")
     showQuery(allviews(acon))   

proc getViews*(acon:PyObject):string = 
   ## getViews
   ## 
   ## returns all views of a given connection
   ##  
   result = "\n" & spaces(6) # indent the returned multiline string
   let aix = allViews(acon)
   for x in 0 ..< aix.len:
      result = result & cleanQdata(aix[x]).replace(spaces(6),"") & newline() & spaces(6) 
           
     
proc allGenerators*(acon:PyObject):seq[string] = 
     ## allGenerators   #fails
     ##
     ## returns all generators  
     ##
     result = fbquery(acon,"select rdb$generator_name from rdb$generators where rdb$system_flag is null")
     if result.len == 0:
        result = @["None"]
          
proc showAllGenerators*(acon:PyObject) =
     ## showAllGenerators
     ##
     ## shows generators in the connected db
     ##
     cxprintLn(0,plum,"Generators in current Database ")
     showQuery(allgenerators(acon))
     echo()   
      
proc getGenerators*(acon:PyObject):string = 
     ## getGenerators
     ## 
     ## returns all generators of a given connection
     ##  
     result =  "\n" & spaces(6) # indent the returned multiline string
     let aix = allgenerators(acon)
     for x in 0 ..< aix.len:
        result = result & cleanQdata(aix[x]).replace(spaces(6),"") & newline() & spaces(6) 
  

proc allIndexes*(acon:PyObject): seq[string] = 
     ## allIndexes
     ##
     ## returns all indexes in a database
     ## 
     result = fbquery(acon,"select i.rdb$index_name,i.rdb$unique_flag,i.rdb$relation_name, s.rdb$field_name from rdb$indices i, rdb$index_segments s where  i.rdb$index_name=s.rdb$index_name and  i.rdb$index_name not like 'RDB$%'")

 
proc showAllIndexes*(acon:PyObject) =
     ## showAllIndexes
     ##
     ## displays indexes in database except primary keys
     ## 
     cxprintLn(0,plum,"Indexes in database except primary keys ")
     cxprintLn(0,dodgerblue,rightarrow & "  Name, UniqueFlag, Table, Field")
     echo()
     var adx = allindexes(acon)
     for x in 0 ..< adx.len:
        let adx1 = strip((cleanQdata(adx[x])).replace("\\L",""),true,true).split(",")
        for y in adx1:
           printBiCol(y.strip(true,true) & spaces(1))
        echo()      
     echo()
     
proc getIndexes*(acon:PyObject):string = 
     ## getIndexes
     ## 
     ## returns all indexes of a given connection
     ##  
     result =  "\n" & spaces(6) # indent the returned multiline string
     let aix = allindexes(acon)
     for x in 0 ..< aix.len:
        result = result & cleanQdata(aix[x]).replace(spaces(6),"") & newline() & spaces(6) 
    
 
proc allPrimarykeys*(acon:PyObject) : seq[string] =
     ## allPrimarKeys
     ##
     ## returns primary keys
     ##
     result = fbquery(acon,"select i.rdb$index_name, s.rdb$field_name from rdb$indices i left join rdb$index_segments s on i.rdb$index_name = s.rdb$index_name left join rdb$relation_constraints rc on rc.rdb$index_name = i.rdb$index_name where rc.rdb$constraint_type = 'PRIMARY KEY'")
 

proc showAllPrimarykeys*(acon:PyObject) = 
     ## showAllPrimaryKeys
     ##
     ## shows primary keys in the connected database
     ##
     cxprintLn(0,plum,"Primary Keys in Database ")
     printLn(rightarrow & "IndexName,\n Field",dodgerblue)
     let apk = allprimarykeys(acon)
     for x in 0 ..< apk.len:
        var apk1 = strip((cleanQdata(apk[x])).replace("\\L",""),true,true).split(",")
        for y in apk1:
           printLnBiCol(y,xpos=2)
     
proc getPrimarykeys*(acon:PyObject):string = 
     ## getPrimarykeys
     ## 
     ## returns all primarykeys of a given connection
     ##  
     result =  "\n" & spaces(6) # indent the returned multiline string
     let apk = allprimarykeys(acon)
     for x in 0 ..< apk.len:
        result = result & cleanQdata(apk[x]).replace(spaces(6),"") & newline() & spaces(6) 
 
 
proc getSingleCount*(acon:PyObject,atable:string):string = 
     ## getSingleCount
     ## 
     ## returns rowcount for one named table of a connection
     ## 
     let qcsql = "select count(*) from " & atable
     let cres = fbquery(acon,qcsql)
     result = $cres[0]
     
 
proc showCounts*(acon:PyObject) = 
     ## showCounts
     ##
     ## displays rowcount data for tables of a connection
     ##  
     cxprintLn(0,plum,"Row counts of each table in current database")
     echo()
     let qres = fbquery(acon,countall)
     printLn(fmtx(["<25","",""],"  Table"," : ","  RowCount  "),gold,xpos=1,styled={styleUnderScore})
     for x in qres:
         let xx = x.replace("('select count(*) from","").replace("'","").replace(")","").split(",")
         printLnBicol(fmtx(["<25","",">10"],xx[0]," : ",xx[1]),xpos=1)
     echo()
 
 
proc showCursorInfo*(cur:PyObject) = 
    ## showCursorInfo
    ##
    ## pass a cursor from a select or insert query 
    ##
    ## and display relevant technical information
    ##
    ##  
    ##
    cxprintLn(1,plum,"Cursor Description Information")
    echo()
    for x in 0 ..< 1000: # assuming 1000 fields ...
       try:  
           let nameOf   = cur.description[x][fdb.DESCRIPTION_NAME]
           let typeCode = cur.description[x][fdb.DESCRIPTION_TYPE_CODE]
           let displaysize = cur.description[x][fdb.DESCRIPTION_DISPLAY_SIZE]
           let internalsize = cur.description[x][fdb.DESCRIPTION_INTERNAL_SIZE]
           let precision = cur.description[x][fdb.DESCRIPTION_PRECISION]
           let scale = cur.description[x][fdb.DESCRIPTION_SCALE]
           let nullok = cur.description[x][fdb.DESCRIPTION_NULL_OK]
    
           cxprintLn 1,limegreen,"Name        : ",$nameof
           cxprintLn 1,"TypeCode    : ",$typecode
           cxprintLn 1,"DisplaySize : ",$displaysize
           cxprintLn 1,"InternalSize: ",$internalsize
           cxprintLn 1,"Precision   : ",$precision
           cxprintLn 1,"Scale       : ",$scale
           cxprintLn 1,"Null Ok     : ",$nullok 
           echo()
       except IndexDefect:
              # we bail at the first index error
              discard  
    
    cxprintLn(1,pink,"End of Cursor Description   ")
    echo()      
 
 
proc addUser*(host:string="localhost",
             adminuser:string="sysdba",
             adminpw:string="", 
             username:string,
             userpassword:string,
             firstname:string="",
             middlename:string="",
             lastname:string="") =
         
        let svc = fdb.connect_server(host,user=adminuser, password = adminpw)   
        var checkuser = svc.user.get(username)
        #echo "--add----> ",checkuser  
        if ($checkuser).strip() == "None" : 
           # we add new user    
           discard svc.user.add(user_name=username, password=userpassword,
                              first_name=firstname, middle_name=middlename, last_name=lastname)
           
           printLnInfoMsg("Firebird",cxpad("Added user   : " & username,50),pastelorange)
        else:
           printLnInfoMsg("Firebird",cxpad("User   : " & username & " not added",50),truetomato)     
        
        discard svc.close()
        echo()
           
proc deleteUser*(host:string="localhost",
                adminuser:string="sysdba",
                adminpw:string, 
                username:string)=
            
            let svc = fdb.connect_server(host,user=adminuser, password=adminpw)
            var checkuser = svc.user.get(username)
            #echo "--del----> ",checkuser  
            if ($checkuser).strip() == "None" : 
                 printLnInfoMsg("[Firebird]",cxpad("User : " & username & " does not exist",50),truetomato)     
            else:
                 discard svc.user.delete(username)
                 printLnInfoMsg("Firebird",cxpad("Deleted user : " & username,50),pastelorange)
            
            discard svc.close()   
            echo()
 
 
proc modifyUser*(host:string="localhost",
             adminuser:string="sysdba",
             adminpw:string="", 
             username:string,
             userpassword:string,
             firstname:string="",
             middlename:string="",
             lastname:string="") =
             
     printLnInfoMsg("Firebird","Modify user function not yet implemented",truetomato)
     echo()        
              
              
proc fbGrant*(acon:PyObject,username:string,atable:string ,options:string) =
     ## Grant rights to a user
     ## see firebird documentation about grant
     ##
     ## Needs testing
     ##
     if connectedflag == true:
         var grantstring = ""
         if options == "all":
             grantstring = ("GRANT DELETE, INSERT, REFERENCES, SELECT, UPDATE ON $1 TO $2 WITH GRANT OPTION;" % [atable,username]) 
         else:
             grantstring = ("GRANT $1 ON $2 TO $3 WITH GRANT OPTION;" % [options,atable,username])
    
         try:
            discard acon.execute_immediate(grantstring) 
            discard acon.commit()
            printLnInfoMsg("Firebird",cxpad(grantstring,60),pastelorange)
         except:
            printLnInfoMsg("Firebird",cxpad("Grant query failed",50),truetomato)
         echo()   

proc fbRevoke*(acon:PyObject,username:string,atable:string ,options:string) =
     ## Revoke rights from a user
     ## see firebird documentation about revoke
     ## https://fdb.readthedocs.io/en/latest/usage-guide.html
     ##
     ## Needs testing
     ##
     if connectedflag == true:
         var revokestring = ""
         if options == "all":
             revokestring = ("REVOKE DELETE, INSERT, REFERENCES, SELECT, UPDATE ON $1 FROM $2;" % [atable,username]) 
         else:
             revokestring = ("REVOKE $1 ON $2 FROM $3;" % [options,atable,username])
    
         try:
            discard acon.execute_immediate(revokestring) 
            discard acon.commit()
            printLnInfoMsg("Firebird",cxpad(revokestring,60),pastelorange)
         except:
            printLnInfoMsg("Firebird",cxpad("Revoke query failed",50),truetomato)
         echo()
    
    
proc fbBackup*(database:string,backupfile:string,adminpw:string = "",report:bool=false) =
   ## fbBackup
   ##
   ## Firebird database backup
   ##
   ## full path or aliases must be given for database and backupfile
   ##
   ## traditionally backupfiles end with .fbk
   ##
   ## only basic backup is implemented , for advanced scenarios use gbak directly
   ##
   ## this backup is performed via the python based fdb driver
   ##
   echo()
   printLnInfoMsg("Firebird",cxpad("Backup started for  : " & database,50),pastelorange)
   discard py.exec("""from fdb import services""")
   discard py.exec("""con = services.connect(password = '$1')""" % adminpw)
   discard py.exec("""con.backup('$1', '$2', metadata_only=False, collect_garbage=True)""" % [database,backupfile]) 
   if report == true:
     discard py.exec("""backup_report = con.readlines()""")
     printLn("Backup Report for $1 " % database,dodgerblue,xpos=1)
     discard py.exec("""for rep in backup_report: print(" ",rep) """)
   discard py.exec("""con.close()""")
   printLnInfoMsg("Firebird",cxpad("Backup finished for : " & database,50),pastelorange)
   printLnInfoMsg("Firebird",cxpad("                 to : " & backupfile,50),pastelorange)
   echo()

proc fbBackupnew*(host:string="localhost",database:string,backupfile:string,adminuser:string="",adminpw:string = "") =
     # WIP as per new api but fails
     let svc = fdb.connect_server(host,user=adminuser, password=adminpw)
     discard svc.database.backup(database = database, backup = backupfile,verbose = false)
     var report = svc.readlines() 
     cxprintLn(1,"Backup Report: ",$report)
     discard svc.close()
     printLnInfoMsg("Firebird",cxpad("Backup finished for : " & database,50),pastelorange)
     printLnInfoMsg("Firebird",cxpad("                 to : " & backupfile,50),pastelorange)
     echo()
     
      
proc fbRestore*(backupfile:string,database:string,adminpw:string="",replace:bool = false,report:bool=false) =
     ## fbRestore
     ##
     ## Firebird database restore
     ##
     ## this calls the firebird gbak utility to restore a databasefile backed up with
     ## gbak or with fbBackup
     ##
     ## the replace flag if set to true will use the gbak switch -REP to
     ## replace/overwrite an existing databasefile of the same name
     ## 
     ##  unless you are very sure it makes sense to restore to a new file and rename later
     ##  so intented name test123.fdb you restore to restored-test123.fdb and check if all ok
     ##
     ##  only basic restore is implemented , for advanced scenarios use gbak directly
     ##
     ##  also note that gbak does not need any passwords so it is paramount
     ##
     ##  that backupfiles are treated with same security precautions as the database itself.
     ##
     var restorestring = ""
     var ov = "No"
     
     printLnInfoMsg("Firebird",cxpad("GBAK Restore started for " & database,50),pastelorange)
     if replace == false:
         # this will throw an error if database already exists
         #restorestring = "gbak -c $1  $2 -V" % [backupfile,database]  # verbose
         restorestring = "gbak -c $1  $2" % [backupfile,database]
     else:
         # this will overwrite existing database so we ask for agreement
         if fileExists(database):
             echo()
             var yn = cxZYesNo("Replace File : $1 " % database) 
             if $yn == "yes":
                  #restorestring = "gbak -c $1  $2 -REP -V" % [backupfile,database] # verbose
                  restorestring = "gbak -c $1  $2 -REP" % [backupfile,database]
             else:
                  restorestring = ""
                  printLnInfoMsg("Firebird",cxpad("Nothing will be restored",50),truetomato)
         else:
             #if databasefile is not existing we simply restore
             #restorestring = "gbak -c $1  $2 -V" % [backupfile, database] # verbose
             #restorestring = "gbak -c $1  $2 -V" % [backupfile, database] # verbose
             restorestring = "gbak -c $1  $2" % [backupfile, database]
                              
     if restorestring.len > 0:
        if report == true: 
         cxprintLn(1,dodgerblue,"Restore Report for $1 " % database)
         cxprintLn(1,restorestring)
        var restoreres = execCmdEx(restorestring)
        if report == true:
         for line in restoreres.output.splitLines():                 
            cxprintLn(1,dodgerblue,line)
        if restoreres.exitCode == 0:
            printLnInfoMsg("Firebird",cxpad("Restore finished to : " & database ,50),pastelorange)
            printLnInfoMsg("Firebird",cxpad("               from : " & backupfile,50),pastelorange)
        else:
            printLnInfoMsg("Firebird",cxpad("Check output . gbak exitcode : " & $(restoreres.exitCode),50),truetomato)
     else:
         printLnInfoMsg("Firebird",cxpad("Nothing Restored",50),truetomato)


proc dropDatabase*(database:string,auser:string,auserpw:string) =
    ## dropDatabase
    ##
    ## This function will only succeed if there are no other connections
    ## or transactions pending on the firebird server for the to be dropped
    ## database file. The user must have droping rights
    ## 
    ## handle with care !
    ##
    echo()
    try:
      if fileExists(database):
         # to drop database we need to connect first
         printLnInfoMsg("Firebird",cxpad("Trying to drop Database " &  database,50),pastelorange)
         let newcon = fbconnect(database,auser,auserpw)
         discard newcon.drop_database()
         discard newcon.close()
         printLnInfoMsg("Firebird",cxpad("Dropped Database : " & database,50),pastelorange)
    except:
         printLnInfoMsg("Firebird","Database : " & database  & " could not be dropped ",truetomato)
 
when isMainModule:
    
    # some quick testing for various functions
    # the fbtest30.fdb is part of the python driver test suite
    # setup
    let pwx = getPwd()  # get the password via cxzenity first
    let user = "sysdba" # set the initial user
    
    #below ok  change to wherever the fbtest30.fdb file lives
    #note that permissions must be correct so usually you want
    #to have the .fdb files be part of the firebird group
    let testdb = "inet://" & getHomeDir() & "Downloads/python3-driver/test/fbtest30.fdb"
    # below used in backup gbak utility works only local
    let testdbflocal = getHomeDir() & "Downloads/python3-driver/test/fbtest30.fdb"
    
    #remote connection path example to some database on a remote server ok
    #let testdb = "192.168.1.109/3050:/home/mint-tux/Downloads/python3-driver/test/fbtest30.fdb" 
      
    # show path of python driver 
    showFirebirdPythonDriver()
    
    # show serverinfo
    showServerInfo(password=pwx)
    
    var acon = fbconnect(dsn=testdb,user=user,pw=pwx)
    echo()
    
    cxprintln(0,plum,"Show information based on connection to a database")
    showDbinfo(acon)
    showTablesAndFields(acon)
    showCounts(acon)  # will fail if user has not full permissions , ok with sysdba user
    echo()
    
    cxprintln(0,plum,"Query output")
    echo()
    showQuery(fbquery(acon,"SELECT first 5 * FROM employee r"))
    echo()
    showQuery(fbquery(acon,"select * from country order by currency"))
    echo()
    
    cxprintLn(0,plum,"Isolation Level:")
    showQuery(fbquery(acon,isolevel))
    echo()
    
    cxprintLn(0,plum,"ServerTime  :")
    var st = showQuery(fbquery(acon,servertime),false)
    # still remove some artifacts
    var sts = st[0].replace("(,","")
    sts.removesuffix(",")
    echo sts
    echo()
    
    cxprintLn(0,plum,"CurrentTime :")
    var ct = showQuery(fbquery(acon,currenttime),false)
    var cts = st[0].replace("(,","")
    cts.removesuffix(",")
    echo cts
    echo()
    
    cxprintLn(0,plum,"CurrentDay  :")
    var cd = showQuery(fbquery(acon,currentday),false)
    echo parseDatetime(cd[0])
    echo()
    
    cxprintLn(0,plum,"ODS         : " , getOds(acon))
    echo()
    
    cxprintLn(0,plum,"Show 2 types of user information")
    
    cxprintLn(0,plum,"Users/Plugin:")
    echo getSecUsers(acon)
    echo()
    
    cxprintLn(0,plum,"Users Full Details:")
    getusers(password = pwx)
    
    cxprintLn(0,plum,"User manipulation tests add/delete ")
    
    cxprintLn(0,plum,"Adding a new user if possible")
    addUser(adminpw=pwx,username="JOHN4",middlename="F.",userpassword="JOHN4")
    echo()
        
    cxprintLn(1,plum,"Current Users Full Details before deletes:")
    getusers(password = pwx)
    
    #let us delete users some may not exist
    deleteUser(adminpw=pwx,username="JOHN3")
    
    deleteUser(adminpw=pwx,username="JOHN22")
    
    deleteUser(adminpw=pwx,username="JOHN2020")
    
    cxprintLn(1,plum,"Current Users Full Details after delete:")
    getusers(password = pwx)
    echo()
       
    cxprintLn(1,peru,"End of user manipulation test")   
       
       
    cxprintLn(1,plum,"Disconnection Information ")
    printLnBiCol(" Fbdisconnect  : " & $fbdisconnect(acon) & "  [ should be true ]")
    printLnBiCol(" ConnectedFlag : " & $connectedflag & " [ should be false ]")
    echo()
    try:
       cxprintLn(1,peru,"Trying to run a query on a closed connection")  
       showQuery(fbquery(acon,"SELECT first 5 * FROM employee r"))
    except :
        printLnFailMsg("Connection has closed and is not available anymore as it should be")
        discard
       
        
    cxprintLn(1,plum,"Trying to run a backup/restore via gbak   ")
    
    # backup with new api still fails 
    #fbBackupNew("localhost",testdbflocal,getHomeDir() & "Downloads/python3-driver/test/fbtest30.fbk","sysdba",pwx)      
        
    # old local backup/restore ok
    fbBackup(testdbflocal,getHomeDir() & "Downloads/python3-driver/test/fbtest30.fbk",pwx) 
        
    # restoring with rep switch is true so a older restore will be replaced  ok
    fbRestore(getHomeDir() & "Downloads/python3-driver/test/fbtest30.fbk",
              getHomeDir() & "Downloads/python3-driver/test/fbtest30-restored.fdb",
              pwx,
              replace=true) 
    echo()              
    # now lets test the restored file connect to it
    acon = fbconnect(dsn=getHomeDir() & "Downloads/python3-driver/test/fbtest30-restored.fdb",user=user,pw=pwx)
    cxprintln(0,plum,"Query outputs from restored database")
    echo()
    showQuery(fbquery(acon,"SELECT first 5 * FROM employee r"))
    echo()
    showQuery(fbquery(acon,"select * from country order by currency"))
    echo()
    
    # show cursorinfo from a connection
    var cur = acon.cursor()
    showCursorInfo(cur.execute("select * from country"))
    echo()
      
    # shutdown all again
    cxprintLn(0,plum,"Disconnection Information ")
    printLnBiCol(" Fbdisconnected : " & $fbdisconnect(acon) & "  [ should be true ]")
    printLnBiCol(" ConnectedFlag  : " & $connectedflag & " [ should be false ]")
    echo()
    
    doFinish()
                     
# end of fdb.nim 
