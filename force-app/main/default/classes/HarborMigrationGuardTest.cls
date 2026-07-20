/**
 * HarborMigrationGuardTest
 *
 * Coverage for the Tier-3 HarborMigrationGuard: a GiftTransaction linked to a
 * negative-Amount Opportunity is blocked; gifts with a non-negative or absent parent
 * pass. Self-contained (SeeAllData=false); creates its own Opportunities and does not
 * depend on the training seed.
 *
 * NOTE ON REQUIRED FIELDS: GiftTransaction has standard required fields that vary by
 * org configuration (e.g. OriginalAmount, TransactionDate). The helper populates the
 * commonly-required ones; if this org requires additional fields, add them in
 * buildGift() so the tests exercise the guard rather than failing on missing fields.
 */
@isTest
private class HarborMigrationGuardTest {

    private static Opportunity makeOpp(Decimal amount) {
        return new Opportunity(
            Name = 'TEST Opp ' + (amount == null ? 'null' : String.valueOf(amount)),
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            Amount = amount
        );
    }

    private static GiftTransaction buildGift(Id oppId) {
        return new GiftTransaction(
            Source_Opportunity__c = oppId,
            OriginalAmount = 100,
            TransactionDate = Date.today(),
            Status = 'Paid',
            PaymentMethod = 'Check'
        );
    }

    @isTest
    static void giftAgainstNegativeOpportunity_isBlocked() {
        Opportunity negativeOpp = makeOpp(-500);
        insert negativeOpp;

        GiftTransaction gift = buildGift(negativeOpp.Id);

        Test.startTest();
        Database.SaveResult result = Database.insert(gift, false);
        Test.stopTest();

        Assert.isFalse(result.isSuccess(),
            'Gift linked to a negative-Amount Opportunity should be blocked.');
        Boolean foundExpectedError = false;
        for (Database.Error err : result.getErrors()) {
            if (err.getMessage().contains('written-off')) {
                foundExpectedError = true;
            }
        }
        Assert.isTrue(foundExpectedError,
            'Block error should reference the written-off pledge rule. Got: '
            + result.getErrors());
    }

    @isTest
    static void giftAgainstPositiveOpportunity_isAllowed() {
        Opportunity positiveOpp = makeOpp(1000);
        insert positiveOpp;

        GiftTransaction gift = buildGift(positiveOpp.Id);

        Test.startTest();
        Database.SaveResult result = Database.insert(gift, false);
        Test.stopTest();

        Assert.isTrue(result.isSuccess(),
            'Gift linked to a positive-Amount Opportunity should be allowed. Errors: '
            + result.getErrors());
    }

    @isTest
    static void giftWithNoParentOpportunity_isNotBlockedByGuard() {
        // The guard only blocks negative-parent gifts. A null parent is not the guard's
        // concern (the F1 validation rule handles required-parent enforcement separately).
        // Here we confirm the guard itself does not add its written-off error.
        GiftTransaction gift = buildGift(null);

        Test.startTest();
        Database.SaveResult result = Database.insert(gift, false);
        Test.stopTest();

        for (Database.Error err : (result.isSuccess()
                ? new List<Database.Error>()
                : result.getErrors())) {
            Assert.isFalse(err.getMessage().contains('written-off'),
                'Guard must not raise the written-off error for a null-parent gift.');
        }
    }

    @isTest
    static void bulkMix_blocksOnlyNegativeParents() {
        // 300 opps: even index positive, odd index negative. Crosses the 200-record
        // trigger batch boundary and confirms per-record blocking is correct in bulk.
        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 300; i++) {
            opps.add(makeOpp(Math.mod(i, 2) == 0 ? 1000 : -1000));
        }
        insert opps;

        List<GiftTransaction> gifts = new List<GiftTransaction>();
        for (Opportunity opp : opps) {
            gifts.add(buildGift(opp.Id));
        }

        Test.startTest();
        List<Database.SaveResult> results = Database.insert(gifts, false);
        Test.stopTest();

        Integer blocked = 0;
        Integer allowed = 0;
        for (Database.SaveResult result : results) {
            if (result.isSuccess()) {
                allowed++;
            } else {
                blocked++;
            }
        }
        Assert.areEqual(150, blocked,
            'Exactly the 150 negative-parent gifts should be blocked.');
        Assert.areEqual(150, allowed,
            'Exactly the 150 positive-parent gifts should be allowed.');
    }
}
