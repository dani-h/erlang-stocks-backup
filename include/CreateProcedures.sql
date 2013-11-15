/*
*
* Stored procedures for StockDB Database in SQL Server 2008 R2
* @Author : Robert Petre
*
*/
USE StockDB;
GO
CREATE PROCEDURE s_addDaily 
	@Name nvarchar(150),@Symbol nchar(10),@Datetime datetime,
	@CurrentPrice decimal(8,2),@ChangeValue decimal(8,2),@ChangePercent decimal(8,2),
	@PreviousClose decimal(8,2),@Open decimal(8,2),@Volume int,@DayMinPrice decimal(8,2),
	@DayMaxPrice decimal(8,2)
AS 
	SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
	BEGIN TRANSACTION
	MERGE TodayStock WITH (UPDLOCK) AS myTarget
		USING (SELECT @Name AS Name, @Symbol AS Symbol,
		@Datetime AS Datetime, @CurrentPrice AS CurrentPrice,
		@ChangeValue AS ChangeValue, @ChangePercent AS ChangePercent,
		@PreviousClose AS PreviousClose, @Open AS [Open], @Volume AS Volume,
		@DayMinPrice AS DayMinPrice, @DayMaxPrice AS DayMaxPrice) AS mySource
		ON mySource.Symbol = myTarget.Symbol
		WHEN MATCHED 
			THEN UPDATE 
				SET Name = mySource.Name, Datetime = mySource.Datetime,
				CurrentPrice = mySource.CurrentPrice, ChangeValue = mySource.ChangeValue,
				ChangePercent = mySource.ChangePercent, PreviousClose = mySource.PreviousClose,
				[Open] = mySource.[Open], Volume = mySource.Volume,
				DayMinPrice = mySource.DayMinPrice, DayMaxPrice = mySource.DayMaxPrice				
		WHEN NOT MATCHED
			THEN
				INSERT(Name,Symbol,Datetime,CurrentPrice,ChangeValue,ChangePercent,PreviousClose,[Open],Volume,DayMinPrice,DayMaxPrice)
				VALUES(@Name,@Symbol,@Datetime,@CurrentPrice,@ChangeValue,@ChangePercent,@PreviousClose,@Open,@Volume,@DayMinPrice,@DayMaxPrice);
	COMMIT 
GO
CREATE PROCEDURE s_addHistorical
	@Symbol nchar(10),@Date datetime,
	@Open decimal(8,2),@Close decimal(8,2),@MinPrice decimal(8,2),
	@MaxPrice decimal(8,2),@Volume int
AS 
	SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
	BEGIN TRANSACTION
	MERGE HistoricalStock WITH (UPDLOCK) AS myTarget
		USING (SELECT @Symbol AS Symbol,
		@Date AS Date, @Open AS [Open], @Close AS [Close],
		@MinPrice AS MinPrice, @MaxPrice AS MaxPrice,@Volume AS Volume) AS mySource
		ON mySource.Symbol = myTarget.Symbol AND mySource.Date = myTarget.Date
		WHEN MATCHED 
			THEN UPDATE 
				SET [Open] = mySource.[Open], [Close] = mySource.[Close],
				MinPrice = mySource.MinPrice, MaxPrice = mySource.MaxPrice, Volume = mySource.Volume			
		WHEN NOT MATCHED
			THEN
				INSERT(Symbol,Date,[Open],[Close],MinPrice,MaxPrice,Volume)
				VALUES(@Symbol,@Date,@Open,@Close,@MinPrice,@MaxPrice,@Volume);
	COMMIT 
GO
CREATE PROCEDURE s_addNews
	@Symbol nchar(10),@Date datetime,
	@Headline nvarchar(150), @Hyperlink nvarchar(150)
AS 
	SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
	BEGIN TRANSACTION
	MERGE StockNews WITH (UPDLOCK) AS myTarget
		USING (SELECT @Symbol AS Symbol,
		@Date AS Date, @Headline AS Headline, @Hyperlink AS Hyperlink) AS mySource
		ON mySource.Symbol = myTarget.Symbol AND mySource.Headline = myTarget.Headline
		WHEN MATCHED 
			THEN UPDATE 
				SET Hyperlink = mySource.Hyperlink, Date = mySource.Date		
		WHEN NOT MATCHED
			THEN
				INSERT(Symbol,Headline,Hyperlink,Date)
				VALUES(@Symbol,@Headline,@Hyperlink,@Date);
	COMMIT
GO
