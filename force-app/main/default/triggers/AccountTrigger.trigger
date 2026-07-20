/**
 * AccountTrigger
 *
 * One trigger per object; delegates to handler classes (no logic in the trigger).
 *
 * TIER-3 enforcement: after insert, HarborAccountEnrichment runs an intentional
 * SOQL-in-loop performance anti-pattern (gated by the Migration_Settings__c bypass so
 * it does not fire during the seed load).
 */
trigger AccountTrigger on Account (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        HarborAccountEnrichment.enrich(Trigger.new);
    }
}
