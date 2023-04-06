select 
	ShiftId,
	count(*) [Number of Dumps],
	sum(FieldLsizetons) [Total tonnage per shift],
	(246.621051973134 * count(*) + sum(FieldLsizetons)) - 2 * sum(FieldLsizetons)
from shiftshiftdump 
group by
	ShiftId
order by
	(246.621051973134 * count(*) + sum(FieldLsizetons)) - 2 * sum(FieldLsizetons)




--220818002	Spence
--220104002	AMR  
--230304001

--267	65847.8208768267	246.621051973134

select 
	avg(cnt) [Total Number of Dumps per shift],
	avg(size) [Total tonnage per shift],
	avg(size)/avg(cnt) [Average dump size] 
from 
(
	select 
		ShiftId,
		count(*) cnt,
		sum(FieldLsizetons) size
	from shiftshiftdump 
	group by
		ShiftId
) a
