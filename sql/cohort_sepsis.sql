-- ------------------------------------------------------------------
--
-- Cohort sepsis selection
--
-- Collect data for population with relevant data and flags
-- 
-- ------------------------------------------------------------------

DROP MATERIALIZED VIEW IF EXISTS cohort_sepsis CASCADE;
CREATE MATERIALIZED VIEW cohort_sepsis AS
with abg_order as (
	select icustay_id, charttime, po2,
			dense_rank() over (partition by icustay_id order by charttime) AS abg_nb
	from abg_sepsis
	where po2 is not NULL
),

first as (
	select icustay_id,
		   po2 as first_po2
	from abg_order
	where abg_nb = 1
),

abg_24 as (
	select ie.icustay_id, 
		   round(cast(avg(po2) as numeric), 2) as avg_24_po2,
		   min(po2) as min_24_po2,
		   max(po2) as max_24_po2
	from icustays as ie
	inner join abg_sepsis as ab using (icustay_id)
	where charttime <= ie.intime + interval '1' day
	group by ie.icustay_id
),

abg_whole as (
	select ie.icustay_id, 
		   round(cast(avg(po2) as numeric), 2) as avg_whole_po2,
		   min(po2) as min_whole_po2,
		   max(po2) as max_whole_po2
	from icustays as ie
	inner join abg_sepsis as ab using (icustay_id)
	group by ie.icustay_id
),

sources as (
	select icustay_id, 
		source_pulm,
	   	source_urogyn,
	   	source_neuro,
	   	source_dig,
	   	source_ost,
	  	source_ent,
	   	source_card,
	   	source_skin,
	   	source_other
	from infectious_sources
)

select subject_id,
	   icustay_id,
	   hadm_id,
	   first_po2,
	   avg_24_po2,
	   min_24_po2,
	   max_24_po2,
	   --avg_48_po2,
	   --min_48_po2,
	   --max_48_po2,
	   --avg_72_po2,
	   --min_72_po2,
	   --max_72_po2,
	   --avg_whole_po2,
	   --min_whole_po2,
	   --max_whole_po2,
	   first_careunit,
	   first_wardid,
	   admission_type,
	   intime,
	   outtime,
	   los_icu,
	   los_hospital,
	   vent_first_duration,
	   vaso_firstday,
	   norepinephrine_duration,
	   norepinephrine_max_dose,
	   admission_age,
	   gender,
	   height_firstday,
	   weight_firstday,
	   bmi_firstday,
	   abg_count,
	   lactate_max_firstday,
	   pco2_max_firstday,
	   ph_min_firstday,
	   albumin_min_firstday,
	   bicarbonate_min_firstday,
	   bilirubin_max_firstday,
	   creatinine_max_firstday,
	   chloride_max_firstday,
	   sodium_max_firstday,
	   potassium_max_firstday,
	   hematocrit_min_firstday,
	   hemoglobin_min_firstday,
	   platelet_min_firstday,
	   ptt_min_firstday,
	   rrt,
	   comorbidity_cardio,
	   comorbidity_vascular,
	   comorbidity_neuro,
	   comorbidity_pneumo,
	   comorbidity_metabolic,
	   comorbidity_renal,
	   comorbidity_liver,
	   comorbidity_cancer,
	   sofa,
	   sapsii,
	   apsiii,
	   noso_vap,
	   noso_urinary,
	   noso_cvc,
	   noso_cvc_other,
	   source_pulm,
	   source_urogyn,
	   source_neuro,
	   source_dig,
	   source_ost,
	   source_ent,
	   source_card,
	   source_skin,
	   source_other,
	   death_thirtydays,
	   death_icu,
	   death_hosp,
	   flag_shock
from cohort_all
left join first using (icustay_id) 
left join abg_24 using (icustay_id)
left join abg_whole using (icustay_id)
left join sources using (icustay_id)
where flag_include = 1 and flag_sepsis = 1;
