USE [Scratchdisk]
GO

/****** Object:  View [dbo].[HOUZZ_INVENTORY_VW]    Script Date: 3/3/2022 1:33:51 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


ALTER VIEW [dbo].[HOUZZ_INVENTORY_VW]
AS
	WITH HouzzBlacklist
	AS
	(SELECT
			UniqueID
		   ,[303]
		FROM Departments.marketplace.blacklistUniqueID),
	BlacklistManufacturer
	AS
	(SELECT
			MAP.uniqueId
		   ,RM.[303]
		FROM Departments.marketplace.blacklistManufacturer AS RM
		INNER JOIN MMC.dbo.product AS MAP
			ON RM.Manufacturer = MAP.manufacturer
		WHERE (MAP.status = 'stock')),
	MarketplaceInventory
	AS
	(SELECT
			mpl.[INVENTORY NUMBER] AS UniqueID
		   ,SUM(mvi.Quantity) AS TotalQuantity
		FROM Departments.marketplace.automatedListingLog AS mpl
		INNER JOIN Departments.marketplace.automatedListingBase AS MAP
			ON mpl.[INVENTORY NUMBER] = MAP.Uniqueid
		INNER JOIN OMC.dbo.Master_Vendor_Inventory AS mvi
			ON MAP.Finish = mvi.finish
			AND MAP.MANUFACTURER = mvi.manufacturer
			AND MAP.productid = mvi.productID
		INNER JOIN MMC.dbo.marketplace_vendor AS mav
			ON mav.vendorId = mvi.vendor
			AND mav.active = 1
		GROUP BY mpl.[INVENTORY NUMBER]
		HAVING (SUM(mvi.Quantity) > 0)),
	DBM
	AS
	(SELECT
			P.uniqueId
		FROM OMC.dbo.Master_Vendor_Inventory AS MVI
		INNER JOIN MMC.dbo.product AS P
			ON P.manufacturer = MVI.manufacturer
			AND P.productid = MVI.productID
			AND P.finish = MVI.finish
		WHERE (P.status IN ('STOCK', 'NONSTOCK'))
		AND EXISTS (SELECT
				1 AS Expr1
			FROM OMC.dbo.discontinuedInventory AS I
			WHERE (uniqueId = P.uniqueId))
		GROUP BY P.uniqueId
		HAVING (MAX(MVI.last_modified_timestamp) >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE)))
		AND (SUM(MVI.Quantity) <= 5))
	SELECT
		MB.Uniqueid AS SKU
	   ,CASE
			WHEN MI.[TotalQuantity] <= 1 THEN 0
			WHEN MI.[TotalQuantity] IS NULL THEN 0
			WHEN mpl.Attribute302Value = '999999' THEN 0
			ELSE MI.[TotalQuantity]
		END AS QUANTITY
	   ,CASE
			WHEN MPL.ATTRIBUTE301VALUE = '_DELETE_' THEN MB.PB1
			ELSE CAST((MPL.ATTRIBUTE301VALUE + MB.PB1) AS DECIMAL(18, 2))
		END AS PRICE
	   ,CASE
			WHEN mpl.HouzzLabel = '-Houzz Active' THEN 'Discontinued'
			WHEN WL.[303] = 1 and mpl.houzzlabel = 'Houzz Active' THEN 'Active'
			WHEN HB.[303] = 0 THEN 'Discontinued'
			WHEN BM.[303] = 0 THEN 'Discontinued'
			WHEN mpl.HouzzLabel = 'Houzz Active' THEN 'Active'
			ELSE 'Discontinued'
		END AS STATUS
	   ,'Update' AS Action
	FROM Departments.marketplace.automatedListingBase AS MB
	INNER JOIN MMC.dbo.product AS P
		ON P.uniqueId = MB.Uniqueid
	INNER JOIN Departments.marketplace.automatedListingLog AS mpl
		ON mpl.[INVENTORY NUMBER] = MB.Uniqueid
	LEFT OUTER JOIN DBM AS dbm
		ON dbm.uniqueId = MB.Uniqueid
	LEFT OUTER JOIN MarketplaceInventory AS MI
		ON MI.UniqueID = MB.Uniqueid
	LEFT OUTER JOIN HouzzBlacklist AS hb
		ON hb.UniqueID = MB.Uniqueid
	LEFT OUTER JOIN BlacklistManufacturer AS BM
		ON BM.uniqueId = MB.Uniqueid
	left join Departments.marketplace.whitelistUniqueID as WL
		on WL.uniqueid = MB.Uniqueid

GO
