@isTest
private class CoastieEdTrainingDataLoaderTest {

    private static Map<String, Map<String, Id>> emptyMaps() {
        return new Map<String, Map<String, Id>>();
    }

    @isTest
    static void testInsertBuildsKeyMap() {
        String csv = '#Key,Name,Type\n'
            + 'TEST-ACC-00001,Test Harbor Org,Corporation\n'
            + 'TEST-ACC-00002,Test Bay Org,Foundation';
        Test.startTest();
        CoastieEdTrainingDataLoader.StepResult r =
            CoastieEdTrainingDataLoader.insertFromCsv('Account', csv, emptyMaps());
        Test.stopTest();
        System.assert(r.message.contains('success=2'), 'Unexpected: ' + r.message);
        System.assertEquals(2, r.keys.size());
        System.assertNotEquals(null, r.keys.get('TEST-ACC-00001'));
        System.assertEquals(2, [SELECT COUNT() FROM Account WHERE Name LIKE 'Test%Org']);
    }

    @isTest
    static void testRefColumnResolvesParent() {
        Account parent = new Account(Name = 'Parent Co');
        insert parent;
        Map<String, Map<String, Id>> maps = emptyMaps();
        maps.put('Account', new Map<String, Id>{ 'K1' => parent.Id });
        String csv = '#Key,LastName,Ref:AccountId:Account\nC1,Tester,K1';
        Test.startTest();
        CoastieEdTrainingDataLoader.StepResult r =
            CoastieEdTrainingDataLoader.insertFromCsv('Contact', csv, maps);
        Test.stopTest();
        System.assert(r.message.contains('success=1'), 'Unexpected: ' + r.message);
        Contact c = [SELECT AccountId FROM Contact WHERE LastName = 'Tester'];
        System.assertEquals(parent.Id, c.AccountId);
    }

    @isTest
    static void testMissingParentRowIsSkipped() {
        String csv = '#Key,LastName,Ref:AccountId:Account\nC1,Orphan,NO-SUCH-KEY';
        Test.startTest();
        CoastieEdTrainingDataLoader.StepResult r =
            CoastieEdTrainingDataLoader.insertFromCsv('Contact', csv, emptyMaps());
        Test.stopTest();
        System.assert(r.message.contains('skippedMissingParent=1'), 'Unexpected: ' + r.message);
        System.assertEquals(0, [SELECT COUNT() FROM Contact WHERE LastName = 'Orphan']);
    }

    @isTest
    static void testDateAndCurrencyCoercion() {
        Account parent = new Account(Name = 'Opp Parent');
        insert parent;
        Map<String, Map<String, Id>> maps = emptyMaps();
        maps.put('Account', new Map<String, Id>{ 'K1' => parent.Id });
        String csv = '#Key,Name,StageName,Amount,CloseDate,Ref:AccountId:Account\n'
            + 'O1,Test Grant,Closed Won,15000.50,2024-06-30,K1';
        Test.startTest();
        CoastieEdTrainingDataLoader.StepResult r =
            CoastieEdTrainingDataLoader.insertFromCsv('Opportunity', csv, maps);
        Test.stopTest();
        System.assert(r.message.contains('success=1'), 'Unexpected: ' + r.message);
        Opportunity o = [SELECT Amount, CloseDate FROM Opportunity WHERE Name = 'Test Grant'];
        System.assertEquals(15000.50, o.Amount);
        System.assertEquals(Date.newInstance(2024, 6, 30), o.CloseDate);
    }

    @isTest
    static void testUnknownObjectIsSkippedGracefully() {
        CoastieEdTrainingDataLoader.StepResult r =
            CoastieEdTrainingDataLoader.insertFromCsv('No_Such_Object__x9', '#Key,A\n1,x', emptyMaps());
        System.assert(r.message.contains('SKIPPED'), 'Unexpected: ' + r.message);
    }

    @isTest
    static void testPrecheckReportsMissingSetup() {
        // Standard test contexts have no Person Account record type, so precheck
        // must return a setup message rather than null.
        String problem = CoastieEdTrainingDataLoader.precheck();
        System.assertNotEquals(null, problem);
        System.assert(problem.contains('SETUP INCOMPLETE'), problem);
    }

    @isTest
    static void testStepConfiguration() {
        System.assertEquals(7, CoastieEdTrainingDataLoader.steps().size());
    }
}
