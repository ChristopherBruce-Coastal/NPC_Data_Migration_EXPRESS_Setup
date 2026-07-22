# NPC Data Migration EXPRESS Training Org (TARGET Dataset) - Learner Setup

Deploys the training metadata and seeds the **sterile TARGET dataset** for the EXPRESS
Data Migration program into **your own** Salesforce Nonprofit Cloud (NPC) training org.
You (the learner) deploy this package yourself as part of environment setup.

> **ALL DATA IS SYNTHETIC.** Fictional entities only, generated with seed `20260706`.
> No real people or organizations are represented. For training, testing, and demos only.

## How the seed works (and what it leaves behind)

The dataset ships as CSV static resources. A Queueable Apex loader inserts the records
in relational order (Account -> Contact -> AccountContactRelation -> Lead ->
Opportunity -> GiftTransaction -> Deliverable__c) and resolves every foreign key
**in memory**: CSV row keys are mapped to the inserted record Ids and are never written
to any field. After the seed, the org contains no migration scaffolding.

The loader is one-shot per org: it refuses to run if EXPRESS data already exists.
To start over, request a fresh training org.

## Setup order (do not skip ahead)

Complete these in order. Each step depends on the one before it.

1. **Create your base NPC org.** [Get your Nonprofit Cloud training org per the course guide *(Ctrl+Click or Cmd+Click(Mac) to open in a new tab)*.](https://www.salesforce.com/form/sfdo/signup/nonprofit/nonprofit-cloud-base-trial/?noskip=true)

2. **Enable Person Accounts (complete ALL four sub-steps — this is the most common place setup goes wrong).**
   Person Account enablement is a multi-step flow, and one sub-step opens a **new browser tab**.
   You are not finished until you have returned to the original tab and clicked the final
   Enable button. Enabling Person Accounts is irreversible in a standard org, which is fine
   for a disposable training org.
   1. **Open the Person Accounts setup page.** Setup > Quick Find > "Person Accounts" >
      under Feature Settings > Accounts, click **Person Accounts**.
   2. **Acknowledge org impact.** Under *Step 1: Org Impact Acknowledgement*, click
      **View Org Impacts**, review the modal, and click **Continue**.
   3. **Create the Business Account record type.** Under *Step 2: Create Accounts Record Type*,
      click **Set Up** — this opens Object Manager in a **new tab**. Click **New**, enter
      `Business Account` as the Record Type Label (Record Type Name auto-fills as
      `Business_Account`), keep **Active** checked, set profile visibility, click **Next**,
      choose a page layout, and click **Save**. The loader checks for this record type by
      name and refuses to run without it.
   4. **Return to the original tab and finish enabling.** Switch back to the Person Accounts
      setup tab, **refresh the page**, and confirm both steps show green checkmarks. Then
      click **Enable Person Accounts** (bottom-right) and click **Enable** in the confirmation
      dialog. **You must see the "Successfully enabled Person Accounts" banner** — if you do
      not, Person Accounts is not enabled and the package will fail to deploy (see the
      `IsPersonType` note in Troubleshooting). Do not proceed to deploy until you see that banner.


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

7. **Assign the EXPRESS Training Data Admin permission set to your user.** Setup >
   Permission Sets > **EXPRESS Training Data Admin** > Manage Assignments > Add Assignment >
   select your user > Assign. This grants access to the custom object, fields, and the loader.
   (Fundraising access was already granted in step 4 via the Fundraising Admin permission set group.)

8. **Run the seed.**

   *New to the Developer Console?* Open it from the **gear icon** in the top-right of Salesforce
   Setup — click the gear, then **Developer Console**. It opens in a new window. (If you don't see
   it under the gear, your user may need the "Author Apex" permission; the EXPRESS Training Data
   Admin permission set from step 7 covers this.)

   In the Developer Console, go to **Debug > Open Execute Anonymous Window**, paste the following,
   and click **Execute**:

   ```apex
   CoastieEdTrainingDataLoader.run();
   ```

   The loader prechecks your setup and throws a plain-English message if a step was missed.
   Progress and completion are tracked under **Setup > Apex Jobs** (the seed runs as a
   chain of four jobs; when all four show Completed, the seed is done).

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

## What gets deployed

| Component | Purpose |
|---|---|
| `Deliverable__c` object + fields + tab | Custom object per the Deliverable schema doc (date, currency, long text fields) |
| `EIN__c` (Account), `GL_Fund_Code__c` (Opportunity) | Scenario fields used for matching and designations |
| `Designation_GL_Code__c` + `Source_Opportunity__c` (GiftTransaction) | Preserves designation codes and the legacy gift-to-opportunity link |
| `OpportunityStage` + `LeadStatus` standard value sets | Aligns stages/statuses with the dataset (WARNING: replaces the org's existing values; fine for disposable training orgs) |
| `CoastieEdTrainingDataLoader` Apex (+ tests) | Precheck + one-shot queueable seed chain |
| 7 CSV static resources (`CE_*`) | The TARGET dataset rows |
| `EXPRESS_Training_Data_Admin` permission set | Access to the custom object, fields, and loader |

No external ID fields are deployed. No record types are deployed; you create the
Business Account record type yourself in step 2, and Person Accounts ship with the
NPC org.

## Expected record counts after the seed

Account 1200 | Contact 1707 | Lead 500 | Opportunity 1700 | GiftTransaction 1744 | Deliverable__c 500

The seed also loads 400 Account-Contact relationships (secondary contact roles). These
are not directly queryable by object name in a Nonprofit Cloud org, so they are not
listed above for verification; they load as part of the relational chain.

> Contact totals 1707 because each seeded individual (Person Account) automatically
> creates its own Contact (800 business contacts + 900 person-account contacts). Your
> counts may be slightly higher if your org already contained sample records before the
> seed; they should never be lower than the numbers above.

Verify in the Developer Console Query Editor (open the Developer Console from the Setup **gear
icon > Developer Console**, then use the **Query Editor** tab at the bottom). Run each of these
and compare against the targets above:

```sql
SELECT RecordType.Name, COUNT(Id) FROM Account GROUP BY RecordType.Name
```
```sql
SELECT COUNT() FROM Account
```
```sql
SELECT COUNT() FROM Contact
```
```sql
SELECT COUNT() FROM Lead
```
```sql
SELECT COUNT() FROM Opportunity
```
```sql
SELECT COUNT() FROM GiftTransaction
```
```sql
SELECT COUNT() FROM Deliverable__c
```

The first query breaks Account down by record type (business vs. person); the total should
be 1,200. Counts equal to or greater than the targets are healthy. Any object whose count
falls below its target indicates a data or setup problem worth reporting to your instructor.

> Account-Contact relationships are not directly queryable by object name in a Nonprofit
> Cloud org, so there is no count query for them here.

## Troubleshooting

- **Deploy fails with `No such column 'IsPersonType' on entity 'RecordType'`** (and a cascade
  error about no ApexClass named `CoastieEdTrainingDataLoader`): Person Accounts enablement was
  not completed. The `IsPersonType` field only exists once Person Accounts is fully enabled.
  Return to step 2, finish all four sub-steps (especially clicking **Enable Person Accounts**
  on the original tab and confirming the success banner), then redeploy.
- **`SETUP INCOMPLETE: No Person Account record type`**: you are not in an NPC org with Person Accounts enabled; complete step 2 or get the correct training org.
- **`SETUP INCOMPLETE: No active "Business Account" record type`**: complete step 2, sub-step 3. The record type label/developer name must match `Business Account` / `Business_Account`.
- **`ALREADY SEEDED`**: the seed ran before in this org. Use a fresh org.
- **GiftTransaction step reports SKIPPED or errors**: Fundraising is not enabled (step 3) or the Fundraising Admin permission set group is not assigned (step 4).
- **StandardValueSet warning on deploy**: deploying `OpportunityStage`/`LeadStatus` replaces the full org value sets. Intended for disposable training orgs only.
- **The seed did not appear to finish**: check **Setup > Apex Jobs**. The seed runs as four chained jobs; all four should show Completed. If a job shows Failed, open it for the error.

## Regenerating the dataset

The TARGET dataset and metadata are reproducible from the builder scripts in the EXPRESS
curriculum workspace (seed `20260706`). The SOURCE (defective) dataset is intentionally
NOT in this repo; it is distributed to learners as a workbook, not loaded to the org.
