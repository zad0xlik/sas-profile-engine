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
/*end - get current working directory and set libname*/

/*PROFILING OPTIONS BY FIELD:*/
/*PatternCheck - Y/N - transform column into a pattern string and group by to select top occurences*/
/*DateCheck - Y/N - perform DQ checks on date fields to ensure dates are accurate (e.g. Sept 31 is not valid)*/
/*NumericAnalysis - Y/N - for numeric fields perform the following:
		nmiss=MissingValues
		sum=Sum
		min=Min
		mean=Mean
		max=Max
		skewness=Skewness
		std=StandardDeviation		
		median=Median
		mode=Mode
*/
/*Shortname - Y/N - if column name exceed 32 chars then rename to something shorter; otherwise keep the same*/
	DATA sasdata.tbl_name;
		LENGTH Variable $50 Shortname $32; 
		INPUT Variable $ PatternCheck $ DateCheck $ NumericAnalysis $ Shortname $;
		DATALINES;

			Date	Y	Y	N	Date
			field_1	Y	N	Y	field_1
			field_2	Y	N	Y	field_2
			field_3	Y	N	Y	field_3
			field_4	Y	N	Y	field_4

	RUN;

/*replicate process for multiple tables or put it into macro*/
	

/*ouptut data into flat file */

%macro output_db(listnm);

data _null_ ;          								 		/* no sas data set is created */ 
    set &listnm ; 
    file "&pathname.\output\&listnm._profile" dlm='|' ;    	/* output text file */ 
    put (_all_)(+0);
run;
	
/*ouptut schema*/
proc contents data=&listnm out=profile&listnm._sch noprint;
run;

/*sort columns prior inserting into postgres*/
proc sort data=profile&listnm._sch; by VARNUM; quit;

/*get all fields from table/file into a string to be refernce as a list when creating a schema in postgres*/
data _null_;
	format pg_type $100.;
	length strschema $4000;
	retain strschema;
	set profile&listnm._sch;

	if type = 1 then pg_type = name || 'double precision'; else pg_type = name || 'character(' || length || ')';
	pg_type = trim(left(compbl(pg_type)));
	if _n_ = 1 then strschema = trim(strschema)||' '||trim(pg_type); else strschema = trim(strschema)||','||trim(pg_type);
	keep name type length pg_type strschema;

	call symputx('strschema', strschema);

run;

/*create a string for schema of table to be create in postgres*/
data _null_ ;          								  /* no sas data set is created */ 
    file "&pathname.\output\&listnm._profilesch";     /* output text file */ 
	put "create table &listnm._profile (";
	put "&strschema";
	put ")
		with (
		  oids=false
		);
		alter table &listnm._profile
		  owner to postgres;";
run;

/*create table in postgres and insert data*/
x "perl &pathname.\output\csv_pg_load.pl &listnm._profilesch &listnm._profile";

%mend; 

%output_db(tbl_name);
/*%output_db(...);*/
run;





