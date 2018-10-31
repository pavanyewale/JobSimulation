DROP TABLE IF  EXISTS params;
DROP TABLE IF  EXISTS history;
DROP TABLE IF  EXISTS worldClock;
DROP TABLE IF  EXISTS worldState;
DROP TABLE IF  EXISTS clients;
DROP TABLE IF  EXISTS randomJobs;
PRAGMA recursive_triggers = ON;
CREATE TABLE IF NOT exists params
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
	arrivalTime,
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

/* trigger on params*/

CREATE TRIGGER IF NOT EXISTS insertParamsEvent AFTER INSERT   ON params 
BEGIN
	INSERT INTO clients VALUES (1);
	INSERT INTO worldClock VALUES ((SELECT worldStartTime FROM params));
	INSERT INTO randomJobs VALUES (0);
	UPDATE worldClock SET currentTime=currentTime;
END;

/* trigger on clients */
CREATE TRIGGER IF NOT EXISTS insertClient AFTER INSERT ON clients 
WHEN NEW.clientID < (SELECT max(numberOfClients) FROM params)
BEGIN 
	INSERT INTO clients VALUES (NEW.clientID+1);
END;


CREATE TRIGGER IF  NOT EXISTS insertclient1 AFTER INSERT ON clients 
BEGIN 
	INSERT INTO worldState VALUES (NEW.clientID,-1,-1,-1);
END;

/* trigger to handle events on worldClock*/
CREATE TRIGGER IF NOT EXISTS worldClockEvent AFTER UPDATE ON worldClock 
WHEN 
		NEW.currentTime < (SELECT worldEndTime FROM params)
BEGIN
		UPDATE worldState SET clientWaitTime=clientWaitTime-1 WHERE worldState.status <> -1;
		UPDATE randomJobs SET noOfJobs=(ABS(random())%(SELECT MAX(maxJobs) FROM params));
		UPDATE worldClock SET currentTime=currentTime+1;
END;


/* trigger to worldState*/
CREATE TRIGGER IF NOT EXISTS worldStateEvent AFTER UPDATE ON worldState
WHEN 
		NEW.clientWaitTime=0 AND NEW.status=0
BEGIN 
		INSERT INTO history VALUES (NEW.clientID,(SELECT MAX(currentTime) FROM  worldClock),-1);
		UPDATE worldState 
		SET 
		status=1 ,
		arrivalTime=(SELECT MAX(currentTime) FROM worldClock),
		clientWaitTime=(SELECT MAX(minWaitInterval) FROM params)+(ABS(random())% (select max(maxWaitInterval)-max(minWaitInterval) FROM params)) 
		WHERE clientID=NEW.clientID;
END;

CREATE TRIGGER IF NOT EXISTS AFTER UPDATE ON worldState
WHEN 
		NEW.clientWaitTime=0 AND NEW.status=1
BEGIN 
		UPDATE history 
		SET  
		departureTime=(SELECT MAX(currentTime) FROM worldClock) 
		WHERE clientID=NEW.clientID AND arrivalTime=NEW.arrivalTime;
		UPDATE worldState 
		SET status=-1 
		WHERE clientID=NEW.clientID;
END;
/* trigger on randomJobs to create jobs*/
CREATE TRIGGER IF NOT EXISTS createJobs AFTER UPDATE ON randomJobs
WHEN NEW.noOfJobs>0
BEGIN
		UPDATE worldState 
		SET 
		status=0 ,
		clientWaitTime=(SELECT MAX(minWaitInterval) FROM params)+(ABS(random())% (select max(maxWaitInterval)-max(minWaitInterval) FROM params)) 
	   WHERE clientID=ABS(random())%( SELECT max(numberOfClients) FROM params) AND status=-1;
		
		UPDATE randomJobs
		SET 
		noOfJobs=noOfJobs-1;
END;
INSERT INTO params VALUES (300,2,10,0,300,100);

