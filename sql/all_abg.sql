-- ------------------------------------------------------------------
-- All arterial blood gas
-- ------------------------------------------------------------------

DROP MATERIALIZED VIEW IF EXISTS abg_all CASCADE;
CREATE MATERIALIZED VIEW abg_all AS
with all_gas as (
	select subject_id,
		   charttime,
		   max(case when itemid = 50800 then value end) as specimen,
		   max(case when itemid = 50801 then valuenum end) as Aa_gradient,
		   max(case when itemid = 50802 then valuenum end) as base_excess,
		   max(case when itemid = 50803 then valuenum end) as hco3,
		   max(case when itemid = 50804 then valuenum end) as total_co2,
		   max(case when itemid = 50805 then valuenum end) as carboxy_hb,
		   max(case when itemid = 50806 then valuenum end) as chloride,
		   max(case when itemid = 50807 then value end) as comments,
		   max(case when itemid = 50808 then valuenum end) as calcium,
		   max(case when itemid = 50809 then valuenum end) as glucose,
		   max(case when itemid = 50810 then valuenum end) as hematocrit,
		   max(case when itemid = 50811 then valuenum end) as hb,
		   max(case when itemid = 50812 then valuenum end) as intubated,
		   max(case when itemid = 50813 then valuenum end) as lactate,
		   max(case when itemid = 50814 then valuenum end) as met_hb,
		   max(case when itemid = 50815 then valuenum end) as o2_flow,
		   max(case when itemid = 50816 then valuenum end) as fio2,
		   max(case when itemid = 50818 then valuenum end) as pco2,
		   max(case when itemid = 50819 then valuenum end) as peep,
		   max(case when itemid = 50820 then valuenum end) as pH,
		   max(case when itemid = 50821 then valuenum end) as po2,
		   max(case when itemid = 50822 then valuenum end) as potassium,
		   max(case when itemid = 50823 then valuenum end) as required_o2,
		   max(case when itemid = 50824 then valuenum end) as sodium,
		   max(case when itemid = 50825 then valuenum end) as temperature,
		   max(case when itemid = 50826 then valuenum end) as tidal_volume,
		   max(case when itemid = 50827 then valuenum end) as ventilation_rate,
		   max(case when itemid = 50828 then valuenum end) as ventilator
		   
	from labevents
	where (itemid between 50800 and 50828)
	group by charttime, subject_id
)

select subject_id,
	   icustay_id,
	   charttime,
	   specimen, Aa_gradient, base_excess, hco3, total_co2, carboxy_hb, chloride, comments, calcium, glucose, hematocrit, hb, intubated, lactate, met_hb, o2_flow, fio2, pco2, peep, pH, po2, potassium, required_o2, sodium, temperature, tidal_volume, ventilation_rate, ventilator
from icustays
inner join all_gas using (subject_id)
where specimen like 'ART';
