/**
 * EXPRESS Data Migration - teardown of the seeded Coastie-Ed training data
 * ------------------------------------------------------------------------
 * SCOPE: CreatedById AND the seed's own data shape. Both conditions, ANDed.
 *
 * Instructor recovery only. The supported path is still a fresh training org,
 * because the loader is insert-based and therefore one-shot per org.
 *
 * HOW TO USE
 *   1. Run as-is. MODE defaults to 'REPORT', which CHANGES NOTHING and prints
 *      what it would delete, per object, with the scope it used.
 *   2. Read every count. If one surprises you, STOP. Do not widen the scope to
 *      make a number look right.
 *   3. Set MODE = 'DELETE' and run again. Re-run until every count reports 0.
 *
 * WHY IT IS CHUNKED. Anonymous Apex caps DML at 10,000 rows per transaction and
 * cascade deletes count toward that cap. A full seed is 6,844 rows before
 * cascades, so one pass can exceed it. Each object is limited per run and the
 * script is designed to be run repeatedly until it reports nothing left.
 *
 * WHAT THIS SCRIPT WILL NOT DO. It will not delete a record the running user did
 * not create, and it will not delete a record that does not match the seed's
 * shape. If you need to remove somebody else's seed, set SCOPE_USER deliberately
 * and read the warning it prints.
 */

String MODE = 'REPORT';        // <-- 'REPORT' changes nothing. Set to 'DELETE' to purge.
Integer CHUNK = 2000;          // rows per object per run, well under the 10,000 DML cap

// Whose records. Defaults to the running user, which is who the seed loader ran as.
Id SCOPE_USER = UserInfo.getUserId();

// ---------------------------------------------------------------- helpers
Integer purge(String objectApi, String extraWhere, Boolean doDelete, Id scopeUser, Integer chunk) {
    if (!Schema.getGlobalDescribe().containsKey(objectApi.toLowerCase())) {
        return -1;                                   // object not present in this org
    }
    String soql = 'SELECT Id FROM ' + objectApi
                + ' WHERE CreatedById = :scopeUser'
                + (String.isBlank(extraWhere) ? '' : ' AND (' + extraWhere + ')')
                + ' LIMIT ' + chunk;
    List<SObject> rows;
    try {
        rows = Database.query(soql);
    } catch (Exception e) {
        System.debug('   ' + objectApi + ': QUERY FAILED, ' + e.getMessage());
        return -2;
    }
    if (doDelete && !rows.isEmpty()) {
        Integer failed = 0;
        String firstErr = '';
        for (Database.DeleteResult dr : Database.delete(rows, false)) {
            if (!dr.isSuccess()) {
                failed++;
                if (firstErr == '') { firstErr = dr.getErrors()[0].getMessage(); }
            }
        }
        if (failed > 0) {
            System.debug('   ' + objectApi + ': ' + failed + ' of ' + rows.size()
                       + ' row(s) FAILED to delete. First error: ' + firstErr);
        }
    }
    return rows.size();
}

// ------------------------------------------------------------------ setup
if (MODE != 'REPORT' && MODE != 'DELETE') {
    throw new System.NoAccessException();            // fail loudly on a typo'd MODE
}
Boolean doDelete = (MODE == 'DELETE');

User who = [SELECT Id, Name, Username FROM User WHERE Id = :SCOPE_USER LIMIT 1];

System.debug('=================================================================');
System.debug('EXPRESS teardown - MODE = ' + MODE + (doDelete ? '  *** THIS RUN DELETES ***' : '  (nothing will change)'));
System.debug('Org:   ' + UserInfo.getOrganizationId());
System.debug('Scope: CreatedById = ' + SCOPE_USER + '  (' + who.Name + ', ' + who.Username + ')');
if (SCOPE_USER != UserInfo.getUserId()) {
    System.debug('*** WARNING: SCOPE_USER is NOT the running user. You are about to act on');
    System.debug('*** records created by somebody else. Confirm that is what you intend.');
}
System.debug('Chunk: ' + CHUNK + ' rows per object per run');
System.debug('=================================================================');

// ------------------------------------------------ objects, child before parent
// Reverse FR-5 dependency order. Deleting a parent cascades to children, so the
// children are removed first to keep each statement's row count predictable and
// to keep the reported numbers meaningful.
List<List<String>> plan = new List<List<String>>{
    new List<String>{ 'Deliverable__c',          '' },
    new List<String>{ 'GiftTransaction',         'Name LIKE \'GTX-%\'' },
    new List<String>{ 'AccountContactRelation',  'IsDirect = false' },
    new List<String>{ 'Opportunity',             'Name LIKE \'FY2%Grant - %\' OR Name LIKE \'FY2%Major Gift - %\'' },
    new List<String>{ 'Lead',                    'Email LIKE \'%@example.net\'' },
    new List<String>{ 'Contact',                 'IsPersonAccount = false AND Email LIKE \'%.example.org\'' },
    new List<String>{ 'Account',                 'Website LIKE \'%.example.org\' OR PersonEmail LIKE \'%@example.org\'' }
};

Integer totalSeen = 0;
Boolean anyLeft = false;
System.debug('OBJECT                     MATCHED  NOTE');
for (List<String> step : plan) {
    Integer n = purge(step[0], step[1], doDelete, SCOPE_USER, CHUNK);
    String note = '';
    if (n == -1) {
        note = 'object not present in this org';
    } else if (n == -2) {
        note = 'query failed, see debug above';
    } else {
        totalSeen += n;
        if (n == CHUNK) { note = 'CHUNK FULL, more may remain, RE-RUN'; anyLeft = true; }
        else if (n > 0 && !doDelete) { note = 'would be deleted'; }
        else if (n > 0) { note = 'deleted'; }
    }
    System.debug(step[0].rightPad(26) + String.valueOf(n).leftPad(8) + '  ' + note);
}

System.debug('-----------------------------------------------------------------');
System.debug('Rows matched this run: ' + totalSeen);
if (!doDelete) {
    System.debug('MODE was REPORT. NOTHING WAS CHANGED. Set MODE = \'DELETE\' to purge.');
} else if (anyLeft || totalSeen > 0) {
    System.debug('RE-RUN THIS SCRIPT until every count reports 0. A chunk-full count means');
    System.debug('more rows remain; a zero everywhere means the teardown is complete.');
}
System.debug('*** VERIFY WITH scripts/census.apex, NOT WITH THIS SCRIPT\'S OWN OUTPUT. ***');
System.debug('A teardown that reports success is not evidence the org is clean, for the same');
System.debug('reason four Completed Apex jobs are not evidence the seed loaded (finding #46).');
System.debug('=================================================================');
