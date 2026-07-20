/**
 * HarborAccountEnrichmentTest
 *
 * Covers the Tier-3 HarborAccountEnrichment bypass gate and the active single-record
 * path. Self-contained (SeeAllData=false).
 *
 * NOTE ON THE ANTI-PATTERN: the "Too many SOQL queries: 101" behavior is the point of
 * this class in production, but asserting a governor LimitException at exactly 101 in a
 * unit test is brittle (query counts shift with other automation in the transaction).
 * So this test proves the LOGIC that matters - the bypass gate correctly enables and
 * disables the per-record work - and the live learner-simulation (bulk insert with
 * bypass off) is what proves the limit actually trips. Coverage here comes from the
 * bypass-off single/small-batch path exercising the loop.
 */
@isTest
private class HarborAccountEnrichmentTest {

    private static void setBypass(Boolean value) {
        Migration_Settings__c settings = Migration_Settings__c.getOrgDefaults();
        settings.Bypass_Automation__c = value;
        upsert settings;
    }

    @isTest
    static void bypassOn_skipsEnrichment_noQueries() {
        setBypass(true);

        Test.startTest();
        Integer queriesBefore = Limits.getQueries();
        HarborAccountEnrichment.enrich(new List<Account>{
            new Account(Name = 'Bypass Test Co')
        });
        Integer queriesAfter = Limits.getQueries();
        Test.stopTest();

        Assert.areEqual(queriesBefore, queriesAfter,
            'With bypass on, enrich() must run no SOQL (anti-pattern skipped).');
    }

    @isTest
    static void bypassOff_runsEnrichment_smallBatch() {
        setBypass(false);

        // Small batch stays well under the 100-query limit, so it runs cleanly while
        // still exercising the loop body (coverage of the active anti-pattern path).
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            accounts.add(new Account(Name = 'Active Test Co ' + i));
        }
        insert accounts;

        Test.startTest();
        HarborAccountEnrichment.enrich(accounts);
        Test.stopTest();

        // No assertion on side effects (the enrichment intentionally does nothing with
        // the query result); the test confirms the active path executes without error
        // at safe volume. The limit-tripping behavior is validated live, not here.
        Assert.isFalse(HarborAccountEnrichment.isBypassed(),
            'Bypass should be off for this scenario.');
    }

    @isTest
    static void nullAndEmptyInput_areSafe() {
        setBypass(false);

        Test.startTest();
        HarborAccountEnrichment.enrich(null);
        HarborAccountEnrichment.enrich(new List<Account>());
        Test.stopTest();

        // Reaching here without exception is the assertion; guard clauses handled it.
        Assert.isTrue(true, 'Null and empty inputs must not throw.');
    }

    @isTest
    static void bypassGate_reflectsSettingState() {
        setBypass(true);
        Assert.isTrue(HarborAccountEnrichment.isBypassed(),
            'isBypassed must be true when the setting is true.');

        setBypass(false);
        Assert.isFalse(HarborAccountEnrichment.isBypassed(),
            'isBypassed must be false when the setting is false.');
    }
}
