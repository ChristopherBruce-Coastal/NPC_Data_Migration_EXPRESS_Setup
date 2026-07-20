/**
 * GiftTransactionTrigger
 *
 * One trigger per object. Delegates all logic to handler classes; contains no
 * business logic itself (per Apex trigger best practice).
 *
 * TIER-3 enforcement: before insert, HarborMigrationGuard blocks any GiftTransaction
 * linked to a written-off (negative-amount) Opportunity.
 */
trigger GiftTransactionTrigger on GiftTransaction (before insert) {
    if (Trigger.isBefore && Trigger.isInsert) {
        HarborMigrationGuard.validateGifts(Trigger.new);
    }
}
