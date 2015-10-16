#Profiling Engine

##**Languages used: SAS/PERL/SQL with postgres**

This package requires a postgres server running on local host and would require updated login info & db name(s).

Schema specified in data_profiling_schema.sql needs to be created in local db. This is where the profiling results
will be written to.

##Overview:
* Automatically load data from source system
* Perform data quality profiling on underlying data and exclude/correct data set prior modeling
* Write profiling results back into DB, which are ultimately displayed in a dashboard (D3/highcharts) - this is separate code


##Breakdown: 
* This is a 3 way profiling engine that generates completeness/pattern/numeric results and writes them back to a pg database:

* **Part 1:** start up server.sas which opens up web sockets for udp connect and waits for commands (server socket:5500; client soeckt:5501)
    * sockets/ports can be updated/changed in the code
    * update "%let launchlist = *1_load_data*2_settings*3_profile_code*;" in the code for additional programs/macros to be executed
* **Part 2:** update 1_load_data & 2_settings files:
    * 1_load_data - specify read-in information into sas (table names, field names...)
    * 2_setting - specify type of profiling that needs to occur on each field
* **Part 3:** execute client specifying tasks to perform on SAS server [cl_profile.pl ARG(0) ARG(1) ARG(2) ]
    * ARG(0) - specify command to execute (RUN - execute sas program, STOP - stop sas server)
(example: cl_profile.pl RUN 3_profile_code mytablename)


##Execution phases:
* Run server.sas in background that opens a socket 5500(server) and 5501(client)
* Run cl_profile.pl with the following parameters:
  * cmd = command to execute on server (RUN=run sas program/STOP=shutdown sas server)
  * prog = name the program that needs to be execute
  * table = specify table from postgres to pull data from (this would require additional setup)
