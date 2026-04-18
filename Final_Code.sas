PROC IMPORT DATAFILE="/home/u64451712/WDSTS_CleanedData.xlsx"
	OUT=wdsts_raw DBMS=xlsx REPLACE;
    SHEET="Cleaned data";
    GETNAMES=Yes;
RUN; 

DATA wdsts_confirmed;
    SET wdsts_raw;
    WHERE gen_diagnose = "Yes";
RUN;

PROC FREQ DATA=wdsts_confirmed;
    TABLES gen_diagnose;
RUN;

DATA wdsts_confirmed1;
    SET wdsts_confirmed;

    age_dx_raw = STRIP(LOWCASE('Age at the diagnosis'n));
    age_dx_years = .;

    IF NOT MISSING(age_dx_raw) THEN DO;

        /* Extract numeric portion */
        num = INPUT(COMPRESS(age_dx_raw,,'kd'),8.);

        /* If contains any form of year */
        IF INDEX(age_dx_raw,'yr') > 0 OR
           INDEX(age_dx_raw,'year') > 0 OR
           INDEX(age_dx_raw,'y') > 0 THEN
            age_dx_years = num;

        /* If contains month */
        ELSE IF INDEX(age_dx_raw,'m') > 0 THEN
            age_dx_years = num / 12;

    END;

    DROP num;
RUN;

PROC SORT DATA=wdsts_confirmed1;
    BY DESCENDING age_dx_years;
RUN;

PROC PRINT DATA=wdsts_confirmed1 (OBS=10);
    VAR age_dx_raw age_dx_years;
RUN;


PROC FREQ DATA=wdsts_confirmed1;
    TABLES participant_country / NOCUM;
RUN;

/* Table 1*/
PROC MEANS DATA=wdsts_confirmed1 MEDIAN MEAN N;
    CLASS participant_country;
    VAR age_dx_years ;
RUN;

/* FIGURE 1: Age at Diagnosis  */

ODS GRAPHICS / RESET WIDTH=6in HEIGHT=6in
    IMAGENAME="Figure1_Agedx_Confirmed";

ODS LISTING GPATH="/home/u64451712/";

PROC SGPLOT DATA=wdsts_confirmed1;
    VBOX age_dx_years;
    YAXIS LABEL="Age at Diagnosis (Years)";
    TITLE "Age at Diagnosis (Genetically Confirmed, n=137)";
RUN;

ODS LISTING CLOSE;


/* Table 2A - Number of hospitalizations */

PROC FREQ DATA=wdsts_confirmed NOPRINT;
    TABLES treat_hospital / OUT=hosp_freq;
RUN;

DATA table2a;
    SET hosp_freq;

    /* Convert to numeric */
    hosp_num = INPUT(treat_hospital, BEST12.);

    IF MISSING(hosp_num) THEN hosp_label = "(blank)";
    ELSE hosp_label = STRIP(PUT(hosp_num, 8.));

    percent = ROUND(PERCENT, 0.1);

    KEEP hosp_num hosp_label COUNT percent;
RUN;

/* Sort numerically */
PROC SORT DATA=table2a;
    BY hosp_num;
RUN;

TITLE "Number of Hospitalizations (n=&total_confirmed)";

PROC PRINT DATA=table2a NOOBS LABEL;
    VAR hosp_label COUNT percent;

    LABEL hosp_label = "Number of hospitalizations"
          COUNT      = "Number of participants (n)"
          percent    = "Percentage";
RUN;

TITLE;

/* Figure 2 */

ODS GRAPHICS / RESET WIDTH=6 in HEIGHT=6in
    IMAGENAME="Figure2_Hospitalization";

ODS LISTING GPATH="/home/u64451712/";

PROC SGPLOT DATA=hosp_yesno;
    HBAR hosp_label /
         RESPONSE=percent
         DATALABEL
         CATEGORYORDER=RESPDESC;
    XAXIS LABEL="Percentage (%)";
    YAXIS LABEL="Number of Hospitalizations";
    TITLE "Hospitalization Status (n=137)";
RUN;

ODS LISTING CLOSE;


/* Table 2B - reasons of hospitalizations*/
DATA hosp_long;
    SET wdsts_confirmed;

    LENGTH hosp_reason $100;

    IF treat_hospReas = "Participant was never hospitalized" THEN DELETE;

    /* Skip missing */
    IF MISSING(treat_hospReas) THEN DELETE;

    num_items = COUNTW(treat_hospReas, ',');

    DO i = 1 TO num_items;
        hosp_reason = STRIP(SCAN(treat_hospReas, i, ','));
        OUTPUT;
    END;

    KEEP participant_id hosp_reason;
RUN;

/* removing duplicates */
PROC SORT DATA=hosp_long NODUPKEY;
    BY participant_id hosp_reason;
RUN;

/* % count */
PROC FREQ DATA=hosp_long NOPRINT;
    TABLES hosp_reason / OUT=hosp_counts;
RUN;

/* percent relative to 137 confirmed patients */
%LET total_confirmed = 137;

DATA hosp_counts_final;
    SET hosp_counts;
    percent_of_total = (COUNT / &total_confirmed) * 100;
RUN;

PROC SORT DATA=hosp_counts_final;
    BY DESCENDING COUNT;
RUN;

PROC PRINT DATA=hosp_counts_final;
    VAR hosp_reason COUNT percent_of_total;
RUN;

/* ≥5% cutoff */
DATA hosp_counts_5pct;
    SET hosp_counts_final;
    IF percent_of_total >= 5;
RUN;

PROC PRINT DATA=hosp_counts_5pct;
    VAR hosp_reason COUNT percent_of_total;
RUN;

DATA table2b;
    SET hosp_counts_5pct;

    percent = ROUND(percent_of_total, 0.1);

    KEEP hosp_reason COUNT percent;
RUN;

PROC SORT DATA=table2b;
    BY DESCENDING COUNT;
RUN;

TITLE "Reason that the participant was hospitalized";
PROC PRINT DATA=table2b NOOBS LABEL;
    LABEL hosp_reason = "Reason"
          COUNT = "Number of participants (n)"
          percent = "Percentage";
RUN;
TITLE;

/* FIGURE 3: Hospitalization Reasons (≥5%) */

DATA hosp_plot;
    SET hosp_counts_5pct;
    percent_of_total = ROUND(percent_of_total,0.1);
RUN;

ODS GRAPHICS / RESET WIDTH=6in HEIGHT=6in
    IMAGENAME="Figure3_HospitalReasons";

ODS LISTING GPATH="/home/u64451712/";

PROC SGPLOT DATA=hosp_plot;
    HBAR hosp_reason / RESPONSE=percent_of_total DATALABEL;
    XAXIS LABEL="Percentage of Confirmed Participants (%)";
    YAXIS LABEL="Reason for Hospitalization";
    TITLE "Hospitalization Reasons (≥5%, n=137)";
RUN;

ODS LISTING CLOSE;

/* Table 3A - num of surgeries*/

PROC FREQ DATA=wdsts_confirmed NOPRINT;
    TABLES treat_surg / OUT=surg_freq;
RUN;

DATA table3a;
    SET surg_freq;

    /*numeric conversion */
    surg_num = INPUT(treat_surg, BEST12.);

    percent = ROUND(PERCENT, 0.1);

    LENGTH surg_display $20;

    IF MISSING(surg_num) THEN surg_display = "Blank/Missing";
    ELSE surg_display = STRIP(PUT(surg_num, 8.));

    KEEP surg_display surg_num COUNT percent;
RUN;

/* Sort numerically (missing first) */
PROC SORT DATA=table3a;
    BY surg_num;
RUN;

TITLE "Number of Surgeries (n=&total_confirmed)";

PROC PRINT DATA=table3a NOOBS LABEL;
    VAR surg_display COUNT percent;

    LABEL surg_display = "Number of surgeries"
          COUNT        = "Number of participants (n)"
          percent      = "Percentage";
RUN;

TITLE;


ODS GRAPHICS / RESET WIDTH=6in HEIGHT=6in
    IMAGENAME="Figure4_NumberOfSurgeries";

ODS LISTING GPATH="/home/u64451712/";

PROC SGPLOT DATA=surg_yesno_plot;
    HBAR surg_label /
         RESPONSE=percent
         DATALABEL
         CATEGORYORDER=RESPDESC;
    XAXIS LABEL="Percentage of Confirmed Participants (%)" GRID;
    YAXIS LABEL="Number of Surgeries";
    TITLE "Number of Surgeries (n=137)";
RUN;

ODS LISTING CLOSE;


/* Table 3B - kind of surgeries*/
DATA surgery_long;
    SET wdsts_confirmed;

    LENGTH surgery_type $100;

    IF treat_surgReas = "Participant never had surgery" THEN DELETE;
    
    IF MISSING(treat_surgReas) THEN DELETE;
    
    num_items = COUNTW(treat_surgReas, ',');

    DO i = 1 TO num_items;
        surgery_type = STRIP(SCAN(treat_surgReas, i, ','));
        OUTPUT;
    END;

    KEEP participant_id surgery_type;
RUN;

/* removing duplicates */
PROC SORT DATA=surgery_long NODUPKEY;
    BY participant_id surgery_type;
RUN;

/* % count - percent relative to total rows in surgery_long */
PROC FREQ DATA=surgery_long NOPRINT;
    TABLES surgery_type / OUT=surg_counts;
RUN;

/* percent relative to 137 confirmed patients */
%LET total_confirmed = 137;   

DATA surg_counts_final;
    SET surg_counts;
    percent_of_total = (COUNT / &total_confirmed) * 100;
RUN;

PROC SORT DATA=surg_counts_final;
    BY DESCENDING COUNT;
RUN;

PROC PRINT DATA=surg_counts_final;
    VAR surgery_type COUNT percent_of_total;
RUN;


/* ≥5% cutoff */
DATA surg_counts_5pct;
    SET surg_counts_final;
    IF percent_of_total >= 5;
RUN;

PROC PRINT DATA=surg_counts_5pct;
     VAR surgery_type COUNT percent_of_total;
RUN;


/* Table 3B - Reasons for surgery (≥5%) */

DATA table3b;
    SET surg_counts_5pct;

    percent = ROUND(percent_of_total, 0.1);

    KEEP surgery_type COUNT percent;
RUN;

PROC SORT DATA=table3b;
    BY DESCENDING COUNT;
RUN;

TITLE "Reason that the participant had surgery (≥5%)";

PROC PRINT DATA=table3b NOOBS LABEL;
    VAR surgery_type COUNT percent;

    LABEL surgery_type = "Reason for surgery"
          COUNT        = "Number of participants (n)"
          percent      = "Percentage";
RUN;

TITLE;

/* FIGURE 5: Types of Surgeries (≥5%)  */
ODS GRAPHICS / RESET WIDTH=6in HEIGHT=6in
    IMAGENAME="Figure5_SurgeryTypes";

ODS LISTING GPATH="/home/u64451712/";

PROC SGPLOT DATA=surg_plot;
    HBAR surgery_type /
         RESPONSE=percent_of_total
         DATALABEL
         CATEGORYORDER=RESPDESC;
    XAXIS LABEL="Percentage of Confirmed Participants (%)";
    YAXIS LABEL="Type of Surgery";
    TITLE "Types of Surgeries (≥5%, n=137)";
RUN;

ODS LISTING CLOSE;


/* TABLE 5 – Therapies Received */
DATA therapy_long;
    SET wdsts_confirmed;

    LENGTH therapy_type $100;

    IF MISSING(ther_service) THEN DELETE;

    num_items = COUNTW(ther_service, ',');

    DO i = 1 TO num_items;
        therapy_type = STRIP(SCAN(ther_service, i, ','));
        OUTPUT;
    END;

    KEEP participant_id therapy_type;
RUN;

/* removing duplicates */
PROC SORT DATA=therapy_long NODUPKEY;
    BY participant_id therapy_type;
RUN;

/*Count number per therapy */
PROC FREQ DATA=therapy_long NOPRINT;
    TABLES therapy_type / OUT=therapy_counts;
RUN;

/* percent out of confirmed patients */
%LET total_confirmed = 137;

DATA therapy_counts_final;
    SET therapy_counts;
    percent_of_total = (COUNT / &total_confirmed) * 100;
RUN;

PROC SORT DATA=therapy_counts_final;
    BY DESCENDING COUNT;
RUN;

PROC PRINT DATA=therapy_counts_final;
    VAR therapy_type COUNT percent_of_total;
RUN;

/* ≥5% cutoff */
DATA therapy_counts_5pct;
    SET therapy_counts_final;
    IF percent_of_total >= 5;
RUN;

PROC PRINT DATA=therapy_counts_5pct;
    VAR therapy_type COUNT percent_of_total;
RUN;


/* Table 5 – Therapies Received */

DATA table5;
    SET therapy_counts_final;

    percent = ROUND(percent_of_total, 1);  

    KEEP therapy_type COUNT percent;
RUN;

PROC SORT DATA=table5;
    BY DESCENDING COUNT;
RUN;

TITLE "Number and percentage of participants receiving therapies (n=&total_confirmed)";

PROC PRINT DATA=table5 NOOBS LABEL;
    VAR therapy_type COUNT percent;

    LABEL therapy_type = "Therapy"
          COUNT        = "# of participants"
          percent      = "Percent";
RUN;

TITLE;

/* FIGURE 6: Therapies Received (≥5%)  */
ODS GRAPHICS / RESET WIDTH=6in HEIGHT=6in
    IMAGENAME="Figure6_Therapies";

ODS LISTING GPATH="/home/u64451712/";

PROC SGPLOT DATA=therapy_plot;
    HBAR therapy_type /
         RESPONSE=percent_of_total
         DATALABEL
         CATEGORYORDER=RESPDESC;
    XAXIS LABEL="Percentage of Confirmed Participants (%)" GRID;
    YAXIS LABEL="Therapy Type";
    TITLE "Therapies Received (≥5%, n=137)";
RUN;

ODS LISTING CLOSE;


/*Table 4*/
/*converting into total months*/
DATA milestones;
    SET wdsts_confirmed;

    /* Walked */
    IF dev_walkYr NOT IN ("Not applicable","Unknown") THEN
        walk_months = INPUT(dev_walkYr,8.)*12 + INPUT(dev_walkMth,8.);
    ELSE walk_months = .;

    /* Speak single words */
    IF dev_speakYr NOT IN ("Not applicable","Unknown") THEN
        speak_months = INPUT(dev_speakYr,8.)*12 + INPUT(dev_speakMth,8.);
    ELSE speak_months = .;

    /* Speak phrases */
    IF dev_speakPhrasYr NOT IN ("Not applicable","Unknown") THEN
        phrase_months = INPUT(dev_speakPhrasYr,8.)*12 + INPUT(dev_speakPhrasMth,8.);
    ELSE phrase_months = .;

    /* Bladder trained */
    IF dev_bladderYr NOT IN ("Not applicable","Unknown") THEN
        bladder_months = INPUT(dev_bladderYr,8.)*12 + INPUT(dev_bladderMth,8.);
    ELSE bladder_months = .;

    /* Bowel trained */
    IF dev_bowelYr NOT IN ("Not applicable","Unknown") THEN
        bowel_months = INPUT(dev_bowelYr,8.)*12 + INPUT(dev_bowelMth,8.);
    ELSE bowel_months = .;

RUN;

/* Stats */
PROC MEANS DATA=milestones MEDIAN MEAN N;
    VAR walk_months speak_months phrase_months 
        bladder_months bowel_months;
RUN;


/* results into dataset */
PROC MEANS DATA=milestones MEDIAN MEAN N NOPRINT;
    VAR walk_months speak_months phrase_months 
        bladder_months bowel_months;
    OUTPUT OUT=table4_summary 
        MEDIAN= walk_med speak_med phrase_med bladder_med bowel_med
        MEAN=   walk_mean speak_mean phrase_mean bladder_mean bowel_mean
        N=      walk_n speak_n phrase_n bladder_n bowel_n;
RUN;


/* % */
%LET total_confirmed = 137;

DATA table4_final;
    SET table4_summary;

    walk_pct   = (walk_n / &total_confirmed) * 100;
    speak_pct  = (speak_n / &total_confirmed) * 100;
    phrase_pct = (phrase_n / &total_confirmed) * 100;
    bladder_pct= (bladder_n / &total_confirmed) * 100;
    bowel_pct  = (bowel_n / &total_confirmed) * 100;
RUN;

/* months to years/months” format */
DATA table4_long;
    SET table4_final;

    LENGTH Milestone $30;

    Milestone = "Walked";
    Median = walk_med;
    Mean = walk_mean;
    N = walk_n;
    Pct = walk_pct;
    OUTPUT;

    Milestone = "Speak single words";
    Median = speak_med;
    Mean = speak_mean;
    N = speak_n;
    Pct = speak_pct;
    OUTPUT;

    Milestone = "Speak phrases";
    Median = phrase_med;
    Mean = phrase_mean;
    N = phrase_n;
    Pct = phrase_pct;
    OUTPUT;

    Milestone = "Bladder trained";
    Median = bladder_med;
    Mean = bladder_mean;
    N = bladder_n;
    Pct = bladder_pct;
    OUTPUT;

    Milestone = "Bowel trained";
    Median = bowel_med;
    Mean = bowel_mean;
    N = bowel_n;
    Pct = bowel_pct;
    OUTPUT;

    KEEP Milestone Median Mean N Pct;
RUN;

DATA table4_formatted;
    SET table4_long;

    LENGTH median_text mean_text combined_text $80;

    Median = ROUND(Median, 1);
    Mean   = ROUND(Mean, 0.01);   

    /* Convert median */
    med_years  = INT(Median / 12);
    med_months = MOD(Median, 12);

    /* Convert mean */
    mean_years  = INT(Mean / 12);
    mean_months = MOD(Mean, 12);

    /* Rounding months */
    med_months  = ROUND(med_months, 1);
    mean_months = ROUND(mean_months, 0.01);

    median_text = CATX(" ", med_years, "years and", med_months, "months");
    mean_text   = CATX(" ", mean_years, "years and", mean_months, "months");

    combined_text = CATX(" ",
                         median_text,
                         "(" || STRIP(mean_text) || ")");

    Pct = ROUND(Pct, 1);

    KEEP Milestone combined_text N Pct;
RUN;

TITLE "Median and mean age of developmental milestones (n=&total_confirmed)";

PROC PRINT DATA=table4_formatted NOOBS LABEL;
    VAR Milestone combined_text N Pct;

    LABEL Milestone     = "Milestone"
          combined_text = "Median (mean)"
          N             = "# participant"
          Pct           = "%";
RUN;

TITLE;

/* Figure 7 */
/* months to years for plotting */
DATA milestone_plot;
    SET table4_long;

    median_years = Median / 12;
    mean_years   = Mean / 12;

    median_years = ROUND(median_years, 0.1);
    mean_years   = ROUND(mean_years, 0.1);
    Pct = ROUND(Pct, 0.1);

    label_display = CATX(" ",
                         Milestone,
                         "(",
                         N,
                         ",",
                         Pct,
                         "%)");
RUN;

PROC SORT DATA=milestone_plot;
    BY median_years;
RUN;

ODS GRAPHICS / RESET WIDTH=6in HEIGHT=6in
    IMAGENAME="Figure7_Milestones";

ODS LISTING GPATH="/home/u64451712/";

PROC SGPLOT DATA=milestone_plot;
    HBAR Milestone /
         RESPONSE=median_years
         DATALABEL
         CATEGORYORDER=RESPASC;  /* smaller ages first */
    XAXIS LABEL="Median Age (Years)";
    YAXIS LABEL="Developmental Milestone";
    TITLE "Median Age of Developmental Milestones (n=137)";
RUN;

ODS LISTING CLOSE;


/*Figures*/

/* 8. genetic_mutation_type */

PROC FREQ DATA=wdsts_confirmed;
    TABLES gen_mutationType / MISSING;
RUN;

/*
DATA mutation_clean;
    SET wdsts_confirmed;

    IF gen_mutationType = "Unknown" THEN DELETE;
    IF gen_mutationType = " " THEN DELETE;
RUN;*/

%LET total_confirmed = 137;

PROC FREQ DATA=wdsts_confirmed NOPRINT;
    TABLES gen_mutationType / OUT=mutation_counts;
RUN;

DATA mutation_counts;
    SET mutation_counts;
    percent = (COUNT / &total_confirmed) * 100;
RUN;

PROC SORT DATA=mutation_counts;
    BY DESCENDING COUNT;
RUN;

ODS GRAPHICS / RESET WIDTH=6in HEIGHT=4in IMAGENAME="mutation_plot";

ODS LISTING GPATH="/home/u64451712/";   

PROC SGPLOT DATA=mutation_counts;
    HBAR gen_mutationType / RESPONSE=percent DATALABEL;
    XAXIS LABEL="Percentage of Confirmed Participants (%)";
    YAXIS LABEL="Mutation Type";
    TITLE "Distribution of Mutation Types (n=137)";
RUN;

ODS LISTING CLOSE;

/* 9. by geographic distribution */

DATA region_data;
    SET wdsts_confirmed1;

    LENGTH region $20;

    IF participant_country IN (
        "United States of America (USA)",
        "Canada"
    ) THEN region = "North America";

    ELSE IF participant_country IN (
        "United Kingdom",
        "France",
        "Germany",
        "Italy",
        "Spain",
        "Denmark",
        "Netherlands",
        "Sweden",
        "Finland",
        "Iceland",
        "Norway",
        "Switzerland"
    ) THEN region = "Europe";

    ELSE IF participant_country IN (
        "Australia",
        "New Zealand"
    ) THEN region = "Australia";

    ELSE IF participant_country IN (
        "Malaysia",
        "Japan",
        "China",
        "India",
        "Israel"
    ) THEN region = "Asia";

    ELSE IF participant_country IN (
        "Colombia",
        "Brazil",
        "Argentina"
    ) THEN region = "South America";

    ELSE region = "Other/Missing";

RUN;

PROC FREQ DATA=region_data NOPRINT;
    TABLES region / OUT=region_counts;
RUN;


/*percent  */
%LET total_confirmed = 137;

DATA region_counts;
    SET region_counts;
    percent = ROUND((COUNT / &total_confirmed) * 100, 0.1);
    FORMAT percent 5.1;
RUN;


/* Add total row */
DATA region_counts;
    SET region_counts END=last;
    OUTPUT;

    IF last THEN DO;
        region = "All regions";
        COUNT = &total_confirmed;
        percent = 100.0;
        OUTPUT;
    END;
RUN;


/* Plot */
ODS GRAPHICS / RESET WIDTH=4in HEIGHT=4in 
    IMAGENAME="Region_Distribution_Confirmed_Percent";

ODS LISTING GPATH="/home/u64451712/";

PROC SGPLOT DATA=region_counts;
    VBAR region / RESPONSE=percent 
                  DATALABEL 
                  DATALABELATTRS=(size=9);
    YAXIS LABEL="Percentage of Confirmed Participants (%)";
    XAXIS LABEL="Geographic Region";
    FORMAT percent 5.1;
    TITLE "Distribution of WDSTS by Geographic Region (n=137)";
RUN;

ODS LISTING CLOSE;

/* Median and Mean Age at Diagnosis per Region */

PROC FREQ DATA=region_data NOPRINT;
    TABLES region / OUT=region_totals;
RUN;

PROC MEANS DATA=region_data NWAY NOPRINT;
    CLASS region;
    VAR age_dx_years;

    OUTPUT OUT=region_stats
        MEDIAN = median_age
        MEAN   = mean_age;
RUN;

PROC SORT DATA=region_totals; BY region; RUN;
PROC SORT DATA=region_stats; BY region; RUN;

DATA region_final;
    MERGE region_totals (RENAME=(COUNT=n_patients))
          region_stats;
    BY region;

    /* Round to 1 decimal */
    median_age = ROUND(median_age, 0.1);
    mean_age   = ROUND(mean_age, 0.1);

    FORMAT median_age 5.1 mean_age 5.1;

    KEEP region n_patients median_age mean_age;
RUN;

PROC SORT DATA=region_final;
    BY DESCENDING n_patients;
RUN;

/* Table median/mean age per region */
PROC PRINT DATA=region_final LABEL NOOBS;
    LABEL
        region       = "Region"
        n_patients   = "N"
        median_age   = "Median Age (Years)"
        mean_age     = "Mean Age (Years)";
RUN;


/* 10. Sys Issues */
DATA sys_data;
    SET wdsts_confirmed;

    bladder = (sym_bladder = "Yes");
    gi      = (sym_giIssue = "Yes");
    skin    = (sym_skin = "Yes");
    mouth   = (sym_mouth = "Yes");
    eye     = (sym_eye = "Yes");
    bone    = (sym_bone = "Yes");
    sleep   = (sym_sleep = "Yes");
    cardiac = (sym_cardiac = "Yes");
RUN;

/*total confirmed N */

PROC SQL NOPRINT;
    SELECT COUNT(*) INTO :total_confirmed
    FROM wdsts_confirmed;
QUIT;

/* Calculate system counts  */

PROC MEANS DATA=sys_data NOPRINT;
    VAR bladder gi skin mouth eye bone sleep cardiac;
    OUTPUT OUT=sys_counts SUM=;
RUN;

DATA sys_long;
    SET sys_counts;

    ARRAY vars{8} bladder gi skin mouth eye bone sleep cardiac;

    ARRAY names{8} $40 _TEMPORARY_
        ("Urological"
         "Gastrointestinal"
         "Integumentary (Hair/Skin)"
         "Mouth/Palate/Dental"
         "Eye or Vision"
         "Skeletal (Bone)"
         "Sleep"
         "Cardiac");

    DO i = 1 TO 8;
        System  = names{i};
        Count   = vars{i};
        Percent = ROUND((Count / &total_confirmed) * 100, 0.1);
        OUTPUT;
    END;

    KEEP System Count Percent;
RUN;

PROC SORT DATA=sys_long;
    BY DESCENDING Percent;
RUN;

ODS LISTING GPATH="/home/u64451712/";

ODS GRAPHICS / RESET
    WIDTH=5in HEIGHT=5in
    IMAGENAME="Figure_System_Involvement_WSS"
    IMAGEFMT=PNG;

TITLE HEIGHT=14pt 
"Prevalence of Multi-System Involvement in Genetically Confirmed WSS Patients";

PROC SGPLOT DATA=sys_long;
    STYLEATTRS DATACOLORS=(CX2F5597); 

    VBAR System /
        RESPONSE=Percent
        DATALABEL
        FILLATTRS=(TRANSPARENCY=0.05)
        OUTLINEATTRS=(THICKNESS=1);

    YAXIS LABEL="Prevalence (%)"
          VALUES=(0 TO 100 BY 10);

    XAXIS DISPLAY=(NOLABEL)
          FITPOLICY=ROTATE
          VALUEATTRS=(SIZE=9);
RUN;

TITLE;
ODS GRAPHICS OFF;
ODS LISTING CLOSE;

/* Overall Quality of Life */

PROC FREQ DATA=wdsts_confirmed NOPRINT;
    TABLES quality_Life / OUT=qol_counts;
RUN;

DATA qol_counts_final;
    SET qol_counts;

    percent = ROUND(PERCENT, 1);
RUN;

PROC SORT DATA=qol_counts_final;
    BY DESCENDING COUNT;
RUN;

TITLE "Quality of Life (n=&total_confirmed)";
PROC PRINT DATA=qol_counts_final NOOBS;
    VAR quality_Life COUNT percent;
RUN;
TITLE;

/* Figure */
ODS LISTING GPATH="/home/u64451712/";
ODS GRAPHICS / RESET
    IMAGENAME="Figure4_QOL_Confirmed"
    IMAGEFMT=PNG
    WIDTH=5in
    HEIGHT=5in;

PROC SGPLOT DATA=qol_counts_final;
    HBAR quality_Life / RESPONSE=COUNT DATALABEL;
    XAXIS LABEL="Number of participants";
    YAXIS LABEL="Quality of Life";
    TITLE "Quality of Life (Genetically Confirmed, n=&total_confirmed)";
RUN;

ODS GRAPHICS OFF;

/* QOL per age */
/* age cat*/
DATA wdsts_confirmed2;
    SET wdsts_confirmed1;

    LENGTH age_group $15;

    IF age_dx_years <= 12 THEN age_group = "Child";
    ELSE IF 13 <= age_dx_years <= 17 THEN age_group = "Adolescent";
    ELSE IF age_dx_years >= 18 THEN age_group = "Adult";
    ELSE age_group = "Missing";
RUN;

PROC FREQ DATA=wdsts_confirmed2 NOPRINT;
    TABLES age_group*quality_Life / OUT=qol_age_counts;
RUN;

PROC SGPLOT DATA=qol_age_counts;
    VBAR age_group /
        RESPONSE=COUNT
        GROUP=quality_Life
        GROUPDISPLAY=CLUSTER
        DATALABEL;

    XAXIS LABEL="Age categories";
    YAXIS LABEL="Number of participants";
    TITLE "Differences in Quality of Life between Age Groups (n=&total_confirmed)";
RUN;

ODS LISTING GPATH="/home/u64451712/";

ODS GRAPHICS / RESET
    IMAGENAME="Figure_QOL_by_Age_Confirmed"
    IMAGEFMT=PNG
    WIDTH=7in
    HEIGHT=5in;

PROC SGPLOT DATA=qol_age_counts;
    VBAR age_group /
        RESPONSE=COUNT
        GROUP=quality_Life
        GROUPDISPLAY=CLUSTER
        DATALABEL;

    XAXIS LABEL="Age categories";
    YAXIS LABEL="Number of participants";
    TITLE "Differences in Quality of Life between Age Groups (n=&total_confirmed)";
RUN;

ODS GRAPHICS OFF;

/* qol per region*/
PROC FREQ DATA=region_data NOPRINT;
    TABLES region*quality_Life / OUT=qol_region_counts;
RUN;

PROC SGPLOT DATA=qol_region_counts;
    VBAR region /
        RESPONSE=COUNT
        GROUP=quality_Life
        GROUPDISPLAY=CLUSTER
        DATALABEL;

    XAXIS LABEL="Region";
    YAXIS LABEL="Number of participants";
    TITLE "Differences in Quality of Life between Regions (n=&total_confirmed)";
RUN;

ODS LISTING GPATH="/home/u64451712/";

ODS GRAPHICS / RESET
    IMAGENAME="Figure_QOL_by_Region_Confirmed"
    IMAGEFMT=PNG
    WIDTH=8in
    HEIGHT=5in;

PROC SGPLOT DATA=qol_region_counts;
    VBAR region /
        RESPONSE=COUNT
        GROUP=quality_Life
        GROUPDISPLAY=CLUSTER
        DATALABEL;

    XAXIS LABEL="Region";
    YAXIS LABEL="Number of participants";
    TITLE "Differences in Quality of Life between Regions (n=&total_confirmed)";
RUN;

ODS GRAPHICS OFF;

/* facial features*/
DATA facial_long;
    SET wdsts_confirmed1;

    LENGTH feature $150;

    IF MISSING(sym_facFeature) THEN DELETE;

    num_items = COUNTW(sym_facFeature, ',');

    DO i = 1 TO num_items;
        feature = STRIP(SCAN(sym_facFeature, i, ','));
        OUTPUT;
    END;

    KEEP participant_id feature;
RUN;

PROC SORT DATA=facial_long NODUPKEY;
    BY participant_id feature;
RUN;

PROC FREQ DATA=facial_long NOPRINT;
    TABLES feature / OUT=facial_counts;
RUN;

PROC SORT DATA=facial_counts;
    BY DESCENDING COUNT;
RUN;
 
 /* figure*/
ODS LISTING GPATH="/home/u64451712/";

ODS GRAPHICS / RESET
    IMAGENAME="Figure_FacialFeatures_Confirmed"
    IMAGEFMT=PNG
    WIDTH=7in
    HEIGHT=5in;

PROC SGPLOT DATA=facial_counts;
    VBAR feature / RESPONSE=COUNT DATALABEL;
    XAXIS DISPLAY=(nolabel);
    YAXIS LABEL="Number of participants";
RUN;

ODS GRAPHICS OFF;

/* feed */
DATA feeding_long;
    SET wdsts_confirmed1;

    LENGTH problem $150;

    IF MISSING(sym_exper) THEN DELETE;

    num_items = COUNTW(sym_exper, ',');

    DO i = 1 TO num_items;
        problem = STRIP(SCAN(sym_exper, i, ','));
        OUTPUT;
    END;

    KEEP participant_id problem;
RUN;

PROC SORT DATA=feeding_long NODUPKEY;
    BY participant_id problem;
RUN;

PROC FREQ DATA=feeding_long NOPRINT;
    TABLES problem / OUT=feeding_counts;
RUN;


DATA feeding_counts_ordered;
    SET feeding_counts;

    /* Flagging "Other" to make it to end */
    IF UPCASE(problem) = "OTHER" THEN order_flag = 1;
    ELSE order_flag = 0;
RUN;

PROC SORT DATA=feeding_counts_ordered;
    BY order_flag DESCENDING COUNT;
RUN;


ODS LISTING GPATH="/home/u64451712/";
ODS GRAPHICS / RESET
    IMAGENAME="Figure_FeedingProblems_Confirmed"
    IMAGEFMT=PNG
    WIDTH=7in
    HEIGHT=5in;

PROC SGPLOT DATA=feeding_counts_ordered;
    VBAR problem /
        RESPONSE=COUNT
        DATALABEL;

    XAXIS DISCRETEORDER=DATA;
RUN;

ODS GRAPHICS OFF;

/* feed intake*/
PROC FREQ DATA=wdsts_confirmed1 NOPRINT;
    TABLES sym_feedIntake / OUT=intake_counts;
RUN;

PROC SORT DATA=intake_counts;
    BY DESCENDING COUNT;
RUN;

ODS LISTING GPATH="/home/u64451712/";
ODS GRAPHICS / RESET
    IMAGENAME="Figure_Intake_Confirmed"
    IMAGEFMT=PNG
    WIDTH=7in
    HEIGHT=5in;

PROC SGPLOT DATA=intake_counts;
    VBAR sym_feedIntake / RESPONSE=COUNT DATALABEL;
RUN;

ODS GRAPHICS OFF;

/*neurological*/

DATA neuro_long;
    SET wdsts_confirmed1;

    LENGTH neuro $150;

    IF MISSING(sym_symptom) THEN DELETE;

    num_items = COUNTW(sym_symptom, ',');

    DO i = 1 TO num_items;
        neuro = STRIP(SCAN(sym_symptom, i, ','));
        OUTPUT;
    END;

    KEEP participant_id neuro;
RUN;

PROC SORT DATA=neuro_long NODUPKEY;
    BY participant_id neuro;
RUN;

PROC FREQ DATA=neuro_long NOPRINT;
    TABLES neuro / OUT=neuro_counts;
RUN;

DATA neuro_counts_ordered;
    SET neuro_counts;

    IF UPCASE(neuro) = "OTHER" THEN order_flag = 1;
    ELSE order_flag = 0;
RUN;

/* Sort Other last */
PROC SORT DATA=neuro_counts_ordered;
    BY order_flag DESCENDING COUNT;
RUN;

/* Plot */
ODS LISTING GPATH="/home/u64451712/";
ODS GRAPHICS / RESET
    IMAGENAME="Figure_Neurological_Confirmed"
    IMAGEFMT=PNG
    WIDTH=9in
    HEIGHT=5in;

PROC SGPLOT DATA=neuro_counts_ordered;
    VBAR neuro /
        RESPONSE=COUNT
        DATALABEL;

    XAXIS DISCRETEORDER=DATA;   
RUN;

ODS GRAPHICS OFF;

/* urological issues */
DATA uro_long;
    SET wdsts_confirmed1;

    LENGTH uro_issue $150;

    IF MISSING(sym_bladYes) THEN DELETE;

    num_items = COUNTW(sym_bladYes, ',');

    DO i = 1 TO num_items;
        uro_issue = STRIP(SCAN(sym_bladYes, i, ','));
        OUTPUT;
    END;

    KEEP participant_id uro_issue;
RUN;

PROC SORT DATA=uro_long NODUPKEY;
    BY participant_id uro_issue;
RUN;

PROC FREQ DATA=uro_long NOPRINT;
    TABLES uro_issue / OUT=uro_counts;
RUN;

DATA uro_counts_ordered;
    SET uro_counts;

    IF UPCASE(STRIP(uro_issue)) = "OTHER" THEN order_flag = 1;
    ELSE order_flag = 0;
RUN;

/* Sort with Other as last*/
PROC SORT DATA=uro_counts_ordered;
    BY order_flag DESCENDING COUNT;
RUN;

/* Plot */
ODS LISTING GPATH="/home/u64451712/";
ODS GRAPHICS / RESET
    IMAGENAME="Figure_Urologic_Confirmed"
    IMAGEFMT=PNG
    WIDTH=7in HEIGHT=5in;

PROC SGPLOT DATA=uro_counts_ordered;
    VBAR uro_issue /
        RESPONSE=COUNT
        DATALABEL;

    XAXIS DISCRETEORDER=DATA;
RUN;

ODS GRAPHICS OFF;

/* GI issue*/

DATA gi_long;
    SET wdsts_confirmed1;

    LENGTH gi_issue $150;

    IF MISSING(sym_gi) THEN DELETE;

    num_items = COUNTW(sym_gi, ',');

    DO i = 1 TO num_items;
        gi_issue = STRIP(SCAN(sym_gi, i, ','));
        OUTPUT;
    END;

    KEEP participant_id gi_issue;
RUN;

PROC SORT DATA=gi_long NODUPKEY;
    BY participant_id gi_issue;
RUN;

PROC FREQ DATA=gi_long NOPRINT;
    TABLES gi_issue / OUT=gi_counts;
RUN;

DATA gi_counts_ordered;
    SET gi_counts;

    IF UPCASE(STRIP(gi_issue)) = "OTHER" THEN order_flag = 1;
    ELSE order_flag = 0;
RUN;

PROC SORT DATA=gi_counts_ordered;
    BY order_flag DESCENDING COUNT;
RUN;

/* Plot */
ODS LISTING GPATH="/home/u64451712/";
ODS GRAPHICS / RESET
    IMAGENAME="Figure_GI_Confirmed"
    IMAGEFMT=PNG
    WIDTH=7in HEIGHT=5in;

PROC SGPLOT DATA=gi_counts_ordered;
    VBAR gi_issue /
        RESPONSE=COUNT
        DATALABEL;

    XAXIS DISCRETEORDER=DATA;
RUN;

ODS GRAPHICS OFF;

/* Mouth/ Palate/ Dental */
DATA mouth_long;
    SET wdsts_confirmed1;

    LENGTH mouth_issue $150;

    IF MISSING(sym_mouthIssue) THEN DELETE;

    num_items = COUNTW(sym_mouthIssue, ',');

    DO i = 1 TO num_items;
        mouth_issue = STRIP(SCAN(sym_mouthIssue, i, ','));
        OUTPUT;
    END;

    KEEP participant_id mouth_issue;
RUN;

PROC SORT DATA=mouth_long NODUPKEY;
    BY participant_id mouth_issue;
RUN;

PROC FREQ DATA=mouth_long NOPRINT;
    TABLES mouth_issue / OUT=mouth_counts;
RUN;

DATA mouth_counts_ordered;
    SET mouth_counts;

    IF UPCASE(STRIP(mouth_issue)) = "OTHER" THEN order_flag = 1;
    ELSE order_flag = 0;
RUN;

PROC SORT DATA=mouth_counts_ordered;
    BY order_flag DESCENDING COUNT;
RUN;

/* Plot */
ODS LISTING GPATH="/home/u64451712/";
ODS GRAPHICS / RESET
    IMAGENAME="Figure_Mouth_Confirmed"
    IMAGEFMT=PNG
    WIDTH=7in HEIGHT=5in;

PROC SGPLOT DATA=mouth_counts_ordered;
    VBAR mouth_issue /
        RESPONSE=COUNT
        DATALABEL;

    XAXIS DISCRETEORDER=DATA;
RUN;

ODS GRAPHICS OFF;

/* Skin/ Hair */
DATA skin_long;
    SET wdsts_confirmed1;

    LENGTH skin_issue $150;

    IF MISSING(sym_skinIssue) THEN DELETE;

    num_items = COUNTW(sym_skinIssue, ',');

    DO i = 1 TO num_items;
        skin_issue = STRIP(SCAN(sym_skinIssue, i, ','));
        OUTPUT;
    END;

    KEEP participant_id skin_issue;
RUN;

PROC SORT DATA=skin_long NODUPKEY;
    BY participant_id skin_issue;
RUN;

PROC FREQ DATA=skin_long NOPRINT;
    TABLES skin_issue / OUT=skin_counts;
RUN;

DATA skin_counts_ordered;
    SET skin_counts;

    IF UPCASE(STRIP(skin_issue)) = "OTHER" THEN order_flag = 1;
    ELSE order_flag = 0;
RUN;

PROC SORT DATA=skin_counts_ordered;
    BY order_flag DESCENDING COUNT;
RUN;

/* Plot */
ODS LISTING GPATH="/home/u64451712/";
ODS GRAPHICS / RESET
    IMAGENAME="Figure_Skin_Confirmed"
    IMAGEFMT=PNG
    WIDTH=9in HEIGHT=5in;

PROC SGPLOT DATA=skin_counts_ordered;
    VBAR skin_issue /
        RESPONSE=COUNT
        DATALABEL;

    XAXIS DISCRETEORDER=DATA;
RUN;

ODS GRAPHICS OFF;


/* Eye/ Vision */
DATA eye_long;
    SET wdsts_confirmed1;

    LENGTH eye_issue $150;

    IF MISSING(sym_eyeIssue) THEN DELETE;

    num_items = COUNTW(sym_eyeIssue, ',');

    DO i = 1 TO num_items;
        eye_issue = STRIP(SCAN(sym_eyeIssue, i, ','));
        OUTPUT;
    END;

    KEEP participant_id eye_issue;
RUN;

PROC SORT DATA=eye_long NODUPKEY;
    BY participant_id eye_issue;
RUN;

PROC FREQ DATA=eye_long NOPRINT;
    TABLES eye_issue / OUT=eye_counts;
RUN;

DATA eye_counts_ordered;
    SET eye_counts;

    IF UPCASE(STRIP(eye_issue)) = "OTHER" THEN order_flag = 1;
    ELSE order_flag = 0;
RUN;

PROC SORT DATA=eye_counts_ordered;
    BY order_flag DESCENDING COUNT;
RUN;

/* Plot */
ODS LISTING GPATH="/home/u64451712/";
ODS GRAPHICS / RESET
    IMAGENAME="Figure_Eye_Confirmed"
    IMAGEFMT=PNG
    WIDTH=9in HEIGHT=5in;

PROC SGPLOT DATA=eye_counts_ordered;
    VBAR eye_issue /
        RESPONSE=COUNT
        DATALABEL;

    XAXIS DISCRETEORDER=DATA;
RUN;

ODS GRAPHICS OFF;

/*Skeletal Issues*/
DATA bone_long;
    SET wdsts_confirmed1;

    LENGTH bone_issue $200;

    IF MISSING(sym_boneIssue) THEN DELETE;

    num_items = COUNTW(sym_boneIssue, ',');

    DO i = 1 TO num_items;
        bone_issue = STRIP(SCAN(sym_boneIssue, i, ','));
        OUTPUT;
    END;

    KEEP participant_id bone_issue;
RUN;

PROC SORT DATA=bone_long NODUPKEY;
    BY participant_id bone_issue;
RUN;

PROC FREQ DATA=bone_long NOPRINT;
    TABLES bone_issue / OUT=bone_counts;
RUN;

DATA bone_counts_ordered;
    SET bone_counts;

    IF UPCASE(STRIP(bone_issue)) = "OTHER" THEN order_flag = 1;
    ELSE order_flag = 0;
RUN;

PROC SORT DATA=bone_counts_ordered;
    BY order_flag DESCENDING COUNT;
RUN;

/* Plot */
ODS LISTING GPATH="/home/u64451712/";

ODS GRAPHICS / RESET
    IMAGENAME="Figure_Skeletal_Confirmed"
    IMAGEFMT=PNG
    WIDTH=9in HEIGHT=5in;

PROC SGPLOT DATA=bone_counts_ordered;
    VBAR bone_issue /
        RESPONSE=COUNT
        DATALABEL;

    XAXIS DISCRETEORDER=DATA;
RUN;

ODS GRAPHICS OFF;

/* Sleep Issues*/
DATA sleep_long;
    SET wdsts_confirmed1;

    LENGTH sleep_issue $200;

    IF MISSING(sym_sleepIssue) THEN DELETE;

    num_items = COUNTW(sym_sleepIssue, ',');

    DO i = 1 TO num_items;
        sleep_issue = STRIP(SCAN(sym_sleepIssue, i, ','));
        OUTPUT;
    END;

    KEEP participant_id sleep_issue;
RUN;

PROC SORT DATA=sleep_long NODUPKEY;
    BY participant_id sleep_issue;
RUN;

PROC FREQ DATA=sleep_long NOPRINT;
    TABLES sleep_issue / OUT=sleep_counts;
RUN;

DATA sleep_counts_ordered;
    SET sleep_counts;

    IF UPCASE(STRIP(sleep_issue)) = "OTHER" THEN order_flag = 1;
    ELSE order_flag = 0;
RUN;

PROC SORT DATA=sleep_counts_ordered;
    BY order_flag DESCENDING COUNT;
RUN;

/* Plot */
ODS LISTING GPATH="/home/u64451712/";
ODS GRAPHICS / RESET
    IMAGENAME="Figure_Sleep_Confirmed"
    IMAGEFMT=PNG
    WIDTH=9in HEIGHT=5in;

PROC SGPLOT DATA=sleep_counts_ordered;
    VBAR sleep_issue /
        RESPONSE=COUNT
        DATALABEL;

    XAXIS DISCRETEORDER=DATA;
RUN;

ODS GRAPHICS OFF;

/*Cardiac Issues */
DATA cardiac_long;
    SET wdsts_confirmed1;

    LENGTH cardiac_issue $200;

    IF MISSING(sym_cardiacIssue) THEN DELETE;

    num_items = COUNTW(sym_cardiacIssue, ',');

    DO i = 1 TO num_items;
        cardiac_issue = STRIP(SCAN(sym_cardiacIssue, i, ','));
        OUTPUT;
    END;

    KEEP participant_id cardiac_issue;
RUN;

PROC SORT DATA=cardiac_long NODUPKEY;
    BY participant_id cardiac_issue;
RUN;

PROC FREQ DATA=cardiac_long NOPRINT;
    TABLES cardiac_issue / OUT=cardiac_counts;
RUN;

DATA cardiac_counts_ordered;
    SET cardiac_counts;

    IF UPCASE(STRIP(cardiac_issue)) = "OTHER" THEN order_flag = 1;
    ELSE order_flag = 0;
RUN;

PROC SORT DATA=cardiac_counts_ordered;
    BY order_flag DESCENDING COUNT;
RUN;

/* Plot */
ODS LISTING GPATH="/home/u64451712/";
ODS GRAPHICS / RESET
    IMAGENAME="Figure_Cardiac_Confirmed"
    IMAGEFMT=PNG
    WIDTH=9in HEIGHT=5in;

PROC SGPLOT DATA=cardiac_counts_ordered;
    VBAR cardiac_issue /
        RESPONSE=COUNT
        DATALABEL;

    XAXIS DISCRETEORDER=DATA;
RUN;

ODS GRAPHICS OFF;
