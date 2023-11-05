---selecting all data from both tables to check that everything is working fine
SELECT *
FROM PortfolioprojectCorona..CovidDeaths

SELECT*
FROM PortfolioprojectCorona..CovidVaccinations

--- Selecting the data that we are going to be using
SELECT location,date, total_cases,new_cases,total_deaths,population
FROM PortfolioprojectCorona..CovidDeaths
ORDER BY 1,2;

---Looking at total cases vs total death in Morocco for example
---This shows the likelihood of dying if you contract Covid in your country 

SELECT location,date, total_cases,total_deaths,Convert(float,total_deaths)/Convert(float,total_cases)* 100 AS Deathpercentage
FROM PortfolioprojectCorona..CovidDeaths
WHERE location like '%Morocco%'
ORDER BY 1,2 desc;

---Looking at total cases vs population
---Shows the percentage of population infected
SELECT location,date, total_cases,population,Convert(float,total_cases)/Convert(float,population)* 100 AS infectionpercentage
FROM PortfolioprojectCorona..CovidDeaths
------WHERE location like 'Morocco'
ORDER BY 2 desc;

---Countries with the highest infection rates
SELECT location,population, Max(Convert(float,total_cases)) as Max_cases, Max(Convert(float,total_cases)/Convert(float,population)* 100) AS Max_infectionpercentage
FROM PortfolioprojectCorona..CovidDeaths
GROUP BY location,population
ORDER BY 4 desc;

---Countries with highest death percentage
SELECT location,population, MAX(Convert(float,total_deaths)/Convert(float,total_cases)*100)as Max_death_percentage
FROM PortfolioprojectCorona..CovidDeaths
WHERE continent is not NULL
GROUP BY location,population
ORDER BY 3 Desc;

---Let's break down things by continents

SELECT continent, MAX(cast(total_deaths as int)) as TotalDeathPerContinent
FROM PortfolioprojectCorona..CovidDeaths
WHERE continent is not null
GROUP BY continent
ORDER BY 2 DESC;


-------Global numbers 
SELECT date, SUM(new_cases)as totalCases,SUM(new_deaths) as totalDeaths, 
			(SUM(new_deaths)/SUM(NULLIF(Convert(float,new_cases),0)))*100 as deathPercentage
FROM PortfolioprojectCorona..CovidDeaths
WHERE continent is not NULL
GROUP BY date
ORDER BY 4;
 

 ---Looking at total Population vs vaccination 
 ---We need to join both tables and then calculate a rolling number of new vaccinations for each location

SELECT dea.continent,dea.location,dea.date,dea.population,vac.new_vaccinations,
		SUM(CONVERT(FLOAT,vac.new_vaccinations)) 
		OVER(PARTITION BY dea.location ORDER BY vac.location,vac.date) as rollingNumberNewVaccinations--,vac.total_vaccinations
FROM PortfolioprojectCorona..CovidDeaths dea
JOIN PortfolioprojectCorona..CovidVaccinations vac
		ON dea.location=vac.location
		AND dea.date=vac.date
WHERE vac.new_vaccinations is not NULL and dea.continent is not null --this line is to display only countries (Not continents)  
                                                              --and to avoid Null values when seeing the cummulative value of the rolling number
--AND dea.location like 'Morocco' -- you can activate this line to see results only for your country
ORDER BY 2,3;


------1st method is to use CTE to calculate population vs vaccination 
------as we can not calculate it in above code where we have just defined the window function with the new column 
------that we need to use for this proportion
WITH PopulationVsVaccin (continents,locations,dates,populations,newVaccinations,rollingNumberNewVaccination)
AS
(SELECT dea.continent,dea.location,dea.date,dea.population,vac.new_vaccinations,
		SUM(CONVERT(FLOAT,vac.new_vaccinations)) 
		OVER(PARTITION BY dea.location ORDER BY dea.location,dea.date) as rollingNumberNewVaccinations--,vac.total_vaccinations
FROM PortfolioprojectCorona..CovidDeaths dea
JOIN PortfolioprojectCorona..CovidVaccinations vac
		ON dea.location=vac.location
		AND dea.date=vac.date
WHERE vac.new_vaccinations is not NULL and dea.continent is not null --this line is to display only countries (Not continents)  
                                                              --and to avoid Null values when seeing the cummulative value of the rolling number

--ORDER BY 2,3;
)

--SELECT *, (rollingNumberNewVaccination/populations)*100 as percent_vaccinated_population

SELECT locations,MAX ((rollingNumberNewVaccination/populations)*100) as Max_percent_vaccinated_population
FROM PopulationVsVaccin
GROUP BY locations

------2nd method is to use TEM TABLE to calculate population vs vaccination 

DROP TABLE IF EXISTs #percentPeopleVaccinated --- this line allows to delete  the temporary table before recreating it
CREATE TABLE #percentPeopleVaccinated
( 
continent nvarchar(255),
location nvarchar(255),
date datetime,
population int,
newVaccinations int,
rollingNumberNewVaccinations float
)

INSERT INTO #percentPeopleVaccinated
SELECT dea.continent,dea.location,dea.date,dea.population,vac.new_vaccinations,
		SUM(CONVERT(FLOAT,vac.new_vaccinations)) 
		OVER(PARTITION BY dea.location ORDER BY dea.location,dea.date) as rollingNumberNewVaccinations--,vac.total_vaccinations
FROM PortfolioprojectCorona..CovidDeaths dea
JOIN PortfolioprojectCorona..CovidVaccinations vac
		ON dea.location=vac.location
		AND dea.date=vac.date
WHERE vac.new_vaccinations is not NULL and dea.continent is not null --this line is to display only countries (Not continents)  
                                                              --and to avoid Null values when seeing the cummulative value of the rolling number

--ORDER BY 2,3;


--SELECT *, (rollingNumberNewVaccinations/population)*100 as percent_vaccinated_population
--FROM #percentPeopleVaccinated

SELECT location,MAX ((rollingNumberNewVaccinations/population)*100) as Max_percent_vaccinated_population
FROM #percentPeopleVaccinated
GROUP BY location
ORDER BY 1;


------Creating views for later visualization in TABLEAU

CREATE VIEW percentOfPeopleVaccinated AS
(SELECT dea.continent,
		dea.location,
		dea.date,
		dea.population,
		vac.new_vaccinations,
		SUM(CONVERT(FLOAT,vac.new_vaccinations)) OVER(
			PARTITION BY dea.location 
			ORDER BY dea.location,dea.date
			) as rollingNumberNewVaccinations--,vac.total_vaccinations
FROM PortfolioprojectCorona..CovidDeaths dea
JOIN PortfolioprojectCorona..CovidVaccinations vac
		ON dea.location=vac.location
		AND dea.date=vac.date
WHERE dea.continent is not null AND vac.new_vaccinations is not NULL
)

use [PortfolioprojectCorona]

Select * from [PortfolioprojectCorona].[dbo].[percentOfPeopleVaccinated]

