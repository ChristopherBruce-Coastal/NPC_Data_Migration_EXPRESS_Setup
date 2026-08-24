// EXPRESS seed census. Anonymous Apex: paste whole file, Execute. See README step 10.
// Logs at ERROR level so a default trace flag cannot filter it out. |ERROR| is not a failure.
// Pass 1: MODE='BEFORE'. Copy the one-line BEFORE= string it prints.
// Pass 2: paste that into BEFORE below, set MODE='AFTER', run again.
String MODE = 'BEFORE';
String BEFORE = '';

List<String> K = new List<String>{'Account','Acct.Person','Acct.Business','Contact','Lead',
    'Opportunity','GiftTransaction','Deliverable__c','ACR.indirect','Campaign'};
// ACR MUST be IsDirect=false. The absolute total moves 1200, not 400.
List<Integer> EXP = new List<Integer>{1200,900,300,1700,500,1700,1744,500,400,0};
List<String> Q = new List<String>{
    'SELECT COUNT() FROM Account', '', '',
    'SELECT COUNT() FROM Contact',
    'SELECT COUNT() FROM Lead',
    'SELECT COUNT() FROM Opportunity',
    'SELECT COUNT() FROM GiftTransaction',
    'SELECT COUNT() FROM Deliverable__c',
    'SELECT COUNT() FROM AccountContactRelation WHERE IsDirect = false',
    'SELECT COUNT() FROM Campaign'};

List<Integer> NOW = new List<Integer>();
for (Integer i = 0; i < K.size(); i++) {
    if (Q[i] == '') { NOW.add(0); continue; }
    try { NOW.add(Database.countQuery(Q[i])); } catch (Exception e) { NOW.add(-1); }
}
// Record types by IsPersonType, never a hardcoded Id.
for (RecordType r : [SELECT Id, IsPersonType FROM RecordType
                     WHERE SObjectType='Account' AND IsActive=true]) {
    try {
        Integer c = Database.countQuery('SELECT COUNT() FROM Account WHERE RecordTypeId=\'' + r.Id + '\'');
        Integer x = r.IsPersonType ? 1 : 2;
        NOW[x] = NOW[x] + c;
    } catch (Exception e) {}
}

if (MODE == 'BEFORE') {
    List<String> v = new List<String>();
    for (Integer n : NOW) { v.add(String.valueOf(n < 0 ? 0 : n)); }
    System.debug(LoggingLevel.ERROR, 'COPY THIS LINE:\nString BEFORE = \''
        + String.join(v, ',') + '\';');
    if (NOW[9] > 0) {
        System.debug(LoggingLevel.ERROR, 'NOTE Campaign=' + NOW[9]
            + ' so exercise #48 (OutreachSourceCode/UsageType) will NOT reproduce here.');
    }
    if (NOW[0] > 100) {
        System.debug(LoggingLevel.ERROR,
            'NOTE org already holds records. Absolute counts prove nothing. Deltas only.');
    }
} else {
    // Validate the pasted baseline before using it, so a missed paste says so plainly
    // instead of throwing "Invalid integer:" from twenty lines further down.
    if (String.isBlank(BEFORE)) {
        System.debug(LoggingLevel.ERROR, 'STOP: MODE is AFTER but BEFORE is still empty. '
            + 'Paste the "String BEFORE = ...;" line printed by the BEFORE pass over line 6, '
            + 'then run again. If you no longer have it, the baseline is gone and this org '
            + 'cannot be verified by delta. Use a fresh org.');
        return;
    }
    List<String> b = BEFORE.split(',');
    if (b.size() != K.size()) {
        System.debug(LoggingLevel.ERROR, 'STOP: BEFORE has ' + b.size() + ' values, expected '
            + K.size() + '. Copy the whole line the BEFORE pass printed, commas included.');
        return;
    }
    Boolean ok = true;
    System.debug(LoggingLevel.ERROR, 'OBJECT / BEFORE / AFTER / DELTA / EXPECTED / RESULT');
    for (Integer i = 0; i < K.size(); i++) {
        Integer bv = Integer.valueOf(b[i].trim());
        Integer d = NOW[i] - bv;
        String res;
        if (NOW[i] < 0) { res = 'N/A not reachable'; }
        else if (d == EXP[i]) { res = 'PASS'; }
        else { res = 'FAIL off by ' + (d - EXP[i]); ok = false; }
        System.debug(LoggingLevel.ERROR, K[i] + ' / ' + bv + ' / ' + NOW[i] + ' / ' + d
            + ' / ' + EXP[i] + ' / ' + res);
    }
    System.debug(LoggingLevel.ERROR, ok ? 'ALL DELTAS MATCH. Seed verified.'
        : 'DELTAS WRONG. Four Completed Apex jobs is NOT proof of success.');
    System.debug(LoggingLevel.ERROR,
        'GiftTransaction short by 436 means the seed CSV still carries PaymentMethod=Wire (#61).');
}
