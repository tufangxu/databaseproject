USE master;
GO
ALTER DATABASE TimeTravel SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO

DROP DATABASE TimeTravel

CREATE DATABASE TimeTravel
GO
USE TimeTravel
GO


CREATE TABLE PORTAL
(PortalID INT IDENTITY(1,1) primary key not null,
PortalName varchar(50) not null,
PortalDescr varchar(500) null,
Latitude decimal(9,6) not null,
Longitude decimal(9,6) not null)
GO

CREATE TABLE MAINTENANCE_TYPE
(MaintenanceTypeID INTEGER IDENTITY(1,1) primary key not null, 
MaintenanceTypeName varchar(50) not null,
MaintenanceTypeDescr varchar(500) null)
GO

CREATE TABLE MAINTENANCE 
(MaintenanceID INTEGER IDENTITY(1,1) primary key not null,
MaintenanceName varchar (50) not null,
MainTenanceDescr varchar (500) null,
MaintenanceTypeID INT FOREIGN KEY REFERENCES MAINTENANCE_TYPE(MaintenanceTypeID) not null,
PortalID INT FOREIGN KEY REFERENCES PORTAL(PortalID) not null)
GO

CREATE TABLE TRIP
(TripID INTEGER IDENTITY(1,1) primary key not null,
PortalID INT FOREIGN KEY REFERENCES PORTAL(PortalID) not null,
OriginTime datetime not null,
DestStartTime datetime not null,
TripName varchar(50) not null,
TripDescr varchar(500) null)
GO


CREATE TABLE PERSON_TYPE
(PersonTypeID INTEGER IDENTITY(1,1) primary key not null,
PersonTypeName varchar(50) not null,
PersonTypeDescr varchar(500) null)
GO

CREATE TABLE [ADDRESS]
(AddressID INT IDENTITY(1,1) primary key not null,
AddressLineOne varchar(200) not null,
AddressLineTwo varchar(200) not null,
AddressCity varchar(60) not null,
AddressZipCode INT Not null,
AddressState varchar(20) not null,
AddressCountry varchar(50) not null)
GO

CREATE TABLE PERSON
(PersonID INTEGER IDENTITY(1,1) primary key not null,
PersonFName varchar(50) not null,
PersonLName varchar(50) not null,
PersonBirthDate DATE not null,
PersonTypeID INT FOREIGN KEY REFERENCES PERSON_TYPE(PersonTypeID) not null,
AddressID INT FOREIGN KEY REFERENCES ADDRESS(AddressID) not null)
GO


CREATE TABLE CURRENCY_TYPE
(CurrencyTypeID INTEGER IDENTITY(1,1) primary key not null,
CurrencyTypeName varchar(60) not null,
CurrencyTypeDescr varchar(500) null)
GO

CREATE TABLE CURRENCY_ORDER
(CurrencyOrderID INTEGER IDENTITY(1,1) primary key not null,
CurrencyOrderName varchar(60) not null,
CurrencyTypeID INTEGER FOREIGN KEY REFERENCES CURRENCY_TYPE(CurrencyTypeID) not null,
PersonID INT FOREIGN KEY REFERENCES PERSON(PersonID) not null,
DesiredCurrencyDate DATE not null,
OrderQuantity INT not null)
GO

CREATE TABLE PERSON_TRIP
(PersonTripID INTEGER IDENTITY(1,1) primary key not null, 
PersonID INT FOREIGN KEY REFERENCES PERSON(PersonID) not null,
TripID INT FOREIGN KEY REFERENCES TRIP(TripID) not null,
TripReport varchar(500) null,
TripDestEndTime DATE null)
GO

CREATE TABLE INCIDENT_TYPE
(IncidentTypeID INTEGER IDENTITY(1,1) primary key not null,
IncidentTypeName varchar(100) not null,
IncidentTypeDescr varchar(500) null)
GO

CREATE TABLE INCIDENT 
(IncidentID INTEGER IDENTITY(1,1) primary key not null,
IncidentTypeID INT FOREIGN KEY REFERENCES INCIDENT_TYPE(IncidentTypeID) not null,
IncidentName varchar(100) not null,
IncidentDescr varchar(500) null,
IncidentDestDate DATETIME not null,
IncidentOriginDate DATETIME not null)
GO

CREATE TABLE PERSON_INCIDENT
(PersonID INT FOREIGN KEY REFERENCES PERSON(PersonID) not null,
IncidentID INT FOREIGN KEY REFERENCES INCIDENT(IncidentID) not null,
primary key (PersonID, IncidentID))

GO
--------------------------------------------------------------------------------INSERTS

INSERT INTO PERSON_TYPE (PersonTypeName, PersonTypeDescr)
VALUES ('Customer', 'Gives us money'), ('Employee', 'Makes us money')

INSERT INTO INCIDENT_TYPE (IncidentTypeName, IncidentTypeDescr)
VALUES ('Traffic Accident','Get hit by vehicles'), ('Machine Malfunction', 'Time machine goes wrong'),('Natural Death','Heart Attack/Stroke sometimes happens'),
('Unexpected Death', 'Eaten by dinosaurs..'),('Food Poision','Fed by exotic food, got sick/allergic..'),('Horrified', 'Customers get scared by abnormal creatures they encounter')

INSERT INTO CURRENCY_TYPE (CurrencyTypeName, CurrencyTypeDescr)
VALUES ('US Dollars', '$'), ('Canadian Dollars', '$'), ('Euro', '€')

INSERT INTO MAINTENANCE_TYPE (MaintenanceTypeName, MaintenanceTypeDescr)
VALUES ('Calibration', 'Ensure portal is in unison with others'), ('Cleaning', 'Make sure Portal is looking its best')

INSERT INTO PORTAL (PortalName, PortalDescr, Latitude, Longitude)
VALUES ('Seattle', 'U-District Location', '47.672263', '-122.312179'), ('Paris', 'Eiffel Tower Location', '48.855839', '2.315464'), ('Stockholm', 'Storkyrkan Location', '59.326309', '18.064531')

SELECT * FROM PORTAL

GO
--------------------------------------------------------------------------------BUSINESS RULES
-- Business Rule 1: No one older than 60 years old that has had over 10 incidents in the current year is allowed to travel back in time
CREATE FUNCTION fn_noSeniorRebels()
RETURNS INT
AS
BEGIN
DECLARE @Ret INT
SET @Ret = 0
IF EXISTS (SELECT * 
			FROM INCIDENT AS I 
				JOIN PERSON_INCIDENT AS PI ON I.IncidentID = PI.IncidentID 
				JOIN PERSON AS P ON PI.PersonID = P.PersonID 
			WHERE PersonBirthDate > GETDATE() - (365.25 * 60) AND YEAR(IncidentOriginDate) = YEAR(GETDATE())
		GROUP BY PI.PersonID
		HAVING COUNT(PI.IncidentID) > 10) 
	SET @Ret = 1
RETURN @Ret
END

GO

ALTER TABLE PERSON_TRIP
ADD CONSTRAINT ck_SeniorRebels
CHECK (dbo.fn_noSeniorRebels() = 0)

GO

-- Business Rule 2: TripDestEndTime cannot be earlier in time than DestStartTime
CREATE FUNCTION noearlier()
RETURNS INT
AS 
BEGIN
DECLARE @Ret INT
SET @Ret = 0
IF EXISTS (SELECT * FROM TRIP T
			JOIN PERSON_TRIP PT
			ON PT.TripID = T.TripID
			WHERE PT.TripDestEndTime < T.DestStartTime)
			SET @Ret = 1
			RETURN @Ret
END

GO

ALTER TABLE  PERSON_TRIP
ADD constraint endtimenoearlier
Check (dbo.noearlier() = 0)
GO

-- Business Rule 3: No traveling forward in time
CREATE FUNCTION notravelforward()
RETURNS INT 
AS 
BEGIN 
DECLARE @Ret INT
SET @Ret = 0 
IF EXISTS (SELECT * FROM TRIP T
			WHERE T.DestStartTime > GETDATE())
			SET @Ret = 1
			RETURN @Ret
END

GO

ALTER TABLE TRIP
ADD Constraint noforwardtravel
Check (dbo.notravelforward() = 0)

GO

-- Business Rule 4: No traveling to Dangerous places if customers are younger than 18
CREATE FUNCTION norisk()
RETURNS INT 
AS 
BEGIN 
DECLARE @Ret INT
SET @Ret = 0 
IF EXISTS (SELECT * FROM TRIP T
			JOIN PERSON_TRIP PT
			ON PT.TripID = T.TripID
			JOIN PERSON P
			ON P.PersonID = PT.PersonID
			WHERE T.TripDescr LIKE '%dangerous%' 
			AND P.PersonBirthDate <(SELECT GETDATE() - 365.25 * 18))
			SET @Ret = 1
			RETURN @Ret
END

GO

ALTER TABLE TRIP
ADD Constraint CK_norisk
Check (dbo.norisk() = 0)

GO
--------------------------------------------------------------------------------STORED PROCEDURES

CREATE PROCEDURE uspNewPerson
@PersonFName VARCHAR(50),
@PersonLName VARCHAR(50),
@PersonBirthDate DATE,
@AddressLineOne VARCHAR(200),
@AddressLineTwo VARCHAR(200),
@AddressCity VARCHAR(60),
@AddressZipCode INT,
@AddressState VARCHAR(20),
@AddressCountry VARCHAR(50),
@PersonTypeName VARCHAR(50)
AS
DECLARE @PersonTypeID INT
DECLARE @AddressID INT

SET @PersonTypeID = (SELECT PersonTypeID FROM PERSON_TYPE
						WHERE PersonTypeName = @PersonTypeName)

IF EXISTS (SELECT AddressID FROM [ADDRESS]
			WHERE AddressLineOne = @AddressLineOne
				AND AddressLineTwo = @AddressLineTwo
				AND AddressCity = @AddressCity
				AND AddressZipCode = @AddressZipCode
				AND AddressState = @AddressState
				AND AddressCountry = @AddressCountry)
	SET @AddressID = (SELECT AddressID FROM [ADDRESS]
						WHERE AddressLineOne = @AddressLineOne
							AND AddressLineTwo = @AddressLineTwo
							AND AddressCity = @AddressCity
							AND AddressZipCode = @AddressZipCode
							AND AddressState = @AddressState
							AND AddressCountry = @AddressCountry)
ELSE
	BEGIN
		INSERT INTO ADDRESS (AddressLineOne, AddressLineTwo, AddressCity, AddressZipCode, AddressState, AddressCountry)
		VALUES (@AddressLineOne, @AddressLineTwo, @AddressCity, @AddressZipCode, @AddressState, @AddressCountry)
		SET @AddressID = (SELECT Scope_Identity())
	END

INSERT INTO PERSON (PersonFName, PersonLName, PersonBirthDate, PersonTypeID, AddressID)
VALUES (@PersonFName, @PersonLName, @PersonBirthDate, @PersonTypeID, @AddressID)

GO

CREATE PROCEDURE uspNewTrip
@PersonFName VARCHAR(50),
@PersonLName VARCHAR(50),
@PersonBirthDate DATE,
@PortalName VARCHAR(50),
@DestStartTime datetime,
@TripName varchar(50),
@TripDescr varchar(500)
AS
DECLARE @PersonID INT
DECLARE @PortalID INT
DECLARE @TripID INT

SET @PersonID = (SELECT PersonID
					FROM PERSON
					WHERE PersonFName = @PersonFName
						AND PersonLName = @PersonLName
						AND PersonBirthDate = @PersonBirthDate)
SET @PortalID = (SELECT PortalID
					FROM PORTAL
					WHERE PortalName = @PortalName)

INSERT INTO TRIP (PortalID, OriginTIme, DestStartTime, TripName, TripDescr)
VALUES (@PortalID, GetDate(), @DestStartTime, @TripName, @TripDescr)
SET @TripID = (SELECT Scope_Identity())
INSERT INTO PERSON_TRIP (PersonID, TripID)
VALUES (@PersonID, @TripID)

GO

CREATE PROCEDURE uspNewIncident
@PersonFName VARCHAR(50),
@PersonLName VARCHAR(50),
@PersonBirthDate DATE,
@IncidentName VARCHAR(50),
@IncidentDescr VARCHAR(500),
@IncidentDestDate DATETIME,
@IncidentOriginDate DATETIME,
@IncidentTypeName VARCHAR(50)
AS
DECLARE @PersonID INT
DECLARE @IncidentTypeID INT
DECLARE @IncidentID INT

SET @PersonID = (SELECT PersonID
					FROM PERSON
					WHERE PersonFName = @PersonFName
						AND PersonLName = @PersonLName
						AND PersonBirthDate = @PersonBirthDate)
SET @IncidentTypeID = (SELECT IncidentTypeID
						FROM INCIDENT_TYPE
						WHERE IncidentTypeName = @IncidentTypeName)

INSERT INTO INCIDENT (IncidentTypeID, IncidentName, IncidentDescr, IncidentDestDate, IncidentOriginDate)
VALUES (@IncidentTypeID, @IncidentName, @IncidentDescr, @IncidentDestDate, @IncidentOriginDate)
SET @IncidentID = (SELECT SCOPE_IDENTITY())
INSERT INTO PERSON_INCIDENT (PersonID, IncidentID)
VALUES (@PersonID, @IncidentID)

GO

--Stored Procedure. Add a new currency order and new currency type
 
CREATE PROCEDURE usp_newCurrency
@PersonFName varchar(50),
@PersonLName varchar(50),
@PersonBirthDate date,
@OrderQty int,
@CurrencyOrderName VARCHAR(50),
@DesiredCurrencyDate date,
@CurrencyName varchar(50)
AS 
DECLARE @CurrencyTypeID int
DECLARE @PersonID INT = (SELECT PERSONID FROM PERSON AS P WHERE  P.PersonFName = @PersonFName AND P.PersonLName = @PersonLName AND P.PersonBirthDate = @PersonBirthDate)
DECLARE @CurrencyOrderID int
 
BEGIN TRAN
INSERT INTO CURRENCY_TYPE (CurrencyTypeName)
VALUES (@CurrencyName)
SET @CurrencyTypeID = (SELECT SCOPE_IDENTITY())
 
INSERT INTO CURRENCY_ORDER (PersonID, OrderQuantity, CurrencyTypeID, DesiredCurrencyDate, CurrencyOrderName)
VALUES (@PersonID, @OrderQty, @CurrencyTypeID, @DesiredCurrencyDate, @CurrencyOrderName)
COMMIT TRAN

GO

--Stored Procedure. Add a new maintenance and maintenance type
CREATE PROCEDURE usp_newMaintenance
@PortalName varchar(50),
@Longitude decimal(9,6),
@Latitude decimal(9,6),
@MaintenanceName varchar(50),
@MaintenanceDescr varchar(500),
@MaintenanceTypeName varchar(50)
AS 
DECLARE @MaintenanceTypeID int
DECLARE @MaintenanceID int
DECLARE @PortalID INT = (SELECT PortalID FROM PORTAL AS P WHERE P.PortalName = @PortalName AND P.Latitude = @Latitude AND P.Longitude = @Longitude)
 
BEGIN TRAN
INSERT INTO MAINTENANCE_TYPE (MaintenanceTypeName)
VALUES (@MaintenanceTypeName)
 
SET @MaintenanceTypeID = (SELECT SCOPE_IDENTITY())
 
INSERT INTO MAINTENANCE (MaintenanceName, PortalID, MaintenanceTypeID, MaintenanceDescr)
VALUES (@MaintenanceName, @PortalID, @MaintenanceTypeID, @MaintenanceDescr)
COMMIT TRAN

GO

--Stored Procedure. Add a new incident and incident type
CREATE PROCEDURE usp_newIncidentAndType
@IncidentTypeName varchar(50),
@IncidentTypeDesc varchar(500),
@IncidentName varchar(50),
@IncidentDesc varchar(500),
@IncidentOriginDate DATETIME,
@IncidentDestDate DATETIME,
@PersonFName varchar(50),
@PersonLName varchar(50),
@PersonBirthDate date
AS 
DECLARE @IncidentTypeID int
DECLARE @IncidentID int
DECLARE @PersonID int = (SELECT PERSONID FROM PERSON AS P WHERE  P.PersonFName = @PersonFName AND P.PersonLName = @PersonLName AND P.PersonBirthDate = @PersonBirthDate)
 
BEGIN TRAN
INSERT INTO INCIDENT_TYPE (IncidentTypeName, IncidentTypeDescr)
VALUES (@IncidentTypeName, @IncidentTypeDesc)
 
SET @IncidentTypeID = (SELECT SCOPE_IDENTITY())
 
INSERT INTO INCIDENT (IncidentName, IncidentOriginDate, IncidentDestDate, IncidentTypeID, IncidentDescr)
VALUES (@IncidentName, @IncidentOriginDate, @IncidentDestDate, @IncidentTypeID, @IncidentDesc)
COMMIT TRAN

GO

CREATE PROCEDURE usp_newPortalTrip
@PortalName varchar(50),
@Longitude decimal(9,6),
@Latitude decimal(9,6),
@PortalDescr varchar(500),
@OriginTime datetime,
@DestStartTime datetime,
@TripName varchar(50),
@TripDescr varchar(500)
AS 
DECLARE @PortalID int
 
BEGIN TRAN
INSERT INTO PORTAL (PortalName, Longitude, Latitude, PortalDescr)
	VALUES (@PortalName, @Longitude, @Latitude, @PortalDescr)
	SET @PortalID = (SELECT Scope_Identity())
 
INSERT INTO TRIP (PortalID, OriginTime, DestStartTime, TripName, TripDescr)
VALUES (@PortalID, @OriginTime, @DestStartTime, @TripName, @TripDescr)

COMMIT TRAN

GO

--Stored Procedure. Add a new currency order and address and person
CREATE PROCEDURE usp_newPersonAddressCurrency
@AddressLineOne varchar(200),
@AddressLineTwo VARCHAR(200),
@AddressCity VARCHAR(60),
@AddressZipCode INT,
@AddressState VARCHAR(20),
@AddressCountry VARCHAR(50),
@PersonTypeName varchar(50),
@PersonFName varchar(50),
@PersonLName varchar(50),
@PersonBirthDate date,
@OrderDate date,
@OrderQty int,
@DesiredCurrencyDate date,
@CurrencyTypeName VARCHAR(50)
AS 
DECLARE @AddressID int
DECLARE @CurrencyOrderID int
DECLARE @PersonID INT
DECLARE @PersonTypeID int = (SELECT PERSONTYPEID FROM PERSON_TYPE AS PT WHERE  PT.PersonTypeName = @PersonTypeName)
DECLARE @CurrencyTypeID INT = (SELECT CurrencyTypeID FROM CURRENCY_TYPE WHERE CurrencyTypeName = @CurrencyTypeName)
 
BEGIN TRAN
INSERT INTO ADDRESS (AddressLineOne, AddressLineTwo, AddressCity, AddressZipCode, AddressState, AddressCountry)
	VALUES (@AddressLineOne, @AddressLineTwo, @AddressCity, @AddressZipCode, @AddressState, @AddressCountry)
	SET @AddressID = (SELECT Scope_Identity())
 
INSERT INTO PERSON (PersonFName, PersonLName, PersonBirthDate, PersonTypeID, AddressID)
VALUES (@PersonFName, @PersonLName, @PersonBirthDate, @PersonTypeID, @AddressID)

SET @PERSONID = (SELECT SCOPE_IDENTITY())
 
INSERT INTO CURRENCY_ORDER (PersonID, OrderQuantity, CurrencyTypeID, DesiredCurrencyDate, CurrencyOrderName)
VALUES (@PersonID, @OrderQty, @CurrencyTypeID, @DesiredCurrencyDate, CONCAT(@PersonFName, ' ', @PersonLName, ' ', @OrderQty, ' ', @CurrencyTypeName))
COMMIT TRAN

GO
--------------------------------------------------------------------------------TESTING PROCEDURES

EXEC uspNewPerson
@PersonFName = 'Kyle',
@PersonLName = 'Wistrand',
@PersonBirthDate = '05/26/1997',
@AddressLineOne = '6415 9th Ave NE',
@AddressLineTwo = 'UNIT D',
@AddressCity = 'Seattle',
@AddressZipCode = '98115',
@AddressState = 'Washington',
@AddressCountry = 'United States',
@PersonTypeName = 'Customer'

SELECT * FROM PERSON

EXEC uspNewPerson
@PersonFName = 'Greg',
@PersonLName = 'Hay',
@PersonBirthDate = '12/19/1966',
@AddressLineOne = '16106 NE 107th Way',
@AddressLineTwo = '',
@AddressCity = 'Redmond',
@AddressZipCode = '98052',
@AddressState = 'Washington',
@AddressCountry = 'United States',
@PersonTypeName = 'Customer'

SELECT * FROM PERSON

EXEC uspNewTrip
@PersonFName = 'Kyle',
@PersonLName = 'Wistrand',
@PersonBirthDate  = '05/26/1997',
@PortalName = 'Seattle',
@DestStartTime = '04/21/1962 10:00:00',
@TripName = 'Seattle World''s Fair',
@TripDescr = 'Kyle''s going back to see the Seattle World''s fair'

SELECT * FROM TRIP

EXEC uspNewIncident
@PersonFName = 'Greg',
@PersonLName = 'Hay',
@PersonBirthDate  = '12/19/1966',
@IncidentName = 'Greg Horrified by Databases Past',
@IncidentDescr = 'Greg saw what databases looked like in the 60''s and he couldn''t help but have a tear in his eye when he though about how far databases have come',
@IncidentDestDate = '05/26/1962 12:00:00',
@IncidentOriginDate = '05/26/1997 9:31:47',
@IncidentTypeName = 'Horrified'

SELECT * FROM INCIDENT

EXEC usp_newMaintenance
@MaintenanceTypeName = 'Cleaning',
@MaintenanceName = 'Cleaning portal time shield',
@MaintenanceDescr = 'It''s spick and span now!',
@Latitude = '47.672263',
@Longitude = '-122.312179',
@PortalName = 'Seattle'

SELECT * FROM MAINTENANCE

EXEC usp_NewCurrency
@CurrencyOrderName = '$10,000 to Kyle',
@CurrencyName = 'US Dollar',
@OrderQty = '10000',
@DesiredCurrencyDate = '01/01/0079',
@PersonFName = 'Kyle',
@PersonLName = 'Wistrand',
@PersonBirthDate = '05/26/1997'

SELECT * FROM CURRENCY_ORDER

EXEC usp_newIncidentAndType
@IncidentTypeName = 'Date Error',
@IncidentTypeDesc = 'Date is returned incorrectly',
@IncidentName = 'Dest Date was off by 3 seconds',
@IncidentDesc = 'Traveler was unharmed',
@IncidentOriginDate = '04/23/2017 11:34:56',
@IncidentDestDate = '05/11/1987 10:44:12',
@PersonFName = 'Greg',
@PersonLName = 'Hay',
@PersonBirthDate = '12/19/1966'

SELECT * FROM INCIDENT
SELECT * FROM INCIDENT_TYPE

EXEC usp_newPersonAddressCurrency
@PersonFName = 'Sam',
@PersonLName = 'Smith',
@PersonBirthDate = '02/12/1996',
@AddressLineOne = '106 NE 107th Way',
@AddressLineTwo = '',
@AddressCity = 'Redmond',
@AddressZipCode = '98052',
@AddressState = 'Washington',
@AddressCountry = 'United States',
@PersonTypeName = 'Customer',
@OrderDate = '12/19/2017',
@OrderQty = '10',
@DesiredCurrencyDate = '12/13/1600',
@CurrencyTypeName = 'US Dollar'

EXEC usp_newPortalTrip
@PortalName = 'Barcelona',
@Longitude = '42.55787',
@Latitude = '1.56788',
@PortalDescr = 'Pretty cool',
@OriginTime = '11/18/2017 10:10:56',
@DestStartTime = '11/18/1997 10:10:56',
@TripName = 'Girls Date',
@TripDescr = 'Super fun trip!'