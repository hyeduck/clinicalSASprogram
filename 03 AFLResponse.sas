*------------------------------------------------------------------------------------------------------ *;
* Study No:      CLTP1033 AFL                                                                    *;
* Author: Hyewon Jung
* Final Date: 06Jan19;
*------------------------------------------------------------------------------------------------------ *;

proc datasets lib=work memtype=data kill nolist;	quit;



**************************************************************************
*************Proc Import Multiple Sheets from one Excel file***************
**************************************************************************;

%let path= 'library';
libname c1033 xlsx   &path. ; 
 

ods output  Members = c10332 ; 
proc datasets library=c1033 ; run; 




proc sql;
select propcase(Name)
into :catxnam separated by '*'
from c10332
;

select count(Name)
into :n
from c10332;
quit;

%put &catxnam;
%put &n;



options mprint;
%macro importDB;
%do i=1 %to &n;
%let var=%scan(&catxnam,&i,*);

proc import out= WORK.&var.
 datafile = &path.
 dbms=xlsx replace;
 sheet="&var.";
 getnames=Yes;
 datarow=2;
run;
%end;
 
%mend importDB;
%importDB;


*************************************************
*************Derive Radiologic Response*********
*************************************************;




**Keep the Vars from RAWDB;


data target; 
set tl;ctdt=mdy( tadt_m, tadt_d, tadt_y);format ctdt yymmdd10.;  if  tlasses='No' then delete; if missing(talesno)=1 then delete;
keep subjid instancename foldername datapagename recordposition tlloc talesno tasite ctdt axisl axissh tamethm ; 
run;
proc sort data=target nodupkey; by _all_; run;

data nontarget; 
set ntl2 ntl ; ctdt=mdy( tadt_m, tadt_d, tadt_y);format ctdt yymmdd10.; talesno=talesno1; tamethm=tamethm1;
keep subjid instancename foldername datapagename recordposition talesno tasite ctdt tassesm tlasses tamethm ; 
run ;
proc sort data=Nontarget nodupkey; by _all_; run;

data new; 
set nl; ctdt=mdy(tadt_m, tadt_d, tadt_y);format ctdt yymmdd10.;  talesno=talesno2;if not missing(talesno); tamethm=TAMETHM2;
keep subjid instancename foldername datapagename talesno  ctdt  tamethm;
run;
proc sort data=new nodupkey; by _all_; run;


proc datasets lib=work;
modify target;
format _all_; 
informat _all_;
run;



data tumor; 
set Nontarget 
	 Target  
     New;   
run;


**Assign Visit Number; 
data visit; 
set vd; visdt=mdy(visdat_m, visdat_d, visdat_y) ; if instancename='SCR FAILURE' or visdt=.  then delete;
 keep Subjid instancename visdt; format visdt yymmdd10.; run;

proc sort data=visit; by subjid instancename; run;
proc sort data=tumor; by subjid instancename; run;

data visitn; 
merge tumor(in=a) visit; 
by subjid instancename; 
if a;
run;

proc sort data=visitn nodupkey; by subjid instancename visdt; run;
proc sort data=visitn; by subjid visdt instancename; run;


data visitn_2; 
set visitn; 
retain visitnum . ; 
by subjid  visdt instancename; 
if first.instancename ; 
if first.subjid then visitnum=0; 
visitnum=visitnum+1; 
run;
proc sort data=visitn_2 out=visitn_3(drop=visdt); by subjid visitnum; run; 
proc sort data=visitn_3; by subjid instancename;; 
proc sort data=tumor; by subjid instancename; 

%let var = Subjid DataPagename InstanceName Foldername visitnum tamethm Talesno Recordposition TLLOC TASITE TLASSES TASSESM CTDT AXISL AXISSH ;
data raw; 
retain &var.; 
merge tumor(in=x) visitn_3; 
by subjid InstanceName; 
if x; 
run;
proc sort data=raw; by subjid visitnum talesno; run;




*No NTL*; 

proc sql; 
 create table raw0 as 
 select a.*, b.nontlflag from raw as a left join 
(select distinct subjid,  'Not registered' as nontlflag from ntl where tlasses='No') as b 
on a.subjid=b.subjid; run;
proc sort data=raw0; by subjid visitnum  talesno; run;






******Target Lesion Evaluation*********;


**Target Lesion data;
data tl_0; 
set raw0 ; if datapagename='TUMOR ASSESSMENT: TARGET LESIONS'; run;


**PPD, SPD, SPD_Nodal, SPD_Extra Nodal;
data tl_1;
set tl_0; 
if index(tlloc, 'Extra')>0 then tlloc='Extra Nodal Lesion' ;
ppd=axisl*axissh;
run;


proc sql; 
	 create table tl_2 as 
	 select distinct a.*, b.spd, case when missing(b.spd)=1 then . else c.spd_nd end as spd_nd, 
	 case when missing(b.spd)=1 then . else d.spd_ext end as spd_ext
	 from tl_1 as a 

	 left join (select subjid, sum(ppd) as spd, instancename  from tl_1  group by subjid, instancename) as b 
	 on a.subjid=b.subjid and a.instancename=b.instancename

	 left join (select subjid, sum(ppd) as spd_nd, instancename, instancename  from tl_1 where tlloc='Nodal Lesion' group by subjid, instancename, tlloc) as c 
	 on a.subjid=c.subjid and a.instancename=c.instancename
	

	 left join (select subjid, sum(ppd) as spd_ext, instancename, instancename  from tl_1 where index(tlloc, 'Extra')>0  group by subjid, instancename, tlloc) as d 
	 on a.subjid=d.subjid and a.instancename=d.instancename 

	 order by a.subjid, visitnum, talesno; 
quit; 

** Missing PPDs;
proc sort data=tl_1(where=(missing(ppd)=1)) nodupkey out=ppdmis(keep=subjid instancename) ; by subjid instancename ; run;

proc sort data=tl_2; by subjid instancename; run;

**Assign missing to SPD/SPD_ND/SPD_EXT if missing ppd;
data tl_3; 
merge tl_2 (in=x) ppdmis(in=y); 
by subjid instancename; 
if x;
if y then do;  call missing(spd, spd_nd, spd_ext); tl_ua='UA';  end; run;


** Baseline values;
proc sql; create table baseline as 
	select a.*, b.axisl as axisl_b, b.axissh as axissh_b, b.ppd as ppd_b, b.spd as spd_b, b.spd_nd as spd_ndb,   b.spd_ext as spd_extb
	from tl_3  as a  
	left join 
	(select distinct subjid, axisl, axissh, ppd, spd, spd_nd, spd_ext, talesno  from tl_2 where foldername='SCREENING' ) as b 
	on a.subjid=b.subjid and a.talesno=b.talesno
	order by a.subjid, visitnum, talesno;
quit; 

** Normalized?;
data norm; 
set baseline; 

if tlloc='Nodal Lesion' then
 do; 
	if foldername ne 'SCREENING' and (axisl_b > 15 and not missing(axisl) and axisl<=15) then N1='Y';
	if foldername ne 'SCREENING' and ((axisl_b >10 and axisl_b <= 15 and axissh_b >10 ) and not missing(axissh) and axissh<=10 and axisl<=15) then N2='Y'; end;
	if index(tlloc, 'Extra')>0 then 
  	do; 
		if foldername ne 'SCREENING' and ((axisl_b >=10 and axissh_b >=10 ) and axissh=0 and axisl=0) then N3='Y'; 
 	end;

	if N1='Y' or N2='Y' or N3='Y'  then Nflag='Y';

drop N1 N2 N3;
run;



** Percentage of Change from baseline from baseline PPD / SPD ;
data pchg;
set norm; 

if foldername ne 'SCREENING' then do;
pchg_ppd=(ppd-ppd_b)*100/ppd_b;
pchg_spd=(spd-spd_b)*100/spd_b;
pchg_spdnd=(spd_nd-spd_ndb)*100/spd_ndb;
pchg_spdext=(spd_ext-spd_extb)*100/spd_extb;
end;

run;

proc sort data=pchg; by subjid visitnum talesno; run;

data pch2; 
set pchg; 
retain tlvisitnum . ;
by subjid visitnum talesno; 
if first.subjid  then tlvisitnum=0; 
if first.visitnum then tlvisitnum=tlvisitnum+1; run;

proc sort data=pch2; by subjid tlvisitnum talesno; run;

**Calculating Nadir by Overall/Nodal/Extranodal; 

data nadir_1; 

set pch2 ; 
retain nadir nadir_nd nadir_ext ; 

   tlvisitnum=tlvisitnum+1;
	if first.subjid then do ; nadir=spd; nadir_nd=spd_nd; nadir_ext=spd_ext; end;
	by subjid ; 


	if not missing(spd) then do; 
	nadir=min(spd, nadir); 
	nadir_nd = min(spd_nd, nadir_nd); 
	nadir_ext = min(spd_ext, nadir_ext); 
	
	end;

run;


proc sort data=pch2; by subjid tlvisitnum; run;
proc sort data=nadir_1; by subjid tlvisitnum; run;

data nadir; 
merge pch2(in=x) nadir_1(keep=subjid tlvisitnum nadir nadir_nd nadir_ext); 
by subjid tlvisitnum ; 
if x; 
run;
proc sort data=nadir ; by subjid visitnum talesno; run;


**Calculating Percentage of Change from fromNadir by Overall/Nodal/Extranodal;

data final;

	set nadir(drop=tlvisitnum) ; 
	p_nadir=(spd-nadir)*100/nadir;
	p_nadir_nd=(spd_nd-nadir_nd)*100/nadir_nd;
	p_nadir_ext=(spd_ext-nadir_ext)*100/nadir_ext;

run; 
proc sort data=final; by subjid visitnum talesno; run;




***CR***; 


data CR; 
set final(where=(foldername^='SCREENING')) ; 
by subjid visitnum instancename ;

retain flag2;
if Nflag='Y' then flag=1; else flag=0; 

if first.instancename then flag2=flag; 


flag2=min(flag, flag2); 
TL_EV='CR';

if last.visitnum and flag2=1 then output; 

keep subjid instancename visitnum TL_EV; 
run;
proc sort data=CR; by subjid  visitnum; run;

***CRu***; 


data preCRu; 
set final ; 
if not missing(pchg_spd) and PCHG_PPD<-75 and PCHG_SPD<-75 and index(tlloc, 'Extra')=0 and axisl_b>15then Nflag2='Y';
if Nflag='Y' or Nflag2='Y' then CRFlag='Y';
run;


data CRu; 
set preCRu(where=(foldername^='SCREENING')) ; 
by subjid visitnum instancename ;

retain flag2;
if CRFlag='Y' then flag=1; else flag=0; 

if first.instancename then flag2=flag; 


flag2=min(flag, flag2); 
TL_EV_='CRu';
if last.instancename and flag2=1 then output; 

keep subjid instancename visitnum TL_EV_; 

run;
proc sort data=CRu; by subjid  visitnum; run;


data CR_u; 
length TL_CR $50.;
merge CR CRu; 
by subjid visitnum; 

if TL_EV='CR' then TL_CR='CR'; 
else TL_CR='CRu';
drop TL_EV TL_EV_;
run;
proc sort data=CR_u nodupkey; by subjid visitnum; run;


***RD/PD;

/*A target nodal lesion becomes at least a 50% increase 
in the longest axis of any single previously identified node and any axis must be >15 mm after smallest normalization;*/ 

proc sort data=final out=small_0; by subjId talesno visitnum; run;

data small_1; 
set small_0; 
np0=ppd; 
nl0= axisl; 
run;

%macro rd(endno);

     %do no=1 %to &endno.;

     %let np= %sysfunc(cats(np, &no.));
	 %let nl= %sysfunc(cats(nl, &no.));

	 %put &np;
	 %put &nl;


	 %let pnp= %sysfunc(cats(np, %eval(&no - 1)));
	 %let pnl= %sysfunc(cats(nl, %eval(&no - 1)));
	
	 %put &pnp;
	 %put &pnl;



data small_%eval(&no.+1); 
set small_&no.; 
by subjid talesno visitnum ; 

retain &np. &nl. ; 

if first.talesno then do; 
&np.=.; &nl.=.;  
end;

output; 

if  nflag='Y' then do ; 
&np.= &pnp.; 
&nl.=&pnl. ; 
end;

run;



	%end;

%mend ;

options mprint;

**************************;
proc sort data=final nodupkey out=unq_subjVS(keep= subjid instanceName ); ;
  by subjid instanceName ;
  
  run;

data unq_subjvs;
   	set unq_subjvs;
      no=1;
	  run;

 proc summary data=unq_subjvs nway;
   class subjid ;
    var no;
   output out=unq_subjvs_max sum=  ;
   run;
  
   proc sql noprint;
     select max(no) into : maxvisit
	 from unq_subjvs_max;
	 quit;

	 %put &maxvisit;

%rd(&maxvisit);


data rdpd1; 
set small_%eval(&maxvisit.+1); 
smallppd=min(np1, np2, np3, np4, np5, np6, np7, np8, np9, np10, np11, np12); ***##** max 만큼 수정**;

 if nmiss(np1, np2, np3, np4, np5, np6, np7, np8, np9, np10, np11, np12) < 9 then
do; 
 if np1=smallppd then longesta=nl1;
 if np2=smallppd then longesta=nl2;
 if np3=smallppd then longesta=nl3;
 if np4=smallppd then longesta=nl4;
 if np5=smallppd then longesta=nl5;
 if np6=smallppd then longesta=nl6;
 if np7=smallppd then longesta=nl7;
 if np8=smallppd then longesta=nl8;
 if np9=smallppd then longesta=nl9;
 if np10=smallppd then longesta=nl10;
 if np11=smallppd then longesta=nl11;
 if np12=smallppd then longesta=nl12;
 end;

pchg_long=(axisl-longesta)*100/longesta;
 if (axisl>15 or axissh>15) and pchg_long>=50 ; 
tl_rdpd='RD/PD';
com='a 50% increase any axis must be >15 mm after smallest normalization';

if not missing(np1) then prevnorm='Y';

drop np0--nl12; 
keep subjid instancename visitnum visit tl_rdpd pchg_long com talesno ;

run;


*3) >=50% increase in SPD of maximal 6 nodal target lesions or 8 extranodal target lesions;


data rdpd2;
set final; 
if p_nadir_nd>=50 or p_nadir_ext>=50; 
TL_RDPD= 'RD/PD'; 
com='>=50% increase in SPD';
keep subjid instancename visitnum  TL_RDPD  com;  
run;
proc sort data=rdpd2 nodupkey; by subjid visitnum TL_RDPD com; run;



data rdpd; 
set rdpd1(drop=talesno) rdpd2 ; 
run;
proc sort data=rdpd; by subjid visitnum tl_rdpd com;  run;


**PR;

data PR; 
set final ;
if  pchg_spd^=. and pchg_spd<-50 ; 
TL_PR='PR'; 
keep subjid instancename visitnum TL_PR; 
run; 
proc sort data=PR nodupkey; by subjid visitnum ; run;



**Target Lesion Results;
data tlresp0 ;
Length TL_RS $50.; 
merge cr_u rdpd  pr  ; 
by subjid visitnum;

if not missing(TL_PR) then TL_RS=TL_PR; 
if not missing(TL_RDPD) then TL_RS=TL_RDPD; 
if not missing(TL_CR) then TL_RS=TL_CR; 

if TL_RS^='RD/PD' then com='';
drop TL_PR TL_RDPD TL_CR;
run;


**UA;
data tlresp1; 
merge final(in=x) tlresp0; 
by subjid visitnum; 
if x; 
if TL_UA='UA' then TL_RS='UA';
drop TL_UA;
run;

**SD;
**Final;
data tlresp_final; 
set tlresp1;
by subjid visitnum; 
if missing(TL_RS)=1 and foldername^='SCREENING' then TL_RS='SD';
run; 

proc sort data=tlresp_final nodupkey dupout=xxx  ; by subjid visitnum talesno; run;




/*Non Target*/; 
data ntl0; 
set raw0; 
if index(datapagename, 'NON')>0; 
run;
proc sort data=ntl0; by subjid visitnum talesno; run;

data  ntl1;
length NTL_RS $40.;
set ntl0; 

by subjid visitnum instancename ;

retain flag2;
if tassesm='Present' then flag=1; 
else if tassesm='Absent' then flag=0;
else if tassesm='Not Assessed' then flag=2;

if first.instancename then flag2=flag; 

flag2=max(flag, flag2); 



if last.visitnum and flag2=1 then NTL_RS='Non CR';
if last.visitnum and flag2=0 then NTL_RS='CR';
if last.visitnum and flag2=2 then NTL_RS='UA';

keep subjid ntl_rs visitnum instancename ;

if last.visitnum and instancename^='SCREENING' then output;

run;

proc sort data=ntl0; by subjid visitnum; run;
proc sort data=ntl1; by subjid visitnum; run;



**NTL Final;
data ntlresp_final; 
length ntl_rs $40.;
merge ntl0(in=a) ntl1(rename=(ntl_rs=ntl_rs2)); 

by subjid visitnum ; 
if a; if tlasses='No' then NTL_RS='UA';
if nontlflag='Not registered' then ntL_rs='UA'; 
if missing(NTL_RS) =1 then NTL_RS=NTL_RS2; 
drop ntl_rs2;
run;


/*New Lesion*/; 
data nlresp_final;;
set raw0; 
if index(datapagename,  'NEW')>0;
NL_RS='PD';
keep subjid instancename visitnum NL_RS; 
run;
proc sort data=nlresp_final nodupkey ; by _all_; run;


****Final-Radiologic Response***;

proc sort data=raw0; by subjid datapagename visitnum  talesno; run;
proc sort data=tlresp_final(drop=tl_rs) out=tlresp_temp; by subjid  datapagename visitnum  talesno; run;
 
data tls; 
merge raw0 (in=a) tlresp_temp; 
by subjid  datapagename visitnum  talesno ; 
if a; run;
proc sort data=tls; by subjid visitnum talesno; run;

proc sort data=tlresp_final (keep=subjid visitnum tl_rs) nodupkey; by subjid visitnum tl_rs; run;
proc sort data=ntlresp_final (keep=subjid visitnum ntl_rs) nodupkey; by subjid visitnum ntl_rs; run;
proc sort data=nlresp_final (keep=subjid visitnum nl_rs) nodupkey ; by subjid visitnum nl_rs; run;



data radio; 
merge tls(in=x) tlresp_final ntlresp_final nlresp_final; 
by subjid visitnum; 
if ntl_rs='UA' and instancename='SCREENING' then call missing(ntl_rs); 
if x; 
run;


data rs; set re; 
keep subjid instancename iwg99ntl iwg99oen iwg99ldh iwg99bsp iwg99bmi iwg99rsp iwg99dt_c ; run;
proc sort data=rs nodupkey; by _all_; run;
proc sort data=radio; by subjid instancename; run;

data radioresp; 
merge radio(in=a) rs; 
by subjid instancename;

length radiologic $3.; 
if a; 


if tl_rs='CR' and nontlflag in ('Not registered') and nl_rs^='PD'   then radiologic='CR'; 
if tl_rs='CR' and ntl_rs in ('CR') and nl_rs^='PD'   then radiologic='CR'; 
if tl_rs='CRu' and ntl_rs in ('CR') and nl_rs^='PD'   then radiologic='CRu'; 
if tl_rs='CRu' and nontlflag in ('Not registered') and nl_rs^='PD'     then radiologic='CRu'; 
if tl_rs='CR' and ntl_rs in ('Non CR')  then radiologic='PR'; 
if tl_rs='CRu' and ntl_rs in ('Non CR')   then radiologic='PR'; 
if tl_rs='PR'  then radiologic='PR';
if tl_rs='SD'  then radiologic='SD';
if tl_rs='RD/PD' or (iwg99ntl='PD' and NTL_RS='Non CR') or nl_rs='PD'  then radiologic='PD';
if tl_rs='UA' or (ntl_rs='UA' and nontlflag^='Not registered') then radiologic='UA'; 

drop  nontlflag;
run;



data prevn;
set small_10; 
if not missing(np1) ; prevnorm='Y';
keep subjid instancename visitnum talesno prevnorm;
run;
proc sort data=prevn; by subjid visitnum talesno; run;
proc sort data=radioresp; by subjid visitnum talesno; run;

data radio_final; 
merge radioresp(in=a) prevn; 
by subjid visitnum talesno; 
if a; 
run;




*******************************************************************
*************************Bone Marrow******************************
*******************************************************************;
proc sort data=bm out=bmexam; by subjid instancename; run;
proc sort data=visit; by subjid instancename; run;

data bm_vs;
merge bmexam(in=a where=(index(instancename, 'UNSCHEDULED')=0)) visit(keep=subjid instancename visdt); 
by subjid instancename;
if a; 
bpdat=mdy(bpdt_m, bpdt_d, bpdt_y); 
format bpdat yymmdd10.;
run;

data bm_vs2;
set bm_vs bmexam(where=(index(instancename, 'UNSCHEDULED')>0) in=b); 
if b then visdt=bpdat;
run;
proc sort data=bm_vs2; by subjid visdt; run;

data bm; 
set bm_vs2; 
retain current prev ; 
by subjid visdt ;


if first.subject then current=bpres;
if not missing(bpres) then current=bpres;


if not missing(visdt);


keep subjid datapagename instancename bmexyn_cv bmexyn bpdat bpres  current visdt;

run;
proc sort data=bm; by subjid visdt bpdat; run;



*Recurrence*; 
data bm2; 
set bm; 
by subjid visdt;
retain last '               ' ;
if first.subjid then last='' ;  
output;
last=current; 
run;

data bm3; 
set bm2; 
if current='Positive' and last='Negative' then reccur='Y'; run;


proc sort data=bm3; by subjid instancename; run;
proc sort data=radio_final; by subjid instancename; run;

data bm4; 
merge radio_final (in=a) bm3(drop=datapagename); 
by subjid instancename; 
if a; 
drop bmexyn--bpdat;
run;
proc sort data=bm4; by subjid visitnum; run;


data bm5; 
set bm4; 
retain bmres ; 
if not missing(current) then bmres=current ; 
drop current last ;
run;

****Final-Overall Response***;

data ovresp; 
length ovr $5.;
set bm5; 
if radiologic='CR' and bmres='Negative' and IWG99BSP='Absent' and IWG99OEN='Normal'  and iwg99ldh='Normal' then ovr='CR';
if radiologic='CRu' and bmres='Negative' and IWG99BSP='Absent' and IWG99OEN='Normal'  and iwg99ldh='Normal' then ovr='CRu';
if radiologic in ('CR', 'CRu') and bmres='Indeterminate' and IWG99BSP='Absent' and IWG99OEN='Normal'  and iwg99ldh='Normal' then ovr='CRu';
if radiologic in ('CRu', 'CR') and (bmres='Positive' or IWG99BSP='Present') then ovr='PR'; 
if radiologic in ('CRu', 'CR') and missing(iwg99ldh)=1 then ovr='PR'; 
if radiologic in ('CRu', 'CR') and iwg99ldh='Abnormal' then ovr='PR'; 
if radiologic in ('PR', 'SD') then ovr=radiologic; 
if radiologic in ('PD') then ovr='PD'; 
if radiologic in ('UA') then ovr='UA';
if IWG99OEN in ('Unequivocal increased') then ovr='PD';
if reccur='Y' then ovr='PD'; 
run;
proc sort data=ovresp; by subjid  talesno visitnum; run;





%let finalvar = subjid datapagename instancename foldername visitnum tamethm methodflag talesno recordposition tlloc tasite tlasses tassesm ctdt 
axisl axissh ppd spd spd_nd spd_ext axisl_b axissh_b ppd_b spd_b spd_ndb spd_extb nflag pchg_ppd pchg_spd pchg_spdnd pchg_spdext nadir nadir_nd
nadir_ext p_nadir p_nadir_nd p_nadir_ext pchg_long prevnorm  tl_rs ntl_rs iwg99ntl  nl_rs radiologic iwg99bmi iwg99rsp iwg99oen iwg99ldh iwg99bsp reccur bmres ovr ;

data final1033 ; 
retain &finalvar;
set ovresp; 
keep &finalvar;
run;




