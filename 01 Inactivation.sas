libname raw "library";

*******************************************************************;
**This program is for generating audit trail for user inactivation in detail **;
*********************************************************************;


proc sql noprint;
  create table all_db as
    select memname from dictionary.tables
	where libname='RAW';

    select count(memname) into: mem_count
	from all_db;
	 
	quit;run;

%put &mem_count;




%let dropvars= projectid--StudySiteId SiteId--Site SiteGroup--instanceId InstanceRepeatNumber--FolderId FolderName TargetDays--DataPageId PageRepeatNumber--RecordId MinCreated--CODER_HIERARCHY;
%let byvars =%str(sitenumber subject instancename folderseq folder  DataPageName recordposition );

%macro inactive(dropvars, byvars);

  %do i=1 %to  &mem_count.;
     data _null_;
      set all_db(firstobs=&i obs=&i);
	  call symput("db",memname);
	  run;
 %put &db;

      data ia_&db.;
      	set raw.&db.;
	   	if RecordActive=0; 
		drop &dropvars.;
		
	  run;
	  proc sort data=ia_&db.;
	    by &byvars;
		run;

proc transpose data=ia_&db. out=trs_ia_&db.;
by &byvars; 
var _all_; run;

data del_trs_ia_&i.;
	set trs_ia_&db.;
	if _NAME_  in ('Subject', 'SiteNumber', 'InstanceName', 'Folder',  'FolderSeq', 'DataPageName', 'RecordPosition', 'RecordActive') then delete;
	if index(_NAME_, '_')>0 then delete;
	Value=left(col1);
	rename _NAME_=Variable _LABEL_=Question;
	temp=_n_;
	drop COL1;
run;


	%end;

%mend inactive; 







%inactive(&dropvars, &byvars); 
proc datasets lib=work noprint;
   delete IA_: TRS_: ;
   run;


%macro combine;


 data All_IA_Pages;
 length sitenumber $4 subject $8 instancename $50 folder $50 DataPageName $100 question $200 value $200; 
 set 
	%do i=1 %to &mem_count.;
	Del_Trs_IA_&i.  
	%end;

;
if missing(InstanceName)=1 then delete;

 run;
%mend;

%combine;

proc sort data=All_IA_Pages ; by sitenumber subject folderseq instancename datapagename recordposition  temp; run;



*************************;
** Audit Trail Data **;
*************************;



PROC IMPORT OUT=Audit DATAFILE= "fromlibrary\Inactivation Report.xlsx" DBMS=xlsx REPLACE; GETNAMES=YES; DATAROW=2; RUN;
proc sort data=audit  ;by site subject folder form ; run;

*****************************;
** Merge eCRF data & Audit Trail  **;
******************************;

proc sql ; 
	create table list_audit as 
	select t1.*, t2.'Audit Action'n, t2.'Audit User'n, t2.'Audit Role'n, t2.'Audit ActionType'n, t2.'Audit Time(GMT)'n as 'Audit Time(GMT)'n
	from all_ia_pages as t1 
	inner join audit as t2 
	on t1.subject=t2.subject and t1.instancename=t2.folder and t1.DataPageName=t2.form;
quit; 






data inactivated_report; 

attrib 
subjid length=$8.
question label='eCRF label'
value label='Entered value from site'
'Audit Time(GMT)'n label='Audit Time(GMT)';



set list_audit; 
subjid=subject;

run;


data inactivated_report;
retain SiteNumber subjid folderseq InstanceName  DataPageName Recordposition Question Value temp  'Audit Action'n 'Audit User'n 'Audit Role'n 'Audit ActionType'n 'Audit Time(GMT)'n;
set inactivated_report;
rename subjid=subject;
keep SiteNumber subjid folderseq InstanceName DataPageName Recordposition Question Value temp 'Audit Action'n 'Audit User'n 'Audit Role'n 'Audit ActionType'n 'Audit Time(GMT)'n;
run;
proc sort data=inactivated_report;by sitenumber subject folderseq instancename datapagename recordposition  temp; run;



data inactivated_report_p;
  set inactivated_report end=last;
  by sitenumber subject folderseq instancename datapagename ;
  retain rows 0 page 1 ;

  if _n_^=1 and ((first.instancename and first.datapagename) or rows ge 15) then do;
   page = page + 1;
   rows=1;
  end;
  if first.subject then do; 
	page = 1; 
	rows=1; 
	end;

  else rows + 1;
run;



*************************;
** Listing to rtf **;
*************************;
options compress=yes;

data _null_;
call symput ("Date", put(date(), date7.));
date=put(date(), date7.);
time=put(time(), time5.);
call symput ("dt", trim(time) | | " / " | | trim(date));
run;





proc sort data=inactivated_report_p out=uniq_p(keep=subject) nodupkey;
  by subject;
run; 


proc sql noprint ;
    select count(subject) into: sbj_count
	from uniq_p;
	quit;run;
 
%put &sbj_count;


%let filepath=outlibrary\CTP1034_InactivatedReport_&DATE._&sbjno..rtf;
%macro sbj_listing(sbj_count);



  %do i=1 %to &sbj_count;
     data _null_;
      set uniq_p(firstobs=&i obs=&i);
	  call symput("sbjno",subject);
	  run;
 %put &sbj_count ; 
 %put &sbjno;

   data prt_&sbj_count;
      set inactivated_report_p (where =(subject="&sbjno"));	
	run;


option nodate nonumber papersize=A4 orientation=landscape;
ods noresults escapechar = "^";
ods listing close;
ods rtf file="&filepath" ;
options nomprint nobyline;

options bottommargin = 0.1cm
           topmargin = 0.1cm
           rightmargin = 0.1cm
	   	   leftmargin = 0.1cm;


title1 height=9pt justify=left "Report ";
title2 height=9pt justify=left "Protocol: ##" justify=right "Page ^{thispage} of ^{lastpage}";
title3 '^S={font=("arial",9pt) just = Center}' "Inactivation Page Listing";
title4 '^S={font=("arial",9pt) just = Center}' "Subject Number: #byval(Subject)";
title5 '^S={font=("arial",9pt) just = left}' "Folder / Data Page: #byval(Instancename) / #byval(datapagename)";
footnote1  height=9pt justify=left  justify=right "Executed: &dt.";


proc report data=prt_&sbj_count   nowindows headline headskip split='*' missing style(header)=[ font=('arial', 9pt, bold) background=Lightsteelblue] style(column)=[ font=('arial', 9pt)];


by subject page instancename datapagename ;
column page subject folderseq instancename datapagename recordposition question value temp 'Audit Action'n 'Audit User'n 'Audit Role'n 'Audit ActionType'n 'Audit Time(GMT)'n;
define page/ group noprint;
define subject/ group noprint;
define folderseq/ group order order=internal noprint;
define instancename/ group id order order=internal display "Folder Name" style={cellwidth=7% just=l};
define datapagename/ display id "DataPage Name" style={cellwidth=11% just=l};
define recordposition/ display "Log Line" style={cellwidth=5% just=l};
define question/ display "eCRF Label" style={cellwidth=14% just=l};
define value/ display "Entered Value*by Site" style={cellwidth=13% just=l};
define temp / order order=internal noprint;
define 'Audit Action'n/ display "Audit Action" style={cellwidth=10% just=l};
define 'Audit User'n/ display "Audit User" style={cellwidth=10% just=l};
define 'Audit Role'n/ display "Audit Role" style={cellwidth=10% just=l};
define 'Audit ActionType'n/ display "Audit ActionType" style={cellwidth=9% just=l};
define 'Audit Time(GMT)'n/ display "Audit Time*(GMT)" style={cellwidth=9% just=l};


run;


ods rtf close;
ods listing close;
 %end; 
 %mend;


%put &sbj_count;
%sbj_listing(&sbj_count);
