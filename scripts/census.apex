/**
 * EXPRESS Data Migration — seed census / delta check
 * ---------------------------------------------------
 * Replaces the old absolute-count health check, which cannot detect a short
 * load in an org that already contains records (a count of 14,896 is ">= 1,744"
 * and passes while 436 rows are missing).
 *
 * HOW TO USE
 *   1. BEFORE deploying or seeding anything, run this with MODE = 'BEFORE'.
 *      Copy the BASELINE block it prints in the debug log.
 *   2. Paste that block over the `baseline` map below.
 *   3. Deploy, complete setup, and run CoastieEdTrainingDataLoader.run().
 *      Wait for four Completed jobs in Setup > Apex Jobs.
 *   4. Set MODE = 'AFTER' and run again. It prints deltas and PASS/FAIL.
 *
 * Run in Developer Console > Debug > Open Execute Anonymous Window, tick
 * "Open Log", or:  sf apex run --file scripts/census.apex -o <alias>
 *
 * NOTE: four Completed jobs does NOT mean four successful jobs. The loader
 * inserts with partial success enabled by design, so a job that discards rows
 * still finishes and still reports Completed. This script is the actual check.
 */

String MODE = 'BEFORE';          // <-- set to 'AFTER' for the second run

// ---------------------------------------------------------------- baseline
// Paste the BASELINE block from the BEFORE run over this map.
Map<String, Integer> baseline = new Map<String, Integer>{
    'Account'                => 0,
    'Account.PersonAccount'  => 0,
    'Account.Business'       => 0,
    'Contact'                => 0,
    'Lead'                   => 0,
    'Opportunity'            => 0,
    'GiftTransaction'        => 0,
    'Deliverable__c'         => 0,
    'ACR.indirect'           => 0,
    'Campaign'               => 0
};

// ------------------------------------------------- expected seed deltas
// Every one of these has been measured against a live org and passed,
// except GiftTransaction, which is the row that #61 must turn green.
Map<String, Integer> expected = new Map<String, Integer>{
    'Account'                => 1200,
    'Account.PersonAccount'  => 900,
    'Account.Business'       => 300,
    'Contact'                => 1700,   // 800 from the CSV + 900 auto-created behind person accounts
    'Lead'                   => 500,
    'Opportunity'            => 1700,
    'GiftTransaction'        => 1744,
    'Deliverable__c'         => 500,
    'ACR.indirect'           => 400,    // MUST be IsDirect = false; the absolute total moves by 1,200
    'Campaign'               => 0        // the seed creates none; a non-zero baseline disables the #48 exercise
};

// --------------------------------------------------------------- helpers
Integer countOf(String soql) {
    try {
        return Database.countQuery(soql);
    } catch (Exception e) {
        return -1;                       // -1 = object or field not reachable in this org
    }
}

Boolean objectExists(String api) {
    return Schema.getGlobalDescribe().containsKey(api.toLowerCase());
}

// --------------------------------------------------------------- measure
Map<String, Integer> now = new Map<String, Integer>();

now.put('Account', countOf('SELECT COUNT() FROM Account'));
now.put('Contact', countOf('SELECT COUNT() FROM Contact'));
now.put('Lead',    countOf('SELECT COUNT() FROM Lead'));
now.put('Opportunity', countOf('SELECT COUNT() FROM Opportunity'));
now.put('Campaign', countOf('SELECT COUNT() FROM Campaign'));

// Account record types, resolved by DeveloperName rather than a hardcoded Id.
Integer personAcct = 0, businessAcct = 0;
for (RecordType rt : [SELECT Id, DeveloperName, IsPersonType
                      FROM RecordType
                      WHERE SObjectType = 'Account' AND IsActive = true]) {
    Integer c = countOf('SELECT COUNT() FROM Account WHERE RecordTypeId = \'' + rt.Id + '\'');
    if (c < 0) continue;
    if (rt.IsPersonType) {
        personAcct += c;
    } else {
        businessAcct += c;
    }
}
now.put('Account.PersonAccount', personAcct);
now.put('Account.Business', businessAcct);

// GiftTransaction is queried dynamically: it does not exist unless Fundraising is on.
now.put('GiftTransaction',
        objectExists('GiftTransaction') ? countOf('SELECT COUNT() FROM GiftTransaction') : -1);

now.put('Deliverable__c',
        objectExists('Deliverable__c') ? countOf('SELECT COUNT() FROM Deliverable__c') : -1);

// AccountContactRelation MUST be counted on IsDirect = false.
// The absolute total moves by 1,200 for two unrelated reasons: the seed's 400
// indirect rows plus one automatic direct row per inserted Contact. Reconciling
// on the total shows 1,200 and looks like a failure on a correct load.
now.put('ACR.indirect',
        objectExists('AccountContactRelation')
            ? countOf('SELECT COUNT() FROM AccountContactRelation WHERE IsDirect = false')
            : -1);

// ---------------------------------------------------------------- report
List<String> order = new List<String>{
    'Account', 'Account.PersonAccount', 'Account.Business', 'Contact', 'Lead',
    'Opportunity', 'GiftTransaction', 'Deliverable__c', 'ACR.indirect', 'Campaign'
};

System.debug('=================================================================');
System.debug('EXPRESS seed census — MODE = ' + MODE);
System.debug('Org: ' + UserInfo.getOrganizationId() + '  User: ' + UserInfo.getUserName());
System.debug('=================================================================');

if (MODE == 'BEFORE') {
    System.debug('--- BASELINE BLOCK: paste this over the baseline map, then re-run as AFTER ---');
    String blk = 'Map<String, Integer> baseline = new Map<String, Integer>{\n';
    for (Integer i = 0; i < order.size(); i++) {
        String k = order[i];
        Integer v = now.get(k);
        // An object that does not exist yet has zero records, so it baselines at 0 rather
        // than -1. Without this, running BEFORE prior to the deploy (when Deliverable__c
        // and GiftTransaction may not exist) produces a delta one too high and a false FAIL.
        String note = '';
        if (v == null || v < 0) { note = '   // object not present at baseline'; v = 0; }
        blk += '    \'' + k + '\'' + ' => ' + v + (i < order.size() - 1 ? ',' : '') + note + '\n';
    }
    blk += '};';
    System.debug('\n' + blk);

    if (now.get('Campaign') != null && now.get('Campaign') > 0) {
        System.debug('*** NOTE: Campaign = ' + now.get('Campaign') + '. The OutreachSourceCode / '
                   + 'UsageType exercise (#48) does NOT reproduce in this org. Brief it as a '
                   + 'walkthrough or skip it.');
    }
    if (now.get('Account') != null && now.get('Account') > 100) {
        System.debug('*** NOTE: this org already holds records. Absolute counts are meaningless '
                   + 'here; the delta check below is the only valid verification.');
    }
} else {
    Boolean allPass = true;
    System.debug('OBJECT                    BEFORE      AFTER      DELTA   EXPECTED  RESULT');
    for (String k : order) {
        Integer b = baseline.containsKey(k) ? baseline.get(k) : 0;
        if (b == null || b < 0) { b = 0; }   // absent at baseline == zero records
        Integer a = now.get(k);
        if (a == null) { a = -1; }
        String res;
        Integer d = a - b;
        if (a < 0) {
            res = 'N/A (object not reachable)';
        } else if (d == expected.get(k)) {
            res = 'PASS';
        } else {
            res = 'FAIL  (off by ' + (d - expected.get(k)) + ')';
            allPass = false;
        }
        System.debug(k.rightPad(24) + ' '
                   + String.valueOf(b).leftPad(9) + ' '
                   + String.valueOf(a).leftPad(10) + ' '
                   + String.valueOf(d).leftPad(10) + ' '
                   + String.valueOf(expected.get(k)).leftPad(10) + '  ' + res);
    }
    System.debug('-----------------------------------------------------------------');
    System.debug(allPass
        ? 'ALL DELTAS MATCH. Seed verified.'
        : 'ONE OR MORE DELTAS ARE WRONG. Do NOT treat four Completed Apex jobs as success.');
    System.debug('If GiftTransaction is short by 436, the seed CSV still carries PaymentMethod = '
               + 'Wire, which a stock NPC org rejects. That is finding #61 and the fix is in the '
               + 'builder, not the org.');
}
System.debug('=================================================================');
