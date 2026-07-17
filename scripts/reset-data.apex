// BEST-EFFORT purge of seeded Coastie-Ed training data, matched by data patterns.
// Instructor recovery only; the supported path is a fresh training org.
delete [SELECT Id FROM Deliverable__c];
delete Database.query('SELECT Id FROM GiftTransaction WHERE Name LIKE \'GTX-%\'');
delete [SELECT Id FROM Opportunity WHERE Name LIKE 'FY2%Grant - %' OR Name LIKE 'FY2%Major Gift - %'];
delete [SELECT Id FROM Lead WHERE Email LIKE '%@example.net'];
delete [SELECT Id FROM Contact WHERE Email LIKE '%.example.org' AND IsPersonAccount = false];
delete [SELECT Id FROM Account WHERE Website LIKE '%.example.org' OR PersonEmail LIKE '%@example.org'];
