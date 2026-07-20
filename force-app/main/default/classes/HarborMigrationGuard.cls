/**
 * HarborMigrationGuard
 *
 * TIER-3 ENFORCEMENT (EXPRESS Data Migration training - "clean data isn't enough").
 *
 * Business invariant: a Gift Transaction may not post against a written-off
 * Opportunity, defined here as an Opportunity whose Amount is negative. A learner
 * who has cleansed every field of the SOURCE data will still hit this guard if they
 * migrate a payment linked to a negative pledge, because the violation is a property
 * of the parent relationship, not of data formatting.
 *
 * This is a NAMED, VISIBLE, BLOCKING guard by design. The learner is meant to hit it,
 * investigate it in Setup, understand the business rule it enforces, and make a real
 * migration decision: reconcile the reversal, or deactivate the guard for the load and
 * escalate to the dev team. It does legitimate validation work and announces itself
 * with a clear error - it is not a silent or resource-exhausting mechanism.
 *
 * Seed-safety: the sterile TARGET seed contains no negative-Amount Opportunities, so
 * this guard never fires during CoastieEdTrainingDataLoader.run(). It only engages on
 * the learner's later upsert of the defective SOURCE data.
 */
public with sharing class HarborMigrationGuard {

    @TestVisible
    private static final String ERROR_MESSAGE =
        'This Gift Transaction is linked to a written-off Opportunity (negative amount). '
        + 'A payment cannot post against a written-off pledge. Reconcile the reversal, or '
        + 'deactivate the HarborMigrationGuard automation for this migration and notify the '
        + 'admin team.';

    /**
     * Blocks any GiftTransaction whose parent Opportunity (via Source_Opportunity__c)
     * has a negative Amount. Records with no parent, or a non-negative parent, pass.
     *
     * @param newGifts the GiftTransaction records being inserted (Trigger.new)
     */
    public static void validateGifts(List<GiftTransaction> newGifts) {
        if (newGifts == null || newGifts.isEmpty()) {
            return;
        }

        // Collect the parent Opportunity Ids referenced by the incoming gifts.
        Set<Id> opportunityIds = new Set<Id>();
        for (GiftTransaction gift : newGifts) {
            if (gift.Source_Opportunity__c != null) {
                opportunityIds.add(gift.Source_Opportunity__c);
            }
        }

        if (opportunityIds.isEmpty()) {
            return;
        }

        // One SOQL for all parents; map Id -> Amount for O(1) lookup.
        Map<Id, Opportunity> opportunitiesById = new Map<Id, Opportunity>(
            [
                SELECT Id, Amount
                FROM Opportunity
                WHERE Id IN :opportunityIds
                WITH USER_MODE
            ]
        );

        for (GiftTransaction gift : newGifts) {
            if (gift.Source_Opportunity__c == null) {
                continue;
            }
            Opportunity parent = opportunitiesById.get(gift.Source_Opportunity__c);
            if (parent != null && parent.Amount != null && parent.Amount < 0) {
                gift.addError(ERROR_MESSAGE);
            }
        }
    }
}
