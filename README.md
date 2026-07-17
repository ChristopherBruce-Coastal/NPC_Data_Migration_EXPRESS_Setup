# Coastie-Ed EXPRESS Training Org (TARGET Dataset) - Learner Setup

Deploys the training metadata and seeds the **sterile TARGET dataset** for the EXPRESS
Data Migration program into **your own** Salesforce Nonprofit Cloud (NPC) training org.
You (the learner) deploy this package yourself as part of environment setup.

> **ALL DATA IS SYNTHETIC.** Fictional entities only, generated with seed `20260706`.
> No real people or organizations are represented. For training, testing, and demos only.

## How the seed works (and what it leaves behind)

The dataset ships as CSV static resources. A Queueable Apex loader inserts the records
in FR-5 relational order (Account -> Contact -> AccountContactRelation -> Lead ->
Opportunity -> GiftTransaction -> Deliverable__c) and resolves every foreign key
**in memory**: CSV row keys are mapped to the inserted record Ids and are never written
to any field. After the seed completes, the org contains **no external IDs and no
migration scaffolding**. You will design your own external ID strategy later in the
program; this org starts clean, the way a real legacy org would.

The loader is one-shot per org: it refuses to run if Coastie-Ed data already exists.
To start over, request a fresh training org (instructors: `scripts/reset-data.apex`
is a best-effort purge).

## Setup order (do not skip ahead)

1. **Get your NPC training org** per the course guide (Person Accounts come enabled).
2. **Create the Business Account record type** on Account, per the setup guide:
   Setup > Object Manager > Account > Record Types > New. Label it exactly
   `Business Account` (developer name `Business_Account`), activate it, and make it
   available to your profile. The loader checks for it by name and refuses to run
   without it. Seeded business accounts get this record type; seeded individuals get
   the org's Person Account record type.
3. **Deploy this repo** with the button below (or the CLI command).
4. **Assign the permission set**: `sf org assign permset -n EXPRESS_Training_Data_Admin -o <alias>`
5. **Run the seed**:

```bash
sf apex run --file scripts/load-data.apex -o <alias>
```

or paste `CoastieEdTrainingDataLoader.run();` into Developer Console > Execute Anonymous.
The loader prechecks your setup and throws a plain-English message if a step was missed.
Progress appears under Setup > Apex Jobs; a per-object summary is emailed to you when
the chain finishes.

## Deploy button

Replace `YOUR_GH_USER` after you fork/create the repo:

```html
<a href="https://githubsfdeploy.herokuapp.com?owner=YOUR_GH_USER&repo=NPC_Data_Migration_EXPRESS_Setup&ref=main">
  <img alt="Deploy to Salesforce" src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png">
</a>
```

githubsfdeploy supports SFDX source-format repos and reads the default package
directory (`force-app`) from `sfdx-project.json`. CLI alternative:

```bash
sf project deploy start -o <alias>
```

## What gets deployed (metadata)

| Component | Purpose |
|---|---|
| `Deliverable__c` object + fields + tab | Custom object per the Deliverable schema doc (date, currency, address, long text fields) |
| `EIN__c` (Account), `GL_Fund_Code__c` (Opportunity) | Scenario fields used for FR-1.2 matching and FR-2.2 designations |
| `Designation_GL_Code__c` + `Source_Opportunity__c` (GiftTransaction) | Preserves designation codes and the legacy gift-to-opportunity link |
| `OpportunityStage` + `LeadStatus` standard value sets | Aligns stages/statuses with the dataset (WARNING: replaces the org's existing values; fine for disposable training orgs) |
| `CoastieEdTrainingDataLoader` Apex (+ tests) | Precheck + one-shot queueable seed chain |
| 7 CSV static resources (`CE_*`) | The TARGET dataset rows |
| `EXPRESS_Training_Data_Admin` permission set | Access to the custom object, fields, and loader |

No external ID fields are deployed. No record types are deployed; you create the
Business Account record type yourself in step 2, and Person Accounts ship with the
NPC org.

## Expected record counts after the seed

Account 1200 | Contact 800 | AccountContactRelation 400 | Lead 500 | Opportunity 1700 | GiftTransaction 1744 | Deliverable__c 500

Verify with, for example:

```sql
SELECT RecordType.Name, COUNT(Id) FROM Account GROUP BY RecordType.Name
```

## Troubleshooting

- **`SETUP INCOMPLETE: No active "Business Account" record type`**: complete step 2. The record type label/developer name must match `Business Account` / `Business_Account`.
- **`SETUP INCOMPLETE: No Person Account record type`**: you are not in an NPC org with Person Accounts; get the correct training org.
- **`ALREADY SEEDED`**: the seed ran before in this org. Use a fresh org.
- **GiftTransaction step reports SKIPPED or errors**: Fundraising is not enabled or your user lacks the Fundraising User permission.
- **`Location__c` Address field fails to deploy**: delete `force-app/main/default/objects/Deliverable__c/fields/Location__c.field-meta.xml` and redeploy; the loader reports the `Location__*__s` columns as skipped and continues.
- **StandardValueSet warning**: deploying `OpportunityStage`/`LeadStatus` replaces the full org value sets. Intended for disposable training orgs only.

## Regenerating the CSVs

The dataset is reproducible from `gen_target2.py` (seed `20260706`) in the EXPRESS
curriculum workspace. The SOURCE (defective) dataset is intentionally NOT in this
repo; it is distributed to learners as a workbook, not loaded to the org.
