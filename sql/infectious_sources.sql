-- ------------------------------------------------------------------
-- Infectious sources
--
-- Create table to collect infectious sources from free text notes
--
-- ------------------------------------------------------------------

DROP TABLE IF EXISTS infectious_sources;
CREATE TABLE infectious_sources AS
select 
	subject_id,
	icustay_id,
	hadm_id,
	NULL as source_pulm,
	NULL as source_urogyn,
	NULL as source_neuro,
	NULL as source_dig,
	NULL as source_ost,
	NULL as source_ent,
	NULL as source_card,
	NULL as source_skin,
	NULL as source_other
from cohort_sepsis
where flag_shock = 1
order by subject_id asc;