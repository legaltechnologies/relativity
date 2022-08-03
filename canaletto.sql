DECLARE @rpf TABLE (ArtifactID int, ControlNumber varchar(255))
DECLARE @image TABLE (ArtifactID int)
DECLARE @placeholder TABLE (ArtifactID int)
DECLARE @skip TABLE (ArtifactID int)
DECLARE @nativered TABLE (ArtifactID int)
DECLARE @markups TABLE (ArtifactID int)
DECLARE @redreq TABLE (ArtifactID int)

DECLARE @relevance int
DECLARE @privilege int
DECLARE @relevant int
DECLARE @privileged int

DECLARE @exec varchar(max)

DECLARE @prod TABLE (
 ArtifactID int,
 ControlNumber varchar(255),
 ProdGI varchar(255),
 ProdSD datetime,
 Native tinyint,
 Image tinyint,
 Placeholder tinyint,
 Skip tinyint,
 NativeRed tinyint,
 Warning varchar(max))



-- This is the main search (Relevant NOT Privileged) + family
INSERT INTO @rpf
SELECT DISTINCT
  dx.[ArtifactID]
 ,dx.[ControlNumber]
FROM [EDDSDBO].[ZCodeArtifact_1000127] r
LEFT JOIN [EDDSDBO].[ZCodeArtifact_1000129] p ON r.[AssociatedArtifactID] = p.[AssociatedArtifactID] 
JOIN [EDDSDBO].[Document] d ON r.[AssociatedArtifactID] = d.[ArtifactID]
JOIN [EDDSDBO].[Document] dx ON d.[GroupIdentifier] = dx.[GroupIdentifier]
WHERE r.[CodeArtifactID] IN (1038501)
AND (p.[CodeArtifactID] NOT IN (1038504) OR p.[CodeArtifactID] IS NULL)

-- Items produced as placeholders (here Privilege = Privileged)
INSERT INTO @placeholder
SELECT DISTINCT
  p.AssociatedArtifactID
FROM [EDDSDBO].[ZCodeArtifact_1000129] p
JOIN [EDDSDBO].[Code] c ON p.[CodeArtifactID] = c.[ArtifactID]
WHERE c.Name = 'Privileged'

-- Items produced as image (here Privilege = Redaction Complete AND NOT Excel)
INSERT INTO @image
SELECT DISTINCT
  p.AssociatedArtifactID
FROM [EDDSDBO].[ZCodeArtifact_1000129] p
JOIN [EDDSDBO].[Code] c ON p.[CodeArtifactID] = c.[ArtifactID]
LEFT JOIN [eddsdbo].[ZCodeArtifact_1000130] ft ON p.AssociatedArtifactID = ft.AssociatedArtifactID
LEFT JOIN [EDDSDBO].[Code] c1 ON ft.[CodeArtifactID] = c1.[ArtifactID] 
WHERE c.Name IN ('Redaction Complete','Redaction Required')
AND c1.Name NOT LIKE '%Excel%'

-- Items to skip silently (e.g. junk items) - their removal doesn't trigger imaging (here Privilege = Redaction Required AND Excel - because those will have a redacted version that will be produced)
INSERT INTO @skip
SELECT DISTINCT
  p.AssociatedArtifactID
FROM [EDDSDBO].[ZCodeArtifact_1000129] p
JOIN [EDDSDBO].[Code] c ON p.[CodeArtifactID] = c.[ArtifactID]
LEFT JOIN [eddsdbo].[ZCodeArtifact_1000130] ft ON p.AssociatedArtifactID = ft.AssociatedArtifactID
LEFT JOIN [EDDSDBO].[Code] c1 ON ft.[CodeArtifactID] = c1.[ArtifactID] 
WHERE c.Name = 'Redaction Required'
AND c1.Name LIKE '%Excel%'

-- Items redacted natively (here Privilege = Redaction Complete and Excel)
INSERT INTO @nativered
SELECT DISTINCT
  p.AssociatedArtifactID
FROM [EDDSDBO].[ZCodeArtifact_1000129] p
JOIN [EDDSDBO].[Code] c ON p.[CodeArtifactID] = c.[ArtifactID]
LEFT JOIN [EDDSDBO].[ZCodeArtifact_1000130] ft ON p.AssociatedArtifactID = ft.AssociatedArtifactID
LEFT JOIN [EDDSDBO].[Code] c1 ON ft.[CodeArtifactID] = c1.[ArtifactID] 
WHERE c.Name = 'Redaction Complete'
AND c1.Name LIKE '%Excel%'

-- Items without a specific Markup Set that are coded Privilege = Redaction Required OR Redaction Complete. 
-- Technically Redaction Required is what it should be coded when you don't have redactions, but I want to put a warning on both, just in case
-- Exclude natively redacted items
INSERT INTO @markups
SELECT
  p.[AssociatedArtifactID]
FROM [EDDSDBO].[ZCodeArtifact_1000129] p 
LEFT JOIN [EDDSDBO].[ZCodeArtifact_1000035] m ON p.[AssociatedArtifactID] = m.[AssociatedArtifactID]
LEFT JOIN @nativered n ON p.[AssociatedArtifactID] = n.[ArtifactID]
WHERE p.[CodeArtifactID] IN (1038507, 1038508) 
AND m.[CodeArtifactID] IS NULL
AND n.[ArtifactID] IS NULL

-- Push items from (Relevant NOT Privileged) + family into @prod table
INSERT INTO @prod (ArtifactID, ControlNumber)
SELECT
  [ArtifactID]
 ,[ControlNumber]
FROM @rpf

-- Push images, placeholders, skipped items, natively redacted items and warnings into @prod table
UPDATE prod
  SET Image = 1
FROM @prod prod
JOIN @image x ON prod.[ArtifactID] = x.[ArtifactID]

UPDATE prod
  SET Placeholder = 1
FROM @prod prod
JOIN @placeholder x ON prod.[ArtifactID] = x.[ArtifactID]

UPDATE prod
  SET Skip = 1
FROM @prod prod
JOIN @skip x ON prod.[ArtifactID] = x.[ArtifactID]

UPDATE prod
  SET NativeRed = 1,
  Warning = CASE WHEN Warning IS NULL THEN 'Check native redaction' ELSE Warning + '; Check native redaction' END
FROM @prod prod
JOIN @nativered x ON prod.[ArtifactID] = x.[ArtifactID]

UPDATE prod
  SET Warning = CASE WHEN Warning IS NULL THEN 'Missing redactions' ELSE Warning + '; Missing redactions' END
FROM @prod prod
JOIN @markups x ON prod.[ArtifactID] = x.[ArtifactID]
WHERE [Skip] IS NULL

-- Image parent items up the tree of items produced as image or placeholder
;WITH CTEHierarchy
AS (
  SELECT
    d.ControlNumber
   ,d.ParentID AS Tree
   ,0 AS Level
   ,ParentID
   ,GroupIdentifier
  FROM [EDDSDBO].[Document] d
  JOIN @prod p ON d.[ArtifactID] = p.[ArtifactID] AND (p.[Image] = 1 OR p.[Placeholder] = 1 OR p.[NativeRed] = 1)
  UNION ALL
  SELECT
    uh.ControlNumber
   ,dx.ParentID as Tree
   ,uh.Level + 1 AS Level
   ,dx.ParentID
   ,uh.GroupIdentifier
  FROM [EDDSDBO].[Document] dx
  INNER JOIN CTEHierarchy uh ON dx.ControlNumber = uh.ParentID AND dx.ControlNumber <> uh.GroupIdentifier
  )
  
SELECT
  ControlNumber
 ,Tree
 ,Level
 ,ParentID
 ,GroupIdentifier
INTO #tree
FROM CTEHierarchy
ORDER BY ControlNumber, Tree, ParentID, GroupIdentifier

UPDATE p SET Image = 1
FROM #tree x 
JOIN @prod p ON x.Tree = p.ControlNumber
WHERE x.[ControlNumber] <> x.[Tree]

DROP TABLE #tree


-- Warn about children of placeholdered documents that are not placeholders
;WITH CTEHierarchy
AS (
  SELECT
    d.ControlNumber
   ,d.ControlNumber AS Tree
   ,0 AS Level
   ,ParentID
   ,GroupIdentifier
  FROM [EDDSDBO].[Document] d
  JOIN @prod p ON d.[ArtifactID] = p.[ArtifactID] AND (p.[Placeholder] = 1)
  UNION ALL
  SELECT
    dx.ControlNumber
   ,dx.ControlNumber as Tree
   ,uh.Level + 1 AS Level
   ,dx.ParentID
   ,uh.GroupIdentifier
  FROM [EDDSDBO].[Document] dx
  INNER JOIN CTEHierarchy uh ON uh.ControlNumber = dx.ParentID AND dx.ControlNumber <> dx.ParentID --AND uh.ControlNumber <> dx.ControlNumber
  )
  
SELECT
  ControlNumber
 ,Tree
 ,Level
 ,ParentID
 ,GroupIdentifier
INTO #tree2
FROM CTEHierarchy
ORDER BY ControlNumber, Tree, ParentID, GroupIdentifier

UPDATE p
SET Warning = CASE WHEN Warning IS NULL THEN 'Placeholdered parent' ELSE Warning + '; Placeholdered parent' END
FROM #tree2 x 
JOIN @prod p ON x.Tree = p.ControlNumber
WHERE p.Placeholder IS NULL

DROP TABLE #tree2



-- Show me the money
SELECT
  d.[ControlNumber]
 ,d.[ParentID]
 ,d.[GroupIdentifier]
 ,p.[ProdGI]
 ,d.[KeyDate]
 ,d.[SortDate]
 ,p.[ProdSD]
 ,d.[MD5Hash]
 ,p.[Native]
 ,p.[Image]
 ,p.[Placeholder]
 ,p.[Skip]
 ,r.[Name] [Relevance]
 ,x.[Name] [Privilege]
 ,ft.[Name] [FileType]
 ,p.[Warning]
 ,CASE
	WHEN [Skip] = 1 THEN 'Skip'
	WHEN [Placeholder] = 1 THEN 'Placeholder'
	WHEN [Image] = 1 THEN 'Image'
	ELSE 'Native' END [Result]
FROM [eddsdbo].[Document] d
JOIN @prod p ON d.[ArtifactID] = p.[ArtifactID]
LEFT JOIN [EDDSDBO].[ZCodeArtifact_1000127] rx ON [d].[ArtifactID] = rx.[AssociatedArtifactID]
LEFT JOIN [EDDSDBO].[Code] r ON rx.[CodeArtifactID] = r.[ArtifactID]
LEFT JOIN [EDDSDBO].[ZCodeArtifact_1000129] xx ON [d].[ArtifactID] = xx.[AssociatedArtifactID]
LEFT JOIN [EDDSDBO].[Code] x ON xx.[CodeArtifactID] = x.[ArtifactID]
LEFT JOIN [EDDSDBO].[ZCodeArtifact_1000130] ftx ON d.[ArtifactID] = ftx.[AssociatedArtifactID]
LEFT JOIN [EDDSDBO].[Code] ft ON ftx.[CodeArtifactID] = ft.[ArtifactID]




-- Scratchpad starts here

/*
INSERT INTO @rpf
SELECT
  d.[ArtifactID]
FROM [eddsdbo].[Document] d
JOIN [eddsdbo].[Document] dx ON d.[GroupIdentifier] = dx.[GroupIdentifier]
*/

/*
SELECT
  [ControlNumber]
 ,[ParentID]
 ,[GroupIdentifier]
 ,r.[Name] [Relevance]
 ,x.[Name] [Privilege]
FROM [EDDSDBO].[Document] d
JOIN @placeholder p ON d.[ArtifactID] = p.[ArtifactID] -- which docs you want to see
LEFT JOIN [EDDSDBO].[ZCodeArtifact_1000127] rx ON [d].[ArtifactID] = rx.[AssociatedArtifactID]
LEFT JOIN [EDDSDBO].[Code] r ON rx.[CodeArtifactID] = r.[ArtifactID]
LEFT JOIN [EDDSDBO].[ZCodeArtifact_1000129] xx ON [d].[ArtifactID] = xx.[AssociatedArtifactID]
LEFT JOIN [EDDSDBO].[Code] x ON xx.[CodeArtifactID] = x.[ArtifactID]
*/

/*
SELECT
 CodeTypeID -- 1000127
FROM [eddsdbo].[Field] f 
WHERE [DisplayName] = 'Relevance'

SELECT
  ArtifactID -- 1038501
FROM [eddsdbo].[Code] c
WHERE c.[Name] = 'Relevant'

SELECT
  CodeTypeID -- 1000129
FROM [eddsdbo].[Field] f 
WHERE [DisplayName] = 'Privilege'

SELECT
  ArtifactID -- 1038504
 ,Name
FROM [eddsdbo].[Code] c
WHERE c.[CodeTypeID] = 1000129

SELECT
 ArtifactID -- 1038504
FROM [eddsdbo].[Code] c
WHERE c.[Name] = 'Privileged'

SELECT
  CodeTypeID -- 1000130
FROM [eddsdbo].[Field] f 
WHERE [DisplayName] = 'File Type'

SELECT
 ArtifactID -- 1038506
FROM [eddsdbo].[Code] c
WHERE c.[Name] LIKE '%Excel%'
AND c.[CodeTypeID] = 1000130

SELECT
  ArtifactID
 ,CodeTypeID -- 1000127
 ,DisplayName
 ,*
FROM [eddsdbo].[Field] f 
WHERE [DisplayName] LIKE 'Markup Set%'

SELECT
*
FROM eddsdbo.[Field]
WHERE FieldCategoryID = 12

-- Markup Sets
SELECT
  CodeTypeID -- 1000035 - Primary
FROM [EDDSDBO].[Field]
WHERE [FieldCategoryID] = 12
*/


