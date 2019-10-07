
*------------------------------------------------------------------------------------------------------ *;
* Study No:      RA Study Analysis                                                                    *;
* Author: Hyewon Jung
* Final Date: 17Apr16;
*------------------------------------------------------------------------------------------------------ *;

ods html newfile=proc;
options compress=yes;

**************************;
**  Set up TLF NAME   **;  
**************************;
%let TLF=Table 14.2.4.2;

*****************************;
**  Define Export Filepath  **;  
******************************;
/*HyeWon Jung*/
%let datasets=library\datasets;
%let filepath=library2\&TLF..rtf;
%include "fromlibrary\ODS_MACRO.sas";

libname adata "&datasets";



proc format;
value visit   80='Baseline'
				90='Screening'
				100='Week 0 (D0)'
				160='Week 4'
				170='Week 8'
				180='Week 12'
				190='Week 16'
				200='Week 20'
				210='Week 24'
				320='End of Study'
				610='Unscheduled';

value trt 1='CT-P10'
			2='Rituxan+MabThera';

value prmdas 6='DAS28(ESR)'
				  7='EULAR(ESR)'
				  8='DAS28(CRP)'
				  9='EULAR(CRP)';
run;

*****************;
** Obtain data **;
*****************;
data adas;
 	set	adata.addas;
    if trt01an in (2 3) then trt01an=2;
run;



***Efficacy Population***;
proc sort data=adas out=addas;
by paramn avisitn;
run;
proc freq data=addas noprint;
where effl='Y' and dtype='DAS28' and avisitn eq 210 and adanfl='Y' and chg NE . and base NE . and JSRFL ne 'Y' and PROHFL ne 'Y' ;
table paramn*trt01an/out=freqtable;
run;

ods output lsmeans=lsm(drop=trt01an);
ods output lsmeandiffcl=pdiff;
proc glm data=addas plots=none;
where effl='Y' and dtype='DAS28' and avisitn eq 210 and adanfl='Y' and chg NE . and base NE . and JSRFL ne 'Y' and PROHFL ne 'Y' ;
class trt01an sex region race atnfctmn pdblmn  ; 
model chg=trt01an sex region race atnfctmn pdblmn ; 
lsmeans  trt01an /alpha=0.05  pdiff cl stderr;
by paramn avisitn;
run;
quit;

data lsm;
set lsm;
i=_n_;
if i in (1,3) then trt01an=1; else trt01an=2;
sderr='('||put(stderr,6.3)||')';
run;

data pdiff;
set pdiff;
CI='('||put(round(lowercl, 0.01) , 6.2)||','||put(round(uppercl, 0.01) , 6.2)||')';
run;

proc sort data=freqtable; by  paramn trt01an;run;
proc sort data=lsm; by paramn  trt01an;run;
proc sort data=pdiff; by paramn trt01an;run;

data results;
merge freqtable(keep=paramn trt01an count) lsm(keep=paramn trt01an lsmean sderr) pdiff(keep=paramn  trt01an difference CI);
by paramn trt01an;
run;

data dummy;
do paramn=6,8 ;
do trt01an=0,1,2,3;
output; end; end; 
run;
proc sort data=dummy; by paramn trt01an; run;

data final;
merge results dummy;
by paramn trt01an;
format text $200.;
count1=put(count, 6.0);
lsmean1=put(round(lsmean, 0.01), 6.2) ||sderr;
difference1=compress(put(round(difference, 0.01), 6.2));
if trt01an=0 or trt01an=3 then do; text=put(paramn, prmdas.) ; count1=" " ;  lsmean1=" " ;  difference1=" " ; ci=" " ; end;
if trt01an=2 then difference1="";
if trt01an in (1,2) then text="^w^w"||put(trt01an, trt.);
drop count lsmean sderr difference;
if trt01an=3 and paramn=6 then delete;
if trt01an=3 and paramn=8 then text="";
run;


***All-Randomized Population***;
proc sort data=adas out=addas;
by paramn avisitn;
run;
proc freq data=addas noprint;
where randfl='Y' and dtype='DAS28' and avisitn eq 210 and adanfl='Y' and chg NE . and base NE . and JSRFL ne 'Y' and PROHFL ne 'Y' ;
table paramn*trt01an/out=freqtable;
run;

ods output lsmeans=lsm(drop=trt01an);
ods output lsmeandiffcl=pdiff;
proc glm data=addas plots=none;
where randfl='Y' and dtype='DAS28' and avisitn eq 210 and adanfl='Y' and chg NE . and base NE . and JSRFL ne 'Y' and PROHFL ne 'Y'  ;
class trt01an sex region race atnfctmn pdblmn;
model chg=trt01an sex region race atnfctmn pdblmn;
lsmeans  trt01an /alpha=0.05  pdiff cl stderr;
by paramn avisitn;
run;
quit;

data lsm;
set lsm;
i=_n_;
if i in (1,3) then trt01an=1; else trt01an=2;
sderr='('||put(stderr,6.3)||')';
run;

data pdiff;
set pdiff;
CI='('||put(round(lowercl, 0.01) , 6.2)||','||put(round(uppercl, 0.01) , 6.2)||')';
run;

proc sort data=freqtable; by  paramn trt01an;run;
proc sort data=lsm; by paramn  trt01an;run;
proc sort data=pdiff; by paramn trt01an;run;

data results;
merge freqtable(keep=paramn trt01an count) lsm(keep=paramn trt01an lsmean sderr) pdiff(keep=paramn  trt01an difference CI);
by paramn trt01an;
run;

data dummy;
do paramn=6,8 ;
do trt01an=0,1,2,3;
output; end; end; 
run;
proc sort data=dummy; by paramn trt01an; run;

data final2;
merge results dummy;
by paramn trt01an;
format text $200.;
count1=put(count, 6.0);
lsmean1=put(round(lsmean, 0.01), 6.2) ||sderr;
difference1=compress(put(round(difference, 0.01), 6.2));
if trt01an=0 or trt01an=3 then do; text=put(paramn, prmdas.) ; count1=" " ;  lsmean1=" " ;  difference1=" " ; ci=" " ; end;
if trt01an=2 then difference1="";
if trt01an in (1,2) then text="^w^w"||put(trt01an, trt.);
drop count lsmean sderr difference;
if trt01an=3 and paramn=6 then delete;
if trt01an=3 and paramn=8 then text="";
run;


*********************;
** Generate report **;
*********************;
%odsout;
 title1 font="arial" height=9pt justify=left "Report." ; 
 title2 font="arial" height=9pt justify=left "Protocol: ##" justify=right "Page ^{pageof}";
 title3 '^S={font=("arial",9pt) just = center}' 'Table 14.2.4.2';
 title4 '^S={font=("arial",9pt) just = center}' 'Analysis of Change from Baseline of DAS28 (ANCOVA) ';
 title5 '^S={font=("arial",9pt) just = center}' 'All-Randomized Population - Antibody Negative Subset';
 title6;
footnote1 '^S={font=("arial",9pt) just = left}' "Note: The primary analysis for DAS28 is an analysis of covariance (ANCOVA) comparing the change from baseline of DAS28 at 24 weeks of treatment between two groups,";
 footnote2 '^S={font=("arial",9pt) just = left}' "CT-P10 and Reference products (Rituxan + MabThera), considering the treatment as a fixed effect and Gender, Region, Race, prior anti-TNF-α blocker status (intolerance";
 footnote3 '^S={font=("arial",9pt) just = left}' "case versus inadequate response), and RF or anti-CCP status (both positive versus both negative versus either RF or anti-CCP negative) as covariates. 
Adjusted least squares means and standard error, estimate of treatment difference [CT-P10 – (Rituxan + MabThera)] and 2-sided 95% confidence interval calculated from the ANCOVA model." ;
 footnote4  font="arial" height=9pt  justify=left "Source Data: Listing 16.2.6.17 and 16.2.9.6"  justify=right "Executed: &dt.";

proc report data=final2 nowd split='*' nowindows headline headskip missing
  style=[cellpadding=1.5pt]
  style(header)=[ just=left font=('arial', 9pt, bold) background=Lightsteelblue]
  style(report)=[ just=center font=('arial', 9pt)  frame=hsides rules=groups borderwidth=1.2pt background=white ]
  style(lines)=[ font_size=2pt]
  style(column)=[ just=center font=('arial', 9pt)];

column paramn  trt01an text count1 lsmean1  difference1 CI;
define paramn/ order descending noprint;
define trt01an/ order noprint;
define text/ order order=data 'Parameter*^w^wTreatment' style={cellwidth=29% just=l};
define count1/ display 'n' style={cellwidth=10% just=c};
define lsmean1/ display  'Adjusted mean (SE)' style={cellwidth=14% just=c};
define difference1/ display  'Estimate of treatment*difference' style={cellwidth=22% just=c};
define CI/ display '95% CI of*treatment difference' style={cellwidth=22% just=c};

compute before;
    line ' ';
endcomp;
compute after;
    line ' ';
endcomp;
run;


 title5 '^S={font=("arial",9pt) just = center}' 'Efficacy Population - Antibody Negative Subset';
 title6;
footnote1 '^S={font=("arial",9pt) just = left}' "Note: The primary analysis for DAS28 is an analysis of covariance (ANCOVA) comparing the change from baseline of DAS28 at 24 weeks of treatment between two groups,";
 footnote2 '^S={font=("arial",9pt) just = left}' "CT-P10 and Reference products (Rituxan + MabThera), considering the treatment as a fixed effect and Gender, Region, Race, prior anti-TNF-α blocker status (intolerance";
 footnote3 '^S={font=("arial",9pt) just = left}' "case versus inadequate response), and RF or anti-CCP status (both positive versus both negative versus either RF or anti-CCP negative) as covariates. 
Adjusted least squares means and standard error, estimate of treatment difference [CT-P10 – (Rituxan + MabThera)] and 2-sided 95% confidence interval calculated from the ANCOVA model." ;
 footnote4  font="arial" height=9pt  justify=left "Source Data: Listing 16.2.6.17 and 16.2.9.6"  justify=right "Executed: &dt.";
proc report data=final nowd split='*' nowindows headline headskip missing
  style=[cellpadding=1.5pt]
  style(header)=[ just=left font=('arial', 9pt, bold) background=Lightsteelblue]
  style(report)=[ just=center font=('arial', 9pt)  frame=hsides rules=groups borderwidth=1.2pt background=white ]
  style(lines)=[ font_size=2pt]
  style(column)=[ just=center font=('arial', 9pt)];

column paramn  trt01an text count1 lsmean1  difference1 CI;
define paramn/ order descending noprint;
define trt01an/ order noprint;
define text/ order order=data 'Parameter*^w^wTreatment' style={cellwidth=29% just=l};
define count1/ display 'n' style={cellwidth=10% just=c};
define lsmean1/ display  'Adjusted mean (SE)' style={cellwidth=14% just=c};
define difference1/ display  'Estimate of treatment*difference' style={cellwidth=22% just=c};
define CI/ display '95% CI of*treatment difference' style={cellwidth=22% just=c};

compute before;
    line ' ';
endcomp;
compute after;
    line ' ';
endcomp;
run;

%odsclose;

