DM 'clear log';

*List location of work directory;
*%put %sysfunc(getoption(work));

/*start - get current working directory and set libname*/
%macro pathfind;
	%sysget(SAS_EXECFILEPATH)
%mend pathfind;

data _null_;
	call symputx('PATHNAME',substr("%pathfind", 1, index("%pathfind", "sas")+2));
run;
%put &PATHNAME;

LIBNAME SASDATA "&PATHNAME.\SASDATA";
/*end - get current working directory and set libname*/

/*tbl_dwld_prod.pl - connects to postgres to pull table of choice*/
/*update tbl_name with actual table from postgres*/
filename tbl_name pipe "perl &PATHNAME.\rawdata\tbl_dwld_prod.pl tbl_name" lrecl=32767;

	data SASDATA.tbl_name;
    %let _EFIERR_ = 0; /* set the ERROR detection macro variable */
	INFILE tbl_name delimiter=';' MISSOVER DSD lrecl=32767 firstobs=1;

	input
		Date						:	yymmdd10.
		field_1						:	8.
		field_2						:	8.
		field_3						:	8.
		field_4						:	8.
		/*...*/
    ;
	format date mmddyy10.;

	LINE_ID = _N_;
	PORTFOLIO = 'tbl_name';

    if _ERROR_ then call symputx('_EFIERR_',1);  /* set ERROR detection macro variable */
    run;

/*replicate read-in process as neccasary based on table required for the process*/
