--Created in SQL Server Management Studio 19 (SSMS)
CREATE DATABASE personal_finances;
GO

USE personal_finances;
GO

DROP TABLE IF EXISTS transactions
CREATE TABLE transactions (
	entry_id int IDENTITY(2910,1) NOT NULL PRIMARY KEY,
	entry_date date,
	category varchar(40),
	specific_expense varchar(40),
	spent float
);
GO

INSERT INTO transactions (entry_date, category, specific_expense, spent)
SELECT 
	CAST([Date] AS date),
	[Category],
	[Specific Expense],
	[Spent]
FROM [dbo].[Personal Finances] --Previously imported this table to the database from an Excel file I use to track my expenses
GO


CREATE PROCEDURE monthly_expenses
AS
BEGIN TRY
	DROP TABLE IF EXISTS #monthly_expenses
	SELECT
		DATEPART(month,entry_date) [Month],
		DATEPART(year,entry_date) [Year],
		category [Category],
		SUM(spent) [Total_Spent]
	INTO #monthly_expenses
	FROM transactions
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
		ISNULL([Deposit],0) - ([Rent] + ISNULL([Investing],0) + ISNULL([Car],0) + 
								ISNULL([Groceries],0) + ISNULL([Newton],0) + 
								ISNULL([Miscellaneous/Fun],0)) [Savings: Rebuilding Emergency Fund]
	FROM #monthly_expenses_pivot '

	EXEC(@SQLquery);
	
	DROP TABLE IF EXISTS #monthly_expenses
	DROP TABLE IF EXISTS #monthly_categories

END TRY

BEGIN CATCH
	SELECT
		ERROR_NUMBER() AS ErrorNumber  
		,ERROR_SEVERITY() AS ErrorSeverity  
		,ERROR_STATE() AS ErrorState  
		,ERROR_PROCEDURE() AS ErrorProcedure  
		,ERROR_LINE() AS ErrorLine  
		,ERROR_MESSAGE() AS ErrorMessage
END CATCH
GO


CREATE PROCEDURE category_expenses (@month varchar(2), @year varchar(4))
AS

DECLARE @year_month varchar(6);
SET @year_month = CONCAT(@year, @month);

IF (@year_month NOT IN(SELECT DISTINCT CONCAT(CAST(DATEPART(year,entry_date) AS varchar(4)), 
											  CAST(DATEPART(month,entry_date) AS varchar(2)))
						FROM personal_finances.dbo.transactions))
	BEGIN
		PRINT('The month-year pair you are looking for is not available.')
		RETURN
	END

DROP TABLE IF EXISTS #category_total
SELECT 
	[Category],
	SUM(spent) [Total Spent]
INTO #category_total
FROM transactions
WHERE 
	DATEPART(month,entry_date) = @month
	AND DATEPART(year,entry_date) = @year
GROUP BY category;

SELECT 
	t1.[Category],
	FORMAT(t1.[Total Spent],'C','en-US') [Total Spent],
	FORMAT(t1.[Total Spent] / (SELECT [Total Spent] FROM #category_total WHERE [Category] = 'Deposit'),'P') [Percentage of Total Monthly Budget]
FROM (
	SELECT *
	FROM #category_total
	UNION
	SELECT 
		'Savings',
		(SELECT [Total Spent] FROM #category_total WHERE [Category] = 'Deposit') - SUM([Total Spent])
	FROM #category_total
	WHERE NOT [Category] = 'Deposit'
) t1
WHERE NOT t1.[Category] = 'Deposit'

DROP TABLE IF EXISTS #category_total
GO

EXEC dbo.category_expenses @month = '3', @year = '2024'
