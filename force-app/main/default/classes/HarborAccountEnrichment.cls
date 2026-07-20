/**
 * HarborAccountEnrichment
 *
 * TIER-3 ENFORCEMENT (EXPRESS Data Migration training - "clean data isn't enough").
 *
 * This handler contains a DELIBERATE performance anti-pattern: a SOQL query inside a
 * loop (one query per Account). It performs fine on small inserts but trips the
 * "Too many SOQL queries: 101" governor limit when a learner bulk-upserts the SOURCE
 * accounts (>100 in a transaction). The learner is meant to hit this at load time,
 * diagnose that an AUTOMATION - not their data - is the bottleneck, find this named
 * class in Setup, recognize the SOQL-in-loop anti-pattern, and decide to deactivate it
 * for the bulk load or flag it for refactor.
 *
 * This is a REALISTIC, DIAGNOSABLE anti-pattern (the single most common real-world
 * migration speed bump), not a rigged failure. The governor-limit error is clear and
 * points a competent investigator straight at the cause.
 *
 * SEED-SAFETY: the seed loader (CoastieEdTrainingDataLoader) sets
 * Migration_Settings__c.Bypass_Automation__c = true for the duration of the load, so
 * this anti-pattern does NOT fire during the seed's 1,200-account load (which would
 * otherwise trip the same limit and break the baseline). The loader resets the flag to
 * false on completion, leaving the automation active for the learner's later upsert.
 *
 * WARNING TO MAINTAINERS: the SOQL-in-loop below is intentional training content. Do
 * not "fix" it by bulkifying - that would remove the lesson. It is gated by the bypass
 * so it never harms the seed.
 */
public with sharing class HarborAccountEnrichment {

    /**
     * Runs the (intentional) per-record enrichment lookup unless automation is bypassed.
     *
     * @param newAccounts the Account records just inserted (Trigger.new)
     */
    public static void enrich(List<Account> newAccounts) {
        if (newAccounts == null || newAccounts.isEmpty()) {
            return;
        }

        // BYPASS GATE: skip entirely during seed/data loads.
        if (isBypassed()) {
            return;
        }

        // INTENTIONAL ANTI-PATTERN: SOQL inside a loop. One query per Account.
        // At >100 accounts in a single transaction this trips
        // "System.LimitException: Too many SOQL queries: 101".
        for (Account acc : newAccounts) {
            List<Account> possibleMatches = [
                SELECT Id
                FROM Account
                WHERE Name = :acc.Name
                AND Id != :acc.Id
                WITH USER_MODE
            ];
            // The query itself is the anti-pattern; the result is not used further.
            // (A real inefficient enrichment routine would process possibleMatches here.)
        }
    }

    /**
     * @return true when Migration_Settings__c.Bypass_Automation__c is set for the
     *         running context (org default / user hierarchy), false otherwise.
     */
    @TestVisible
    private static Boolean isBypassed() {
        Migration_Settings__c settings = Migration_Settings__c.getInstance();
        return settings != null && settings.Bypass_Automation__c == true;
    }
}
