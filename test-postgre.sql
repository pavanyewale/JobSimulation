DROP TABLE IF  EXISTS params;
DROP TABLE IF  EXISTS history;
DROP TABLE IF  EXISTS worldClock;
DROP TABLE IF  EXISTS worldState;
DROP TABLE IF  EXISTS clients;
DROP TABLE IF  EXISTS randomJobs;
CREATE TABLE IF NOT EXISTS params
(
	numberOfClients int,
	minWaitInterval int,
	maxWaitInterval int,
	worldStartTime int,
	worldEndTime int,
	maxJobs int
);

CREATE TABLE IF NOT EXISTS history
(
    clientID int,
    arrivalTime int,
    departureTime int,
    primary key(clientID,arrivalTime)
);
CREATE TABLE IF NOT EXISTS worldClock
(
    currentTime int
);

CREATE TABLE IF NOT EXISTS worldState
(
    clientID int,
	arrivalTime int,
    status int,
    clientWaitTime int
);

CREATE TABLE IF NOT EXISTS clients 
(
    clientID INT PRIMARY KEY

);
CREATE TABLE IF NOT EXISTS randomJobs
(
	noOfJobs int

);

CREATE OR REPLACE FUNCTION modd(no1 integer,no2 integer) returns integer as
$body$
begin
	return no1-(no2 * floor(no1/no2));
end;
$body$
language plpgsql;


/* trigger on params*/

CREATE OR REPLACE FUNCTION handleIsertParamsEvent() RETURNS TRIGGER  
AS $BODY$
BEGIN	
	INSERT INTO clients VALUES (1);
	INSERT INTO worldClock VALUES ((SELECT worldStartTime FROM params));
	INSERT INTO randomJobs VALUES (0);
	UPDATE worldClock SET currentTime=currentTime;
	RETURN NEW;
END;
$BODY$ 
LANGUAGE plpgsql;

CREATE TRIGGER insertParamsEvent 
	AFTER INSERT   ON params 
	FOR EACH ROW
	EXECUTE PROCEDURE handleIsertParamsEvent();

/* trigger on clients */
CREATE OR REPLACE FUNCTION eventInsertClient() RETURNS TRIGGER  
AS $BODY$
BEGIN 
	IF NEW.clientID < (SELECT max(numberOfClients) FROM params) THEN	
		INSERT INTO clients VALUES (NEW.clientID+1);
		
	END IF;
	RETURN NEW;
END;
$BODY$ 
LANGUAGE plpgsql;

CREATE TRIGGER insertClient AFTER INSERT ON clients 
	FOR EACH ROW
	EXECUTE PROCEDURE eventInsertClient();

CREATE OR REPLACE FUNCTION eventInsertClient1() RETURNS TRIGGER  
AS $BODY$
BEGIN 
	INSERT INTO worldState VALUES (NEW.clientID,-1,-1,-1);
	RETURN NEW;
END;
$BODY$ 
LANGUAGE plpgsql;

CREATE TRIGGER insertclient1 AFTER INSERT ON clients 
	FOR EACH ROW
	EXECUTE PROCEDURE eventInsertClient1();

/* trigger to handle events on worldClock*/

CREATE OR REPLACE FUNCTION eventWorldClockEvent() RETURNS TRIGGER  
AS $BODY$
BEGIN
		IF NEW.currentTime < (SELECT worldEndTime FROM params) THEN
			UPDATE worldState SET clientWaitTime=clientWaitTime-1 WHERE worldState.status <> -1;
			UPDATE randomJobs SET noOfJobs=mod(cast(random()*100000000 as integer),(SELECT MAX(maxJobs) FROM params));
			UPDATE worldClock SET currentTime=currentTime+1;
		END IF;
			RETURN NEW;
END;
$BODY$ 
LANGUAGE plpgsql;

CREATE TRIGGER worldClockEvent AFTER UPDATE ON worldClock 
	FOR EACH ROW
	EXECUTE PROCEDURE eventWorldClockEvent();


/* trigger to worldState*/
CREATE OR REPLACE FUNCTION eventworldStateEvent() RETURNS TRIGGER  
AS $BODY$
BEGIN 
	IF NEW.clientWaitTime=0 AND NEW.status=0 THEN
		INSERT INTO history VALUES (NEW.clientID,(SELECT MAX(currentTime) FROM  worldClock),-1);
	UPDATE worldState SET status=1 ,arrivalTime=(SELECT MAX(currentTime) FROM worldClock),
	clientWaitTime=(SELECT MAX(minWaitInterval) FROM params)+mod(cast(random()*10000000 as integer), (select max(maxWaitInterval)-max(minWaitInterval) FROM params))
	WHERE clientID=NEW.clientID;
	END IF;
	RETURN NEW;
END;
$BODY$ 
LANGUAGE plpgsql;

CREATE TRIGGER worldStateEvent AFTER UPDATE ON worldState
	FOR EACH ROW
	EXECUTE PROCEDURE eventworldStateEvent();

CREATE OR REPLACE FUNCTION eventWorldState() RETURNS TRIGGER  
AS $BODY$
BEGIN 
	IF NEW.clientWaitTime=0 AND NEW.status=1 THEN
		UPDATE history SET 
		departureTime=(SELECT MAX(currentTime) FROM worldClock) 
		WHERE clientID=NEW.clientID AND arrivalTime=NEW.arrivalTime;
		
		UPDATE worldState SET status=-1 
		WHERE clientID=NEW.clientID;
	END IF;
		RETURN NEW;
END;
$BODY$ 
LANGUAGE plpgsql;


CREATE TRIGGER WorldStateEvent1 AFTER UPDATE ON worldState
	FOR EACH ROW
	EXECUTE PROCEDURE eventWorldState();

/* trigger on randomJobs to create jobs*/

CREATE OR REPLACE FUNCTION eventCreateJobs() RETURNS TRIGGER  
AS $BODY$
BEGIN
	IF NEW.noOfJobs>0 THEN 
		UPDATE worldState SET status=0 ,
		clientWaitTime=(SELECT MAX(minWaitInterval) FROM params)+mod((cast(random()*10000000 as integer)), (select max(maxWaitInterval)-max(minWaitInterval) FROM params))
	   WHERE clientID=mod((cast(random()*10000000 as integer)),( SELECT max(numberOfClients) FROM params)) AND status=-1;
		
		UPDATE randomJobs SET noOfJobs=noOfJobs-1;
	END IF;
		RETURN NEW;
END;
$BODY$ 
LANGUAGE plpgsql;

CREATE TRIGGER createJobs AFTER UPDATE ON randomJobs
	FOR EACH ROW
	EXECUTE PROCEDURE eventCreateJobs();

INSERT INTO params VALUES (100,2,10,0,300,100);

