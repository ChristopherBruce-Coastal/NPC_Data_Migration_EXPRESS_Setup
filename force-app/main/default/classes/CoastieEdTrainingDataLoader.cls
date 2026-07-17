/**
 * CoastieEdTrainingDataLoader (learner edition)
 * Seeds the SYNTHETIC Coastie-Ed TARGET dataset (EXPRESS Data Migration training)
 * from CSV static resources into the learner's NPC training org, in FR-5 order.
 *
 * Usage (anonymous Apex): CoastieEdTrainingDataLoader.run();
 *
 * Design notes:
 * - NO external ID fields are used or persisted. CSV rows carry a '#Key' column;
 *   the loader maps keys to inserted record Ids in memory and resolves
 *   'Ref:<LookupField>:<ParentObject>' columns from those maps. After the seed,
 *   the org contains no migration scaffolding.
 * - Prechecks: Person Account record type must exist (NPC org with Person
 *   Accounts), a Business Account record type must exist (learners create this
 *   during setup), and the org must not already be seeded. run() throws with a
 *   clear message if any precheck fails.
 * - Insert-based and therefore one-shot per org. To reseed, use a fresh
 *   training org (or scripts/reset-data.apex, best effort).
 * - Fully dynamic (no compile-time reference to GiftTransaction), so the class
 *   compiles in any org; missing objects are reported as SKIPPED.
 */
public with sharing class CoastieEdTrainingDataLoader implements Queueable {

    public class LoaderException extends Exception {}

    public class Step {
        public String objectApi;
        public String resourceName;
        public Boolean buildKeyMap;
        public Step(String objectApi, String resourceName, Boolean buildKeyMap) {
            this.objectApi = objectApi;
            this.resourceName = resourceName;
            this.buildKeyMap = buildKeyMap;
        }
    }

    @TestVisible
    private static List<Step> steps() {
        return new List<Step>{
            new Step('Account',                'CE_Account',         true),
            new Step('Contact',                'CE_Contact',         true),
            new Step('AccountContactRelation', 'CE_ACR',             false),
            new Step('Lead',                   'CE_Lead',            false),
            new Step('Opportunity',            'CE_Opportunity',     true),
            new Step('GiftTransaction',        'CE_GiftTransaction', false),
            new Step('Deliverable__c',         'CE_Deliverable',     false)
        };
    }

    public class StepResult {
        public String message;
        public Map<String, Id> keys = new Map<String, Id>();
    }

    private Integer stepIndex;
    private String summary;
    private Map<String, Map<String, Id>> keyMaps;

    public CoastieEdTrainingDataLoader(Integer stepIndex, String summary, Map<String, Map<String, Id>> keyMaps) {
        this.stepIndex = stepIndex;
        this.summary = summary;
        this.keyMaps = keyMaps;
    }

    /** Entry point. Validates prerequisites, then enqueues the first load step. */
    public static Id run() {
        String problem = precheck();
        if (problem != null) {
            throw new LoaderException(problem);
        }
        return System.enqueueJob(new CoastieEdTrainingDataLoader(0, '', new Map<String, Map<String, Id>>()));
    }

    /** Returns null when the org is ready to seed, otherwise a learner-facing message. */
    @TestVisible
    private static String precheck() {
        if (personAccountRecordTypeId() == null) {
            return 'SETUP INCOMPLETE: No Person Account record type found. This loader requires a '
                + 'Nonprofit Cloud org with Person Accounts enabled. Complete the org setup steps first.';
        }
        if (businessAccountRecordTypeId() == null) {
            return 'SETUP INCOMPLETE: No active "Business Account" record type found on Account. '
                + 'Create an Account record type labeled exactly "Business Account" (per the setup guide), '
                + 'activate it, then re-run the loader.';
        }
        Integer seeded = [SELECT COUNT() FROM Account WHERE Website LIKE '%.example.org'];
        if (seeded > 0) {
            return 'ALREADY SEEDED: This org already contains Coastie-Ed training accounts (' + seeded
                + ' found). The seed runs once per org. Use a fresh training org to reseed.';
        }
        return null;
    }

    @TestVisible
    private static Id personAccountRecordTypeId() {
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Account' AND IsPersonType = true AND IsActive = true
            LIMIT 1
        ];
        return rts.isEmpty() ? null : rts[0].Id;
    }

    @TestVisible
    private static Id businessAccountRecordTypeId() {
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Account' AND IsPersonType = false AND IsActive = true
            AND (DeveloperName = 'Business_Account' OR Name = 'Business Account')
            LIMIT 1
        ];
        return rts.isEmpty() ? null : rts[0].Id;
    }

    public void execute(QueueableContext ctx) {
        Step s = steps()[stepIndex];
        StepResult result;
        try {
            result = loadStep(s, keyMaps);
        } catch (Exception e) {
            result = new StepResult();
            result.message = s.objectApi + ': FAILED - ' + e.getMessage();
        }
        summary += result.message + '\n';
        System.debug(LoggingLevel.INFO, result.message);

        if (s.buildKeyMap) {
            keyMaps.put(s.objectApi, result.keys);
        }
        // Free maps that no later step references, to keep queueable state small.
        if (s.objectApi == 'AccountContactRelation') {
            keyMaps.remove('Contact');
        }
        if (s.objectApi == 'GiftTransaction') {
            keyMaps.remove('Account');
        }

        if (stepIndex + 1 < steps().size()) {
            System.enqueueJob(new CoastieEdTrainingDataLoader(stepIndex + 1, summary, keyMaps));
        } else {
            finish(summary);
        }
    }

    @TestVisible
    private static StepResult loadStep(Step s, Map<String, Map<String, Id>> keyMaps) {
        List<StaticResource> srs = [SELECT Body FROM StaticResource WHERE Name = :s.resourceName LIMIT 1];
        if (srs.isEmpty()) {
            StepResult r = new StepResult();
            r.message = s.objectApi + ': SKIPPED - static resource ' + s.resourceName + ' not found';
            return r;
        }
        return insertFromCsv(s.objectApi, srs[0].Body.toString(), keyMaps);
    }

    /**
     * CSV columns are one of:
     *   '#Key'                          - in-memory row key (never persisted)
     *   '#PersonAccount'                - TRUE = Person Account record type, else Business Account
     *   'Ref:<LookupField>:<ParentObj>' - lookup resolved from the parent object's key map
     *   <FieldApiName>                  - typed via describe (Date/Decimal/Boolean/String)
     * CSVs are generated without embedded commas, quotes, or newlines by design.
     */
    @TestVisible
    private static StepResult insertFromCsv(String objectApi, String csvBody, Map<String, Map<String, Id>> keyMaps) {
        StepResult out = new StepResult();
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        Schema.SObjectType sType = gd.get(objectApi);
        if (sType == null) {
            out.message = objectApi + ': SKIPPED - object not present in this org (check licenses/features)';
            return out;
        }
        Map<String, Schema.SObjectField> fieldMap = sType.getDescribe().fields.getMap();

        List<String> lines = csvBody.replace('\r\n', '\n').replace('\r', '\n').split('\n');
        List<String> headers = lines[0].split(',', -1);

        Id personRtId = objectApi == 'Account' ? personAccountRecordTypeId() : null;
        Id businessRtId = objectApi == 'Account' ? businessAccountRecordTypeId() : null;

        Set<String> skippedCols = new Set<String>();
        Integer skippedMissingParent = 0;
        List<SObject> recs = new List<SObject>();
        List<String> rowKeys = new List<String>();

        for (Integer i = 1; i < lines.size(); i++) {
            if (String.isBlank(lines[i])) { continue; }
            List<String> vals = lines[i].split(',', -1);
            SObject rec = sType.newSObject();
            String rowKey = null;
            Boolean missingParent = false;
            Boolean isPerson = false;

            for (Integer c = 0; c < headers.size(); c++) {
                String h = headers[c].trim();
                String v = c < vals.size() ? vals[c].trim() : '';

                if (h == '#Key') {
                    rowKey = v;
                    continue;
                }
                if (h == '#PersonAccount') {
                    isPerson = v.equalsIgnoreCase('TRUE');
                    continue;
                }
                if (String.isBlank(v)) { continue; }

                if (h.startsWith('Ref:')) {
                    // Ref:<LookupField>:<ParentObject>
                    List<String> parts = h.split(':');
                    Map<String, Id> parentKeys = keyMaps.get(parts[2]);
                    Id parentId = parentKeys == null ? null : parentKeys.get(v);
                    if (parentId == null) {
                        missingParent = true;
                    } else {
                        rec.put(parts[1], parentId);
                    }
                    continue;
                }

                String fname = h;
                Schema.SObjectField fTok = fieldMap.get(fname.toLowerCase());
                if (fTok == null && (fname.endsWith('StateCode') || fname.endsWith('CountryCode'))) {
                    // Fallback for orgs without State & Country picklists enabled
                    String alt = fname.replace('StateCode', 'State').replace('CountryCode', 'Country');
                    fTok = fieldMap.get(alt.toLowerCase());
                    if (fTok != null) { fname = alt; }
                }
                if (fTok == null) { skippedCols.add(h); continue; }

                Schema.DisplayType dt = fTok.getDescribe().getType();
                if (dt == Schema.DisplayType.DATE) {
                    rec.put(fname, Date.valueOf(v));
                } else if (dt == Schema.DisplayType.CURRENCY
                        || dt == Schema.DisplayType.DOUBLE
                        || dt == Schema.DisplayType.PERCENT) {
                    rec.put(fname, Decimal.valueOf(v));
                } else if (dt == Schema.DisplayType.BOOLEAN) {
                    rec.put(fname, v.equalsIgnoreCase('TRUE'));
                } else {
                    rec.put(fname, v);
                }
            }

            if (missingParent) {
                skippedMissingParent++;
                continue;
            }
            if (objectApi == 'Account') {
                Id rtId = isPerson ? personRtId : businessRtId;
                if (rtId != null) { rec.put('RecordTypeId', rtId); }
            }
            recs.add(rec);
            rowKeys.add(rowKey);
        }

        List<Database.SaveResult> results = Database.insert(recs, false);
        Integer ok = 0;
        Integer err = 0;
        List<String> samples = new List<String>();
        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult r = results[i];
            if (r.isSuccess()) {
                ok++;
                if (rowKeys[i] != null) { out.keys.put(rowKeys[i], r.getId()); }
            } else {
                err++;
                if (samples.size() < 3) {
                    samples.add(r.getErrors()[0].getMessage());
                }
            }
        }
        String msg = objectApi + ': success=' + ok + ', errors=' + err;
        if (skippedMissingParent > 0) { msg += ', skippedMissingParent=' + skippedMissingParent; }
        if (!samples.isEmpty()) { msg += ' | sample errors: ' + String.join(samples, ' || '); }
        if (!skippedCols.isEmpty()) { msg += ' | skipped columns: ' + String.join(new List<String>(skippedCols), ', '); }
        out.message = msg;
        return out;
    }

    private static void finish(String summary) {
        System.debug(LoggingLevel.INFO, 'Coastie-Ed training data seed complete:\n' + summary);
        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(UserInfo.getUserId());
            mail.setSaveAsActivity(false);
            mail.setSubject('Coastie-Ed EXPRESS training data seed - summary');
            mail.setPlainTextBody('SYNTHETIC training data seed results:\n\n' + summary
                + '\nNo external ID scaffolding was persisted; all relationships were resolved in memory.');
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Summary email not sent: ' + e.getMessage());
        }
    }
}
