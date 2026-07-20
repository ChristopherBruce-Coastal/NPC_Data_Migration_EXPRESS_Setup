# NPC Data Migration EXPRESS Training Org (TARGET Dataset) - Learner Setup

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
to any field.

The loader is one-shot per org: it refuses to run if EXPRESS data already exists.
To start over, request a fresh training org.

## Setup order (do not skip ahead)

Complete these in order. Each step depends on the one before it.

1. **Create your base NPC org.** [Get your Nonprofit Cloud training org per the course guide *(Ctrl+Click or Cmd+Click(Mac) to open in a new tab)*.](https://www.salesforce.com/form/sfdo/signup/nonprofit/nonprofit-cloud-base-trial/?noskip=true)

2. **Enable Person Accounts.** Setup > search "Person Accounts" > follow the enablement
   steps. This is irreversible in a standard org, which is fine for a disposable training org.
   1. **Create a "Business Account" record type on Account.** Setup > Object Manager >
      Account > Record Types > New. Label it exactly `Business Account` (developer name
      `Business_Account`), activate it, and make it available to your profile. The loader
      checks for this record type by name and refuses to run without it. Seeded business
      accounts get this record type; seeded individuals get the org's Person Account record type.

3. **Enable Fundraising.** Setup > search "Fundraising" > turn on Fundraising so the
   GiftTransaction object and its fields exist. Without this, the GiftTransaction step
   of the seed is skipped and the deploy of GiftTransaction fields fails.

4. **Assign the Fundraising Admin permission set group.** Setup > Users > your user >
   Permission Set Group Assignments > Edit Assignments > enable **Fundraising Admin** >
   Save. **The GiftTransaction step of the seed fails without it.**

5. **Enable State and Country/Territory Picklists.** Setup > search "State and Country/Territory
   Picklists" > enable. The dataset uses state and country values; the loader writes to the
   picklist code fields when this is on.

6. **Deploy this package from GitHub.** Use the Deploy button below. See
   [Deploy](#deploy) for the button and troubleshooting.

7. **Assign the permission sets to your user.** Setup > Permission Sets, then for each
   of **EXPRESS Training Data Admin** and **Fundraising Admin**: open it > Manage
   Assignments > Add Assignment > select your user > Assign. EXPRESS Training Data Admin
   grants access to the custom object, fields, and the loader; Fundraising Admin grants
   access to the Fundraising objects the seed writes to.

8. **Run the seed.** Open the Developer Console > Debug > Open Execute Anonymous Window,
   paste the following, and execute:

   ```apex
   CoastieEdTrainingDataLoader.run();
   ```

   The loader prechecks your setup and throws a plain-English message if a step was missed.
   Progress appears under Setup > Apex Jobs; a per-object summary is emailed to you when
   the chain finishes.

## Deploy

<a href="https://githubsfdeploy.herokuapp.com?owner=ChristopherBruce-Coastal&repo=NPC_Data_Migration_EXPRESS_Setup&ref=main">
  <img alt="Deploy to Salesforce" src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png">
</a>

The button reads this repo and deploys the metadata to the org you authorize.

### If the button shows "Oops, something went wrong"

This is an OAuth authorization failure between the deploy tool and your org, not a problem
with the package. It is common on new trial and My Domain orgs. Work through these in order:

1. Open the button in a fresh **incognito / private browser window** so no old session is cached.
2. In that same window, **log in to your training org first** (through your org's My Domain
   URL), then click the Deploy button and authorize when prompted.
3. On the tool's login screen, confirm you are authorizing the **correct org** and user.
4. Confirm your org has **no IP login restrictions** for your user (Setup > Profiles or
   Login IP Ranges). Remove or widen them for the training org if present.

If the button still fails after these steps, it is a known limitation of the community
deploy tool with certain org configurations. Contact your instructor; an alternative
install method may be provided.

## What gets deployed (metadata)

| Component | Purpose |
|---|---|
| `Deliverable__c` object + fields + tab | Custom object per the Deliverable schema doc (date, currency, long text fields) |
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

Verify in the Developer Console Query Editor, for example:

```sql
SELECT RecordType.Name, COUNT(Id) FROM Account GROUP BY RecordType.Name
```

The summary email's per-object line is the authoritative result. Any object where
`success` is below its target, or where `skippedMissingParent` or `parseErrors` is
nonzero, indicates a data or setup problem worth reporting to your instructor.

## Troubleshooting

- **`SETUP INCOMPLETE: Person Accounts is not enabled`**: complete step 2 before running the loader.
- **`SETUP INCOMPLETE: No active "Business Account" record type`**: complete step 2.1. The record type label/developer name must match `Business Account` / `Business_Account`.
- **`SETUP INCOMPLETE: No Person Account record type`**: you are not in an NPC org with Person Accounts; get the correct training org.
- **`ALREADY SEEDED`**: the seed ran before in this org. Use a fresh org.
- **GiftTransaction step reports SKIPPED or errors**: Fundraising is not enabled (step 3), the Fundraising Admin permission set is not assigned (step 6), or the Fundraising Access permission set license is not assigned (step 7).
- **StandardValueSet warning on deploy**: deploying `OpportunityStage`/`LeadStatus` replaces the full org value sets. Intended for disposable training orgs only.

## Regenerating the CSVs

The dataset is reproducible from `gen_target2.py` (seed `20260706`) in the EXPRESS
curriculum workspace. The SOURCE (defective) dataset is intentionally NOT in this
repo; it is distributed to learners as a workbook, not loaded to the org.
