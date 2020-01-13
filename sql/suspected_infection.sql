-- ------------------------------------------------------------------
-- Suspected infection
--
-- Select patients with a suspicion of bacterial infection
-- Defined as order for administration of antibiotics + order for body fluid culture
-- (Seymour et al., JAMA 2016)
--
-- ------------------------------------------------------------------


DROP MATERIALIZED VIEW IF EXISTS suspected_infection CASCADE;
CREATE MATERIALIZED VIEW suspected_infection AS

-- Patients with a body fluid culture within 1 day of the admission time
with culture as (
	select icustay_id,
		max(case when bio.hadm_id is not null then 1 else 0 end) as culture,
		min(coalesce(bio.charttime, bio.chartdate)) as culture_time,
		max(case when bio.org_name is not null and bio.org_name != '' then 1 else 0 end) as culture_positive
	from icustays
	left join microbiologyevents as bio 
	on icustays.hadm_id = bio.hadm_id
		and (bio.charttime between icustays.intime - interval '1' day and icustays.intime + interval '1' day
			or bio.chartdate between icustays.intime - interval '1' day and icustays.intime + interval '1' day)
	group by icustay_id
),

-- Antibiotics prescriptions
atb as (
	select icustays.icustay_id,
		min(startdate) as atb_time,
		max(case 
		  when lower(drug) like '%ampicillin%' then 1 
		  when lower(drug) like '%amoxicillin%' then 1 
		  when lower(drug) like '%amikacin%' then 1 
		  when lower(drug) like '%augmentin%' then 1 
		  when lower(drug) like '%azithromycin%' then 1 
		  when lower(drug) like '%aztreonam%' then 1 
		  when lower(drug) like '%bactrim%' then 1
		  when lower(drug) like '%cefazolin%' then 1
		  when lower(drug) like '%cefepime%' then 1 
		  when lower(drug) like '%cefixime%' then 1 
		  when lower(drug) like '%cefotaxime%' then 1 
		  when lower(drug) like '%cefotetan%' then 1 
		  when lower(drug) like '%cefoxitin%' then 1 
		  when lower(drug) like '%cefpodoxime%' then 1 
		  when lower(drug) like '%ceftazidime%' then 1 
		  when lower(drug) like '%ceftriaxone%' then 1 
		  when lower(drug) like '%cefuroxime%' then 1
		  when lower(drug) like '%cephalexin%' then 1
		  when lower(drug) like '%clarithromycin%' then 1 
		  when lower(drug) like '%clindamycin%' then 1 
		  when lower(drug) like '%colistin%' then 1
		  when lower(drug) like '%dapsone%' then 1
		  when lower(drug) like '%daptomycin%' then 1
		  when lower(drug) like '%doxycycline%' then 1 
		  when lower(drug) like '%ertapenem%' then 1 
		  when lower(drug) like '%erythromycin%' then 1
		  when lower(drug) like '%ethambutol%' then 1
		  when lower(drug) like '%fosfomycin%' then 1
		  when lower(drug) like '%gatifloxacin%' then 1 
		  when lower(drug) like '%gentamicin%' then 1 
		  when lower(drug) like '%imipenem%' then 1
		  when lower(drug) like '%isoniazid%' then 1
		  when lower(drug) like '%linezolid%' then 1 
		  when lower(drug) like '%meropenem%' then 1 
		  when lower(drug) like '%metronidazole%' then 1 
		  when lower(drug) like '%minocycline%' then 1
		  when lower(drug) like '%nafcillin%' then 1
		  when lower(drug) like '%neomycin%' then 1
		  when lower(drug) like '%nitrofurantoin%' then 1 
		  when lower(drug) like '%nystatin%' then 1 
	    when lower(drug) like '%ofloxacin%' then 1
		  when lower(drug) like '%moxifloxacin%' then 1
		  when lower(drug) like '%penicillin%' then 1 
		  when lower(drug) like '%piperacillin%' then 1
		  when lower(drug) like '%pyrimethamine%' then 1
		  when lower(drug) like '%quinupristin%' then 1
		  when lower(drug) like '%rifampin%' then 1
		  when lower(drug) like '%rifaximin%' then 1 
		  when lower(drug) like '%sulbactam%' then 1
		  when lower(drug) like '%sulfamethoxazole%' then 1
		  when lower(drug) like '%synercid%' then 1 
		  when lower(drug) like '%tetracycline%' then 1 
		  when lower(drug) like '%tigecycline%' then 1 
	  	when lower(drug) like '%timentin%' then 1 
		  when lower(drug) like '%tobramycin%' then 1 
		  when lower(drug) like '%trimethoprim%' then 1 
		  when lower(drug) like '%unasyn%' then 1 
		  when lower(drug) like '%vancomycin%' then 1 
		else 0 end) as atb_poe
	
	from icustays
	left join prescriptions 
		on icustays.icustay_id = prescriptions.icustay_id
		and drug_type in ('MAIN', 'ADDITIVE')
		and route in ('IV', 'PO', 'IV DRIP', 'PO/NG', 'SC', 'IM', 'ORAL', 'IV BOLUS')
	group by icustays.icustay_id
),

-- Patients with a prescription of antibiotics less than 72 hours after body fluid culture or less than 24 hours after culture
atb_microbio as (
	select icustays.icustay_id,
		case when (
			(atb_time > culture_time and atb_time <= culture_time + interval '72' hour)
			or
			(atb_time < culture_time and culture_time <= atb_time + interval '24' hour)
		) then 1 else 0 end as atb_ontime
	from icustays
	left join culture using (icustay_id)
	left join atb using (icustay_id)
)

-- Final cohort (infection = 1 if suspected infection)
select icustay_id,
	culture,
	culture_time,
	culture_positive,
	atb_ontime,
	case when (culture = 1 and atb_ontime = 1) then 1 else 0 end as infection
from icustays
left join culture using (icustay_id)
left join atb_microbio using (icustay_id)
