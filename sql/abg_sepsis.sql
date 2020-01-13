-- ------------------------------------------------------------------
-- Arterial blood gas table
--
-- Select all ABGs from patient with sepsis and septic shock
-- ------------------------------------------------------------------

DROP MATERIALIZED VIEW IF EXISTS abg_sepsis CASCADE;
CREATE MATERIALIZED VIEW abg_sepsis AS
select co.subject_id,
	     co.icustay_id,
	     charttime,
	     specimen, 
	     Aa_gradient, 
	     base_excess, 
	     hco3, 
	     total_co2, 
	     carboxy_hb, chloride, comments, calcium, glucose, hematocrit, hb, intubated, lactate, met_hb, o2_flow, fio2, pco2, peep, pH, po2, potassium, required_o2, sodium, temperature, tidal_volume, ventilation_rate, ventilator,
	     flag_shock
from abg_all as ab
inner join cohort_all as co
	on ab.icustay_id = co.icustay_id
	and co.flag_include = 1
	and co.flag_sepsis = 1;
