DECLARE @shiftid varchar(25) = '230203001'

DECLARE @serviceLocation varchar(25)
SET
	@serviceLocation =
	(
		SELECT TOP 1
			[Pitloc].FieldId  
		FROM [dbo].PITPitloc AS [Pitloc] with(nolock)
		LEFT OUTER JOIN [dbo].Enum AS [EnumUnit] with(nolock) ON [EnumUnit].Id = [Pitloc].FieldUnit
		WHERE 
			[EnumUnit].Idx != 10 
			AND [EnumUnit].Idx != 11 
			AND 
			(
				[EnumUnit].Flags & 4 = 4 
				OR [EnumUnit].Flags & 8 = 8 
				OR [EnumUnit].Flags & 16 = 16 
				OR [EnumUnit].Flags & 64 = 64 
				OR [EnumUnit].Flags & 1024 = 1024
			) -- (Crusher, FuelBay)
		ORDER BY NEWID() 
	)

DECLARE @dummyOriginLocation varchar(25)
SET
	@dummyOriginLocation =
	(
		SELECT TOP 1
			[Pitloc].FieldId  
		FROM [dbo].PITPitloc AS [Pitloc] with(nolock)
		LEFT OUTER JOIN [dbo].Enum AS [EnumUnit] with(nolock) 
		ON 
			[EnumUnit].Id = [Pitloc].FieldUnit
		WHERE 
			[EnumUnit].Idx != 10 
			AND [EnumUnit].Idx != 11 
			AND 
			(
				[EnumUnit].Flags & 4 = 4 
				OR [EnumUnit].Flags & 8 = 8 
				OR [EnumUnit].Flags & 16 = 16 
				OR [EnumUnit].Flags & 64 = 64 
				OR [EnumUnit].Flags & 1024 = 1024
			) -- (Crusher, FuelBay)
		ORDER BY NEWID() 
	);

WITH EqmtState AS
(
	SELECT 
		s.ShiftId, 
		s.FieldId,
		s.FieldTime,
		s.StatusId,
		st.Idx,
		LEAD(s.FieldTime, 1, si.ShiftDuration) OVER (PARTITION BY s.ShiftId, s.FieldId ORDER BY s.FieldTime, s.StatusId) - s.FieldTime Duration,
		CONVERT(int, si.ShiftStartTimestamp + 1000 + CHECKSUM(NEWID())% 10 * 1000) RandomStart 
	FROM
	(
		SELECT
			eq.ShiftId, 
			eq.FieldId,
			st.FieldTime,
			ISNULL(r.FieldStatus, st.FieldStatus) StatusId
		FROM [dbo].SHIFTShifteqmt eq with(nolock)
		INNER JOIN [dbo].SHIFTShiftstate st with(nolock)
		ON
			st.ShiftId = eq.ShiftId
			and st.FieldEqmt = eq.Id
		LEFT JOIN [dbo].SHIFTShiftreason r with(nolock)
		ON
			st.FieldReasonrec = r.Id
		WHERE
			eq.ShiftId = @shiftid
		UNION ALL
		SELECT 
			eq.ShiftId, 
			eq.FieldId,
			0 FieldTime,
			eq.FieldStatus StatusId
		FROM [dbo].SHIFTShifteqmt eq with(nolock)
		LEFT JOIN [dbo].SHIFTShiftreason r with(nolock)
		ON
			eq.FieldReason = r.FieldReason
			AND eq.ShiftId = r.ShiftId  
		WHERE
			eq.ShiftId = @shiftid
	) s
	INNER JOIN Common.ShiftInfo si
	ON
		s.ShiftId = si.ShiftId 
	INNER JOIN Common.EnumSTATUS st
	ON	
		s.StatusId = st.Id
)

SELECT
	'Service Mission For ' + t.FieldId [id],
	'Service Mission For ' + t.FieldId [name],
	si.ShiftStartTimestamp [timeStamp],
	'TRUCK_SERVICE' [type],
	t.FieldId [agent],
	'[' + @serviceLocation + ']' [resource],
	si.ShiftStartTimestamp [startTime],
	@dummyOriginLocation [originLocation.elementId],
	'[]' [originLocation.offset],
	@serviceLocation [destinationLocation.elementId],
	'[]' [destinationLocation.offset],
	'SCHEDULED' [operationStatus],
	0.0 AS [endTime],
	ut.Duration [duration],
	CASE 
		WHEN 
			ut.RandomStart > (si.ShiftStartTimestamp + si.ShiftDuration - (ut.Duration + 120)) 
		THEN 
			si.ShiftStartTimestamp + si.ShiftDuration - (ut.Duration + 120) 
		ELSE 
			ut.RandomStart 
	END 'operationTimeWindow.earliestStartTime',
	CASE 
		WHEN 
			ut.RandomStart + ut.Duration > si.ShiftStartTimestamp + si.ShiftDuration 
		THEN 
			si.ShiftStartTimestamp + si.ShiftDuration 
		ELSE 
			ut.RandomStart + ut.Duration
	END AS 'operationTimeWindow.earliestEndTime',
	si.ShiftStartTimestamp + si.ShiftDuration - (ut.Duration + 120) AS 'operationTimeWindow.latestStartTime',
	-- add 120 seconds buffer
	si.ShiftStartTimestamp + si.ShiftDuration AS 'operationTimeWindow.latestEndTime'
FROM PITTruck t with(nolock)
INNER JOIN Common.ShiftInfo si
ON
	si.ShiftId = @shiftid
INNER JOIN  [dbo].Enum [EqmtType] with(nolock) 
ON
	EqmtType.Id = t.FieldEqmttype
INNER JOIN
(
	SELECT
		s.ShiftId,
		s.FieldId,
		AVG(s.Duration) Duration,
		MAX(RandomStart) RandomStart
	FROM EqmtState s
	WHERE
		s.Idx != 2 --Status is not Ready
	GROUP BY
		s.ShiftId,
		s.FieldId
) ut
ON
	ut.FieldId = t.FieldId 
WHERE
	EqmtType.[Description] != 'Unknown'
ORDER BY
	[agent]
