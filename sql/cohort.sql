-- ------------------------------------------------------------------
--
-- Cohort selection
--
-- All population with relevant data and flags
-- Suspicion of infection: flag_infection
-- Sepsis (SEPSIS 3 criteria): flag_sepsis
-- Septic shock (SEPSIS 3 criteria): flag_shock
-- ------------------------------------------------------------------

DROP MATERIALIZED VIEW IF EXISTS cohort_all CASCADE;
CREATE MATERIALIZED VIEW cohort_all AS

-- Suspicion of infection
with infected_cohort as (
  select icustay_id,
  culture,
  culture_time,
  culture_positive,
  atb_ontime,
  infection as flag_infection
  from icustays 
  left join suspected_infection using (icustay_id)
),

details as (
	select icustay_id, age as admission_age, icustay_seq, gender, los_icu, los_hospital, admission_type
	from icustay_detail
),

abg as (
	select icustay_id,
	       count(*) as abg_count
	from abg_all
	group by icustay_id
),

lactate_abg as (
  select ie.icustay_id,
         max(lactate) as lactate_max_firstday,
         max(pco2) as pco2_max_firstday,
         min(pH) as ph_min_firstday
  from icustays as ie
  left join abg_all as ab
  	on ie.icustay_id = ab.icustay_id
  	and ab.charttime between (ie.intime - interval '6' hour) and (ie.intime + interval '1' day)
  group by ie.icustay_id
),

/*
abgfirstday as (
  select icustay_id, avg(po2) as avg_po2, 
  		avg(coalesce(fio2, fio2_chartevents)) as avg_fio2,
  		avg(pao2fio2) as avg_pao2fio2,
  		avg(lactate) as avg_lactate
  from bloodgasfirstdayarterial
  group by icustay_id 
),
*/

vent as (
	select icustay_id, duration_hours as vent_first_duration
	from ventdurations
	where ventnum = 1
),

sofa as (
	select icustay_id, sofa
	from sofa
),

sapsii as (
	select icustay_id, sapsii
	from sapsii
),

apsiii as (
	select icustay_id, apsiii
	from apsiii
),

patient as (
	select icustay_id, expire_flag as death, outtime, dod
	from patients
	inner join icustays using (subject_id)
),

admission as (
  select icustay_id, dischtime, admittime
  from admissions
  inner join icustays using (hadm_id)
),

vaso as (
  select icustay_id,
	  max(case when starttime between intime and intime + interval '1' day  and starttime <= outtime then 1 else 0 end ) as vaso_firstday
from icustays
left join vasopressordurations using (icustay_id)
group by icustay_id
),

-- Norepinephrine
norepi_duration as (
	select icustay_id, sum(duration_hours) as norepinephrine_duration
	from norepinephrinedurations
	group by icustay_id
),

norepi_dose as (
	select icustay_id, max(vaso_rate) as norepinephrine_max_dose
	from norepinephrine_dose
	group by icustay_id
),

-- Comorbidities
comorbidities as (
	select icustay_id,  
		case when congestive_heart_failure = 1 or cardiac_arrhythmias = 1 or valvular_disease = 1 then 1 else 0 end as cardio,
		case when pulmonary_circulation = 1 or peripheral_vascular = 1 or hypertension = 1 then 1 else 0 end as vascular,
		case when paralysis = 1 or other_neurological = 1 then 1 else 0 end as neuro,
		case when chronic_pulmonary = 1 then 1 else 0 end as pneumo,
		case when diabetes_complicated = 1 or diabetes_uncomplicated = 1 or hypothyroidism = 1 then 1 else 0 end as metabolic,
		renal_failure as nephro,
		liver_disease as hepato,
		case when lymphoma = 1 or metastatic_cancer = 1 or solid_tumor = 1 then 1 else 0 end as cancer
	from elixhauser_ahrq
	inner join icustays using(hadm_id)
),

-- Renal replacement therapy
rrt as (
  select icustay_id, rrt
  from rrt
),

-- Weight on first day
weight as (
  select icustay_id, weight
  from weightfirstday
),

-- Height on first day
height as (
  select icustay_id, height
  from heightfirstday
),

-- Lab results on first day
labs as (
  select icustay_id,
  	albumin_min,
  	bicarbonate_min,
  	bilirubin_max,
  	creatinine_max,
  	chloride_max,
  	hematocrit_min,
  	hemoglobin_min,
  	platelet_min,
  	potassium_max,
  	ptt_min,
  	sodium_max
  from labsfirstday
),

-- Nosocomial infections
noso as (
  select icustay_id, 
	  max(case when icd9_code LIKE '99731' then 1 else 0 end) as noso_vap, -- Ventilator associated pneumoniae
	  max(case when icd9_code LIKE '99664' then 1 else 0 end) as noso_urinary, -- Infection and inflammatory reaction due to indwelling urinary catheter
	  max(case when icd9_code LIKE '99932' then 1 else 0 end) as noso_cvc, -- Bloodstream infection due to central venous catheter
	  max(case when icd9_code LIKE '99931' then 1 else 0 end) as noso_cvc_other -- Other and unspecified infection due to central venous catheter
  from diagnoses_icd
  inner join icustays using(hadm_id)
  group by icustay_id
),

cohort as (
	select subject_id,
		hadm_id,
		icustay_id,
		first_careunit,
		first_wardid,
		admission_type,
		ie.intime,
		ie.outtime,
		los_icu,
		los_hospital,
		vent_first_duration,
		culture_time,
		culture_positive,
		vaso_firstday,
		case when norepinephrine_duration is not null then norepinephrine_duration else 0 end as norepinephrine_duration,
		case when norepinephrine_max_dose is not null then norepinephrine_max_dose else 0 end as norepinephrine_max_dose,
		admission_age,
		gender,
		round(cast(height as numeric), 2) as height_firstday,
		round(cast(weight as numeric), 2) as weight_firstday,
		round(cast((weight / ((height/100)*(height/100))) as numeric), 2) as bmi_firstday,
		icustay_seq,
		abg_count,
		lactate_max_firstday,
		pco2_max_firstday,
		ph_min_firstday,
		albumin_min as albumin_min_firstday,
		bicarbonate_min as bicarbonate_min_firstday,
		bilirubin_max as bilirubin_max_firstday,
		creatinine_max as creatinine_max_firstday,
		chloride_max as chloride_max_firstday,
		sodium_max as sodium_max_firstday,
		potassium_max as potassium_max_firstday,
		hematocrit_min as hematocrit_min_firstday,
		hemoglobin_min as hemoglobin_min_firstday,
		platelet_min as platelet_min_firstday,
		ptt_min as ptt_min_firstday,
		--avg_po2,
		--avg_fio2,
		--avg_pao2fio2,
		--avg_lactate,
		rrt,
		cardio as comorbidity_cardio,
		vascular as comorbidity_vascular,
		neuro as comorbidity_neuro,
		pneumo as comorbidity_pneumo,
		metabolic as comorbidity_metabolic,
		nephro as comorbidity_renal,
		hepato as comorbidity_liver,
		cancer as comorbidity_cancer,
		sofa,
		sapsii,
		apsiii,
		death,
		noso_vap,
		noso_urinary,
		noso_cvc,
		noso_cvc_other,
		case when patient.dod <= admission.admittime + interval '30' day then 1 else 0 end as death_thirtydays,
		case when patient.dod <= patient.outtime then 1 else 0 end as death_icu,
		case when patient.dod <= admission.dischtime then 1 else 0 end as death_hosp,
		flag_infection,
		case when (flag_infection = 1 and sofa >= 2) then 1 else 0 end as flag_sepsis,
		case when (flag_infection = 1 and sofa >= 2 and lactate_max_firstday >= 2 and vaso_firstday = 1) then 1 else 0 end as flag_shock,
		--case when (admission_age >= 18 and icustay_seq = 1 and los_icu >= 1 and first_careunit != 'CSRU' and vent_first_duration >= 24 and abg_count >= 1) then 1 else 0 end as flag_sepsis,
		--case when (admission_age >= 18 and icustay_seq = 1 and los_icu >= 1 and first_careunit != 'CSRU' and vent_first_duration >= 24 and abg_count >= 1 and lactate_max_firstday >= 2 and vaso_firstday = 1) then 1 else 0 end as flag_shock
	  case when (admission_age >= 18
          and icustay_seq = 1
          and los_icu >= 1
          and first_careunit NOT IN ('CSRU', 'CCU', 'TSICU')
          and abg_count >= 1
          and vent_first_duration >= 24) then 1 else 0 end as flag_include
	from icustays as ie
	left join infected_cohort using (icustay_id)
	left join details using (icustay_id)
	left join abg using (icustay_id)
	left join lactate_abg using (icustay_id)
	--left join abgfirstday using (icustay_id)
	left join sofa using (icustay_id)
	left join sapsii using (icustay_id)
	left join apsiii using (icustay_id)
	left join vent using (icustay_id)
	left join patient using (icustay_id)
	left join admission using (icustay_id)
	left join vaso using(icustay_id)
	left join norepi_duration using(icustay_id)
	left join norepi_dose using(icustay_id)
	left join comorbidities using(icustay_id)
	left join rrt using(icustay_id)
	left join weight using(icustay_id)
	left join height using(icustay_id)
	left join labs using(icustay_id)
	left join noso using(icustay_id)
)
select * from cohort;