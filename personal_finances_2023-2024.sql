--Created in SQL Server Management Studio 19 (SSMS)
CREATE DATABASE personal_finances;
GO

USE personal_finances;
GO

DROP TABLE IF EXISTS [Personal Finances]
CREATE TABLE [Personal Finances] (
	entry_id int IDENTITY(2910,1) NOT NULL PRIMARY KEY,
	entry_date date,
	category varchar(40),
	specific_expense varchar(40),
	spent float
);
GO


CREATE PROCEDURE monthly_expenses
AS
BEGIN TRY
	DROP TABLE IF EXISTS #monthly_expenses
	SELECT
		DATEPART(month,entry_date) [Month],
		DATEPART(year,entry_date) [Year],
		Category,
		SUM(Spent) [Total_Spent]
	INTO #monthly_expenses
	FROM [personal_finances].[dbo].[Personal Finances]
	GROUP BY DATEPART(month,entry_date), DATEPART(year,entry_date), category 
	ORDER BY [Year], [Month]

	DROP TABLE IF EXISTS #monthly_categories
	SELECT 
		DISTINCT [Category] 
	INTO #monthly_categories
	FROM #monthly_expenses;

	/*  This is meant to take into account when I add another category in the future to the 
		transactions table -> descreases the amount of code below I need to adjust */
	DECLARE 
		@SQLquery varchar(2000),
		@columns nvarchar(MAX);

	SELECT 
		@columns = ISNULL(@columns + ',', '') + '[' + [Category] + ']'
	FROM #monthly_categories
	ORDER BY [Category];

	SET @SQLquery = '
		SELECT *
		INTO #monthly_expenses_pivot
		FROM #monthly_expenses src
		PIVOT (
			SUM(Total_Spent)
			FOR Category IN (' + @columns + ')
		) AS pivot_table
	
	SELECT
		[Month],
		[Year],
		[Rent],
		ISNULL([Car],0) [Car & Insurance],
		ISNULL([Investing],0) [Roth IRA],
		ISNULL([Groceries],0) [Groceries],
		ISNULL([Newton],0) [Newton],
		ISNULL([Miscellaneous/Fun],0) [Miscellaneous/Fun],
		ISNULL([Emergency Fund],0) [From Emergency Fund],
		ISNULL([From Savings],0) [From Savings],
		ISNULL([Savings],0) [Savings]
	FROM #monthly_expenses_pivot '

	EXEC(@SQLquery);
	
	DROP TABLE IF EXISTS #monthly_expenses
	DROP TABLE IF EXISTS #monthly_categories

END TRY

BEGIN CATCH
	SELECT
		ERROR_NUMBER() AS ErrorNumber
		,ERROR_MESSAGE() AS ErrorMessage
		,ERROR_PROCEDURE() AS ErrorProcedure
		,ERROR_STATE() AS ErrorState
		,ERROR_SEVERITY() AS ErrorSeverity   
		,ERROR_LINE() AS ErrorLine
		,getdate()	
END CATCH
GO


CREATE PROCEDURE category_expenses (@month varchar(2), @year varchar(4))
AS

DECLARE @year_month varchar(6);
SET	@year_month = CONCAT(@year, @month);

IF (@year_month NOT IN(SELECT DISTINCT CONCAT(CAST(DATEPART(year,entry_date) AS varchar(4)), 
											  CAST(DATEPART(month,entry_date) AS varchar(2)))
						FROM dbo.[Personal Finances]))
	BEGIN
		PRINT('The month-year pair you are looking for is not available.')
		RETURN
	END

	DROP TABLE IF EXISTS #category_total
	SELECT 
		[Category],
		SUM(spent) [Total Spent]
	INTO #category_total
	FROM [dbo].[Personal Finances]
	WHERE 
		DATEPART(month,entry_date) = @month
		AND DATEPART(year,entry_date) = @year
	GROUP BY category;

	SELECT
		[Category],
		FORMAT([Total Spent],'C','en-US') [Total Spent],
		FORMAT([Total Spent] / 2800,'P') [Percentage of Total Monthly Budget]
	FROM #category_total

	DROP TABLE IF EXISTS #category_total
GO

EXEC dbo.category_expenses @month = '3', @year = '2024'
