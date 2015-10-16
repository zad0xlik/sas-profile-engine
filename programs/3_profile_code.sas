DM LOG 'CLEAR' LOG;

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

data &in_file;
	set sasdata.&in_file.;
run;


/*this can directly be extracted from pg*/
data VariableList;
	set sasdata.VL_&in_file.;
run;


DATA _NULL_;
	CALL SYMPUT("TD",PUT(TODAY(),YYMMDD10.));
RUN;

%MACRO ProfileData (SourceFile);
	DATA _NULL_;
		CALL SYMPUT("NumProf",PUT(Count,8.));
		SET VariableList NOBS=Count;
		STOP;
	RUN;

	DATA MissingMatrix;
			SET &SourceFile;
		KEEP LINE_ID;
	RUN;
	
	%DO I = 1 %TO &NumProf;
	%IF &I = 1 %THEN %DO;
		DATA ValStatAll&SourceFile;
			LENGTH VariableName $50 Invaliddates $20;
			FORMAT MaxLength AverageLength MissingValues UniqueCount Frequency 8.
				   Percentage BEST32.; *MinimumValue 8. MaximumValue 8.;
			STOP;
		RUN;

*** Creates a blank table where its running the append to. ***;
		DATA PattFreqAll&SourceFile;
			LENGTH VariableName OriginalValue Pattern $50;
			FORMAT Frequency Percentage BEST32.;
			STOP;
		RUN;

		DATA NumericAnalysis&SourceFile;
			LENGTH VariableName $50;
			FORMAT MissingValues Sum Min Mean Max Skewness StandardDeviation Median Mode BEST32.; 
			STOP;
		RUN;

**THIS SAME STEP HAS TO HAPPEN FOR DATE**;
	%END;
	DATA _NULL_;
		SET VariableList;
		IF _N_ = &I;
		CALL SYMPUT("PatternCheck",PatternCheck);
		CALL SYMPUT("DateCheck",Datecheck);
		CALL SYMPUT("Variable",Variable);
		CALL SYMPUT("NumericAnalysis",NumericAnalysis);
		CALL SYMPUT("Shortname",TRIM(LEFT(Shortname)));
		*CALL SYMPUT("MinValCheck",MinValCheck);
	RUN;

***Identify High frequency of values within each variable***;
***Checks for missing values***;
DATA _NULL_;
***Creates the total number of variables - NumVars***;
	CALL SYMPUT("NumVars",PUT(Count,8.));
	SET &SourceFile NOBS=Count;
	CALL SYMPUT("PORTFOLIO", TRIM(LEFT(PORTFOLIO)));
	STOP;
RUN;

PROC SORT DATA = &SourceFile; BY &Variable; QUIT;

DATA Temp;
	LENGTH VariableName $50;
	SET &SourceFile (KEEP=&Variable LINE_ID);  *Project_ID Case_ID Src_File);
	BY &Variable;
	IF _N_ =  1 THEN MissingValues = 0;
	VariableName = "&Variable";
	LengthVariable = LENGTH(&Variable);
	IF MISSING(&Variable) THEN MissingValues = 1; ELSE MissingValues = 0;

	IF ^MISSING(&Variable) AND FIRST.&Variable THEN UniqueCount = 1; ELSE UniqueCount = 0;

RUN;

/*xxx missing consolidation*/
PROC SORT DATA = MissingMatrix; BY LINE_ID; QUIT;
PROC SORT DATA = TEMP; BY LINE_ID; QUIT;


DATA MissingMatrix;	
	MERGE MissingMatrix (in=a)
		  TEMP			(in=b KEEP=LINE_ID MissingValues);

		  RENAME MissingValues=&Variable.;
		  IF A AND B THEN OUTPUT;
RUN;


/*MIN(&Variable) = MinimumValue Max(&Variable) = MaximumValue*/
PROC SUMMARY DATA = Temp NWAY MISSING;
	CLASS VariableName;
	VAR LengthVariable MissingValues UniqueCount;* &Variable;
	OUTPUT OUT = &Shortname.ValStat (DROP=_TYPE_ RENAME=_FREQ_=Frequency)
	MAX(LengthVariable) = MaxLength 
	MEAN(LengthVariable)=AverageLength 
	SUM(MissingValues)=MissingValues
	SUM(UniqueCount)=UniqueCount;
QUIT;


PROC SUMMARY DATA = Temp NWAY MISSING;
	CLASS &Variable VariableName;
	OUTPUT OUT = &Shortname.ValFreq (DROP=_TYPE_ RENAME=_FREQ_=Frequency);
QUIT;

PROC SORT DATA = &Shortname.ValFreq;
	BY DESCENDING Frequency; 
RUN;

/*%IF vtype(&Variable) = "N" %THEN %DO;*/
/*%END;*/

%IF &PatternCheck = Y %THEN %DO;
**Identify patterns within data - Used for dates & Ids**;
***Pulls tha value from the table and sorts it.***;
DATA &Shortname.Pattern;
	LENGTH Pattern VariableName OriginalValue $50;
	SET &SourceFile;
	VariableName = "&Variable";
	OriginalValue=&Variable;
	IF MISSING(&Variable) THEN Pattern = "NULL";
	ELSE Pattern = TRANSLATE(&Variable,"##########XXXXXXXXXXXXXXXXXXXXXXXXXXxxxxxxxxxxxxxxxxxxxxxxxxxx","1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz");
RUN;

***Calculates the frequency coulmn for PattFreq table.***;
PROC SUMMARY DATA = &Shortname.Pattern NWAY MISSING;
	CLASS VariableName Pattern;
	ID OriginalValue;
	OUTPUT OUT = &Shortname.PattFreq (DROP=_TYPE_ RENAME=(_FREQ_=Frequency ));
QUIT;

***Need to drop &Shortname.Pattern temp tables for space release***;
PROC DATASETS LIBRARY=Work;
   DELETE &Shortname.Pattern;
RUN;

*** Calculates Percentage for Pattern Frequency table ***;
DATA &Shortname.PattFreq;
	SET &Shortname.PattFreq;
	Percentage = SUM(Frequency/"&NumVars");
RUN;

PROC SORT DATA = &Shortname.PattFreq;
	BY DESCENDING Frequency;
RUN;

*** Appending each value from SASDATA.&Shortname.PattFreq to the blank skeleton table ***;
*** created above -- PattFreqAll&SourceFile***;
PROC APPEND BASE = PattFreqAll&SourceFile DATA = &Shortname.PattFreq (OBS=10);
QUIT;
	
%END;

%IF &NumericAnalysis = Y %THEN %DO;

	PROC UNIVARIATE DATA = TEMP NOPRINT;

	VAR &Variable;

	OUTPUT OUT = &ShortName.NUMCHK

/*	FORMAT MissingValues Sum Min Mean Max Skewness StandardDeviation Median	Mode Kurtosis Frequency BEST12.;*/

/*		nobs=Frequency*/
		nmiss=MissingValues
		sum=Sum
		min=Min
		mean=Mean
		max=Max
		skewness=Skewness
		std=StandardDeviation		
		median=Median
		mode=Mode
/*		kurtosis=Kurtosis*/
		;
	RUN;

	/*ASSIGN VARIABLE NAME*/
	DATA &ShortName.NUMCHK;
	RETAIN VariableName MissingValues Sum Min Mean Max Skewness StandardDeviation Median Mode;
	FORMAT VariableName $50.;
	SET &ShortName.NUMCHK;

		if MissingValues = . then MissingValues = 0;
		if Sum = . then Sum = 0;
		if Min = . then Min = 0; 
		if Mean = . then Mean = 0;
		if Max = . then Max = 0;
		if Skewness = . then Skewness = 0;
		if StandardDeviation = . then StandardDeviation = 0; 
		if Median = . then Median = 0;
		if Mode = . then Mode = 0;

		VariableName = "&Variable.";

	RUN;

	/*APPEND TO BASE TABLE*/
	PROC APPEND BASE = NumericAnalysis&SourceFile DATA=&ShortName.NUMCHK;
	QUIT;

%END;

%IF &DateCheck = Y %THEN %DO;

**Identify invalid dates**;
	DATA &Shortname.InvalidDates;
		FORMAT DATECONVERT YYMMDD10.;   
		INFORMAT DATECONVERT YYMMDD10.;
		RETAIN MissingValues 0;

		SET TEMP;

		/*GET THROUGH DATE FORMATS*/
		if vformat(&Variable) = 'MMDDYY8.' then DATECONVERT = &Variable;
		if vformat(&Variable) = 'DATETIME19.' then DATECONVERT = &Variable;
		if vformat(&Variable) = 'YYMMDD10.' then DATECONVERT = &Variable;

		*if vformat(&Variable) = '$10.' then DATECONVERT = (INPUT(trim(compbl(left(PUT(&Variable,10.)))), YYMMDD10.);
		*if vformat(&Variable) ^= 'MMDDYY8.' then DATECONVERT = INPUT(trim(compbl(left(&Variable))), YYMMDD10.);

		FORMAT DATECONVERT YYMMDD10.;  

		IF TRIM(LEFT(&Variable)) ^= . AND DATECONVERT ^= . THEN MissingValues = 0;
		IF TRIM(LEFT(&Variable)) = . AND DATECONVERT = . THEN MissingValues = 1;
		SumMissV + MissingValues;
		CALL SYMPUTX('SumMissV', PUT(SumMissV,10.));

		***create date constraints below***;
		IF &Variable ^= . AND (&Variable <= '30SEP1998'd OR &Variable > '01MAR2013'd) THEN DO;
		InvalidDate = 1;
		SumInvDt + InvalidDate;
		CALL SYMPUTX('SumInvDt',PUT(SumInvDt,10.));
		END;

		ELSE DO;
		InvalidDate = 0;
		CALL SYMPUTX('SumInvDt',PUT(SumInvDt,10.));
		END;
	
	RUN; 

	***Calculates the MissingValues coulmn for ValStat table.***;
	PROC MEANS DATA = &Shortname.InvalidDates;
		BY VariableName;
		Var MissingValues InvalidDate;
		OUTPUT OUT = &Shortname.InvalidDatesSUM sum=;
	RUN;

	DATA &Shortname.ValStat;
		LENGTH InvalidDates $20.;

		SET &Shortname.ValStat;
		InvalidDates = "miss: " || TRIM(LEFT(PUT(&SumMissV,10.))) || " inv: " || TRIM(LEFT(PUT(&SumInvDt,10.)));

		Percentage = SUM(TRIM(LEFT(PUT(&SumMissV,10.)))/Frequency);
	RUN;

%END;

%ELSE %DO;
	DATA &Shortname.ValStat;
		LENGTH InvalidDates $20.;
		SET &Shortname.ValStat;
		InvalidDates = "N/A";
		Percentage = SUM(MissingValues/Frequency);
	RUN;
%END;

	PROC APPEND BASE = ValStatAll&SourceFile DATA=&Shortname.ValStat;
	QUIT;

%END;

/*NOTES; section below shuld be made into a loop/macro - it repeats 3 times*/

/*ouptut data*/
data _null_ ;          								 			/* no sas data set is created */ 
    set valstatall&sourcefile ; 
    file "&pathname.\output\&sourcefile.valstatall" dlm='|' ;    /* output text file */ 
    put (_all_)(+0);
run;

/*ouptut schema*/
proc contents data=ValStatAll&SourceFile out=ValStatAll&SourceFile._sch noprint;
run;

/*sort columns prior inserting into postgres*/
proc sort data=ValStatAll&SourceFile._sch; by VARNUM; quit;

data _null_;
	format pg_type $100.;
	length strschema $4000;
	retain strschema;
	set valstatall&sourcefile._sch;

	if type = 1 then pg_type = name || 'double precision'; else pg_type = name || 'character(' || length || ')';
	pg_type = trim(left(compbl(pg_type)));
	if _n_ = 1 then strschema = trim(strschema)||' '||trim(pg_type); else strschema = trim(strschema)||','||trim(pg_type);
	keep name type length pg_type strschema;

	call symputx('strschema', strschema);

run;

data _null_ ;          								   		 /* no sas data set is created */ 
    file "&pathname.\output\&sourcefile.valstatall_sch";     /* output text file */ 
	put "create table &sourcefile.valstatall (";
	put "&strschema";
	put ")
		with (
		  oids=false
		);
		alter table &sourcefile.valstatall
		  owner to postgres;";
run;

/*create table in postgres and insert data*/
x "perl &pathname.\output\csv_pg_load.pl &sourcefile.valstatall_sch &sourcefile.valstatall";

/*ouptut data*/
data _null_ ;          								 				  /* no sas data set is created */ 
    set numericanalysis&sourcefile; 
    file "&pathname.\output\&sourcefile.numericanalysis" dlm='|' ;    /* output text file */ 
    put (_all_)(+0);
run ;

/*ouptut schema*/
proc contents data=NumericAnalysis&SourceFile out=NumericAnalysis&SourceFile._sch noprint;
run;

/*sort columns prior inserting into postgres*/
proc sort data=NumericAnalysis&SourceFile._sch; by VARNUM; quit;

data _null_;
	format pg_type $100.;
	length strschema $4000;
	retain strschema;
	set numericanalysis&sourcefile._sch;

	if type = 1 then pg_type = name || 'double precision'; else pg_type = name || 'character(' || length || ')';
	pg_type = trim(left(compbl(pg_type)));
	if _n_ = 1 then strschema = trim(strschema)||' '||trim(pg_type); else strschema = trim(strschema)||','||trim(pg_type);
	keep name type length pg_type strschema;

	call symputx('strschema', strschema);

run;

data _null_ ;          								   		 	  /* no sas data set is created */ 
    file "&pathname.\output\&sourcefile.numericanalysis_sch";     /* output text file */ 
	put "create table &sourcefile.numericanalysis (";
	put "&strschema";
	put ")
		with (
		  oids=false
		);
		alter table &sourcefile.numericanalysis
		  owner to postgres;";
run;

/*create table in postgres and insert data*/
x "perl &pathname.\output\csv_pg_load.pl &sourcefile.numericanalysis_sch &sourcefile.numericanalysis";

/*ouptut data*/
data _null_ ;          								 			  /* no sas data set is created */ 
    set pattfreqall&sourcefile; 
    file "&pathname.\output\&sourcefile.pattfreqall" dlm='|' ;    /* output text file */ 
    put (_all_)(+0);
run ;

/*ouptut schema*/
proc contents data=PattFreqAll&SourceFile out=PattFreqAll&SourceFile._sch noprint;
run;

/*sort columns prior inserting into postgres*/
proc sort data=PattFreqAll&SourceFile._sch; by VARNUM; quit;

data _null_;
	format pg_type $100.;
	length strschema $4000;
	retain strschema;
	set pattfreqall&sourcefile._sch;

	if type = 1 then pg_type = name || 'double precision'; else pg_type = name || 'character(' || length || ')';
	pg_type = trim(left(compbl(pg_type)));
	if _n_ = 1 then strschema = trim(strschema)||' '||trim(pg_type); else strschema = trim(strschema)||','||trim(pg_type);
	keep name type length pg_type strschema;

	call symputx('strschema', strschema);

run;

data _null_ ;          								   		  /* no sas data set is created */ 
    file "&pathname.\output\&sourcefile.pattfreqall_sch";     /* output text file */ 
	put "create table &sourcefile.pattfreqall (";
	put "&strschema";
	put ")
		with (
		  oids=false
		);
		alter table &sourcefile.pattfreqall
		  owner to postgres;";
run;

/*create table in postgres and insert data*/
x "perl &pathname.\output\csv_pg_load.pl &sourcefile.pattfreqall_sch &sourcefile.pattfreqall";


%MEND;

%ProfileData(&in_file);

RUN;
