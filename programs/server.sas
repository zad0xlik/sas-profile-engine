
options source notes noxwait;
 filename _ALL_ CLEAR;

%global launch program in_file loop thisroot;

/*** change 'thisroot' to match your directory ***/
/* %let thisroot = C:\Bitnami\wampstack-5.4.37-0\apache2\htdocs\hydra\sas; */

%macro pathfind;
	%sysget(SAS_EXECFILEPATH)
%mend pathfind;

data _null_;
	call symputx('thisroot',substr("%pathfind", 1, index("%pathfind", "sas")+2));
run;
%put &thisroot;


 DATA _NULL_;
	CALL SYMPUT("td",PUT(TODAY(),YYMMDD10.));
 RUN;

/* proc printto log = "&thisroot.\LOGS\server_log_v&td..log";*/
/* quit;*/

 /* Only these sas programs can be run (launched) from the server */
 %let launchlist = *1_load_data*2_settings*3_profile_code*;

%MACRO server(loop);

	filename srvsoc socket ':5500' server reconn=10;
	filename client socket ':5501';
/*	filename srvclient socket ':5501';*/
/*	filename _webout SOCKET ':5500';*/
/*	proc printto print= _webout; */
/*	run;*/
/*---------------------------------------------------------------------*/
/* START: Create a server loop to listen for TCP connection.		   */
/*---------------------------------------------------------------------*/
	%do %while ( &loop );

 /*------------------------------------------------------------------------*/
 /* Send log to server log file. */
 /*------------------------------------------------------------------------*/
 /*proc printto log = "&srvlog"; run; */

			data _null_;
			infile srvsoc eov=v;						/* point to server as input file */
				input;									/* wait here to read one line from client */

					put "received message from client...";
					linein=left(_infile_);
					put linein=;

					if upcase(linein)=:'BYE' then do;
						command='BYE';
						call symputx('launch','');
						/*set my launch to null to avoid default execution*/
						call symputx('launch','');
					end;

					else if upcase(linein)=:'RUN' then do;	
						command='RUN';
/*						argument= upcase(trim(left(substr(linein,index(linein, '|')+1))));*/
/*						program= substr(argument,1,index(linein, '|')-1);*/
/*						table= substr(argument,index(linein, '|')+1);*/

						argument = upcase(trim(left(substr(linein,index(linein, ' ')+1))));
						program = translate(substr(argument, 1, index(argument, ' ')-1), '', ' ');
						table = translate(substr(argument, index(argument, ' ')+1), '', ' ');

/*						program=trim(arg);*/
/*						program=trim(left(linein));*/
						put "launchlist: &launchlist";
					end;

					else do;
						 file log;
						 put 'Cannot parse command.';
						 file srvsoc;
						 put 'Cannot parse command.';
						 /*set my launch to null to avoid default execution*/
						 call symputx('launch','');
					end;


					 /*---------------------------------------------------------------------*/
					 /* BYE: Shutdown server if requested.									*/
					 /*---------------------------------------------------------------------*/

					 if command='BYE' then do;
						 file log;
						 put 'Server stop is being requested by client.'; /* send to sas log*/
						 file srvsoc;
						 put 'Server stop is being requested by client.'; /* send to client */
						 call symputx('loop','0'); /* stop loop on next pass */
					 end;

					 /*---------------------------------------------------------------------*/
					 /* LAUNCH: Run a predefined program. 									*/
					 /*---------------------------------------------------------------------*/

					 if command='RUN' then do;
					 	put 'menu:';
						put program;
						put table;
					 	if NOT index(upcase("&launchlist"),'*'||trim(program)||'*') then do;
							 file log;
							 put 'This file cannot be run';
							 file srvsoc;
							 /*clear launch to pass 'if' statement below*/
							 call symputx('program','');
							 call symputx('table',trim(table));
							 put 'This file cannot be run';
						end;

						else do;
							 file log;
							 put 'Launching program ' program;
							 file srvsoc;
							 put 'Launching program ' program;
							 call symputx('program',trim(program));
							 call symputx('in_file',trim(table));
					 	end;
					 end;

				stop;
			run;

					 /*---------------------------------------------------------------------------*/
					 /* RUN SAS PROGRAM: use %include to start a sas program.					  */
					 /*---------------------------------------------------------------------------*/
					 %put program=***&program***;
					 %put table=***&in_file***;
					 %if &program^= %then %do;
						 %put &program;
						 %include "&thisroot.\PROGRAMS\&program..sas";
					 %end;

					 /*---------------------------------------------------------------------------*/
					 /* SEND BACK RESULTS TO CLIENT												  */
					 /*---------------------------------------------------------------------------*/

					/* Receiving socket for the results */
					/* data _null_;*/
						/* file client;*/

						/* put "COMPLETE FROM SERVER \n";*/

					/* run;*/

	%end;

%MEND;
	%server(1); /*start server - loop = 1 will not terminate until 0*/
RUN;

/*---------------------------------------------------------------------------*/
/* Release the SAS log. 													  */
/*---------------------------------------------------------------------------*/
/*proc printto; run;*/
