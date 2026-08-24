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
To start over, request a fresh training org (step 1).

## Before you start: take a record census

**Do this first, before you deploy anything.** Your training org almost certainly arrives
with records already in it, so the way to verify the seed is to compare counts **before and
after** and check the difference. An absolute total tells you nothing: if your org starts
with 13,588 gift transactions, a post-seed total of 14,896 is comfortably "more than 1,744"
and still means 436 rows failed to load.

Run `scripts/census.apex` with `MODE = 'BEFORE'` in the Developer Console (Debug > Open
Execute Anonymous Window, tick **Open Log**). It changes nothing. Copy the `BASELINE` block
it prints and keep it: you will paste it back in at step 10.

**This window exists once per org.** Once you have seeded, you cannot recover the baseline.

## Setup order (do not skip ahead)

Complete these in order. Each step depends on the one before it.

1. **Get your training org.** Request a Nonprofit Cloud demo org from
   [Partner Learning Camp > Demo Org *(Ctrl+Click or Cmd+Click(Mac) to open in a new tab)*](https://partnerlearningcamp.salesforce.com/s/demo-org),
   choosing the **NPC** demo type. EXPRESS learners are Coastal consultants with PLC access,
   so you are eligible.

   > **Your org expires in 30 days.** So does every Salesforce trial org. Plan the exercise
   > inside that window, and if it lapses mid-programme, request a new one and re-run this
   > setup from the top. There is no way to extend it.
   >
   > **A demo org arrives already populated** with several tens of thousands of records, and
   > with more org features already switched on than a bare trial. That is realistic and it is
   > fine. It does mean steps 2, 3 and 6 below may already be done for you, and it is why
   > verification is a delta check rather than a count.

2. **Enable Person Accounts (complete ALL four sub-steps — this is the most common place setup goes wrong).**

   > **Check first.** In a PLC demo org this is normally already enabled and a
   > `Business Account` record type may already exist under a different label. If Setup shows
   > Person Accounts enabled, skip to step 3. Do not try to enable it twice.

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
   *(Normally already on in a PLC demo org. Verify rather than perform.)*

4. **Assign the Fundraising Admin permission set group.** Setup > Users > your user >
   Permission Set Group Assignments > Edit Assignments > enable **Fundraising Admin** >
   Save. **The GiftTransaction step of the seed fails without it.**

5. **Enable State and Country/Territory Picklists.** Setup > search "State and Country/Territory
   Picklists" > enable, and complete the conversion. The dataset uses state and country values;
   the loader writes to the picklist code fields when this is on.
   **This one is frequently OFF even in a demo org, so check it.**

6. **Enable "Allow users to relate a contact to multiple accounts."** Setup > Quick Find >
   "Account Settings" > **Edit** > check **Allow users to relate a contact to multiple accounts**
   > **Save**. **The seed's 400 Account-Contact relationships cannot load without this**, and the
   loader will refuse to run until it is on. Like Person Accounts, enabling it is irreversible in a
   standard org, which is fine for a disposable training org.
   *(Normally already on in a PLC demo org. Verify rather than perform.)*

7. **Deploy this package from GitHub.** Use the Deploy button below. See
   [Deploy](#deploy) for the button and troubleshooting.

   > **Deploying replaces two standard picklists rather than merging them.** The package ships
   > `OpportunityStage` and `LeadStatus` standard value sets, which **overwrite** your org's
   > existing values. In an org that already holds records, this orphans their picklist values:
   > measured in one demo org at **347 of 744 Opportunities** and **56 of 374 Leads**. That is
   > expected and it is fine for a disposable training org, but it will look alarming if you are
   > not warned, and those records will show blank stages afterwards.

8. **Assign the EXPRESS Training Data Admin permission set to your user.** Setup >
   Permission Sets > **EXPRESS Training Data Admin** > Manage Assignments > Add Assignment >
   select your user > Assign. This grants access to the custom object, fields, and the loader.
   (Fundraising access was already granted in step 4 via the Fundraising Admin permission set group.)

9. **Verify your setup before you seed.**

   *New to the Developer Console?* Open it from the **gear icon** in the top-right of Salesforce
   Setup — click the gear, then **Developer Console**. It opens in a new window. (If you don't see
   it under the gear, your user may need the "Author Apex" permission; the EXPRESS Training Data
   Admin permission set from step 8 covers this.)

   In the Developer Console, go to **Debug > Open Execute Anonymous Window**, tick **Open Log**,
   paste the following, and click **Execute**:

   ```apex
   CoastieEdTrainingDataLoader.checkSetup();
   ```

   This checks the org settings the steps above turn on, and **changes nothing in your org**.

   - **If a step was missed**, an error appears immediately naming it. Fix that step, then run
     this again. Repeat until it passes.
   - **If your setup is complete**, execution finishes with **no error**. That is the pass
     signal. To see it stated outright, look in the log that opens for `SETUP OK`.

   > **What this check does and does not tell you.** It verifies five org settings and looks for
   > a fingerprint of its own data. It does **not** verify that this org is a suitable target,
   > and it cannot see records that were already here. A green result means "the settings are
   > on", not "you are ready". The delta check at step 10 is what proves the seed worked.

   The next step is **one-shot per org**: the seed refuses to run twice, and to start over you
   need a fresh training org. Confirm this step passes first, and confirm you have your
   `BEFORE` census from the section above.

10. **Run the seed, then check the deltas.**

    In the same Execute Anonymous window, replace the line with the following and click **Execute**:

    ```apex
    CoastieEdTrainingDataLoader.run();
    ```

    The loader re-runs the same checks before it starts, so a step missed after step 9 still stops
    it here rather than seeding a half-configured org.
    Progress is tracked under **Setup > Apex Jobs** (the seed runs as a chain of four jobs).

    > **Four Completed jobs does NOT mean four successful jobs.** The loader inserts with partial
    > success enabled by design, so a job that discards rows still finishes and still reports
    > `Completed`. This has happened: an earlier build of the seed silently dropped 436 of 1,744
    > gift transactions while all four jobs reported success. **The delta check below is the
    > actual verification. Do not skip it.**

    When all four jobs show Completed, paste your `BASELINE` block into `scripts/census.apex`,
    set `MODE = 'AFTER'`, and run it. It prints your before and after counts, the difference, and
    PASS or FAIL against each expected delta.

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

### A quieter deploy hazard

The deploy tool has been observed **omitting a component without reporting an error**. A
successful-looking deploy is not proof that everything installed. If something the table below
lists is missing from your org, check Setup > Object Manager rather than re-reading the deploy
log, and tell your instructor.

## What gets deployed

| Component | Purpose |
|---|---|
| `Deliverable__c` object + fields + tab | Custom object per the Deliverable schema doc (date, currency, long text fields) |
| `EIN__c` (Account), `GL_Fund_Code__c` (Opportunity) | Scenario fields used for matching and designations |
| `Designation_GL_Code__c` + `Source_Opportunity__c` (GiftTransaction) | Preserves designation codes and the legacy gift-to-opportunity link |
| `OpportunityStage` + `LeadStatus` standard value sets | Aligns stages/statuses with the dataset (WARNING: replaces the org's existing values; see step 7) |
| `Migration_Settings__c` custom setting | Holds the automation bypass flag the loader sets during the seed |
| Contact field history tracking (`FirstName`, `LastName`) | Makes name changes traceable during the exercise |
| `CoastieEdTrainingDataLoader` Apex (+ tests) | Precheck + one-shot queueable seed chain |
| 7 CSV static resources (`CE_*`) | The TARGET dataset rows |
| `EXPRESS_Training_Data_Admin` permission set | Access to the custom object, fields, and loader |

No external ID fields are deployed. No record types are deployed; you create the
Business Account record type yourself in step 2, and Person Accounts ship with the
NPC org.

## Expected seed deltas

**Every number below is a difference, not a total.** Compare your `AFTER` census against your
`BEFORE` census. `scripts/census.apex` does this for you.

| Object | Expected delta |
|---|---|
| Account | **+1,200** (300 business + 900 person) |
| ↳ of which person / business record type | **+900 / +300** |
| Contact | **+1,700** (800 from the CSV + 900 auto-created behind person accounts) |
| Lead | **+500** |
| Opportunity | **+1,700** |
| GiftTransaction | **+1,744** |
| Deliverable__c | **+500** |
| AccountContactRelation, indirect only | **+400** |

> Contact moves by 1,700 because each seeded individual (Person Account) automatically
> creates its own Contact: 800 business contacts + 900 person-account contacts.

> **`AccountContactRelation` must be counted on `IsDirect = false`.** The absolute total moves by
> **1,200**, not 400, for two unrelated reasons: the seed's 400 indirect rows, plus one automatic
> direct row created per inserted Contact. If you reconcile on the total you will see 1,200,
> conclude the load is broken, and be looking at a correct result.

If you would rather check by hand, the Developer Console Query Editor equivalents are:

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
```sql
SELECT COUNT() FROM AccountContactRelation WHERE IsDirect = false
```

**Any delta that does not match its target is worth reporting to your instructor**, whether it is
low or high. A delta that is too low means rows failed to load. A delta that is too high means
something ran twice.

> **If the indirect Account-Contact relationship delta is 0**, step 6 was skipped: the
> relationships had nowhere to load, and **the seed still reported success**, because the loader
> does not fail a job on individual row errors. Enable the setting and use a fresh org.

## Troubleshooting

Every `SETUP INCOMPLETE` message below is also what `CoastieEdTrainingDataLoader.checkSetup();`
(step 9) reports, so you can re-check after a fix without attempting a seed.

- **Deploy fails with `No such column 'IsPersonType' on entity 'RecordType'`** (and a cascade
  error about no ApexClass named `CoastieEdTrainingDataLoader`): Person Accounts enablement was
  not completed. The `IsPersonType` field only exists once Person Accounts is fully enabled.
  Return to step 2, finish all four sub-steps (especially clicking **Enable Person Accounts**
  on the original tab and confirming the success banner), then redeploy.
- **`SETUP INCOMPLETE: No Person Account record type`**: you are not in an NPC org with Person Accounts enabled; complete step 2 or get the correct training org.
- **`SETUP INCOMPLETE: No active "Business Account" record type`**: complete step 2, sub-step 3. The record type label/developer name must match `Business Account` / `Business_Account`.
- **`SETUP INCOMPLETE: Fundraising is not enabled`**: complete step 3.
- **`SETUP INCOMPLETE: GiftTransaction exists but your user cannot create it`**: complete step 4, the Fundraising Admin permission set group.
- **`SETUP INCOMPLETE: State and Country/Territory Picklists are not enabled`**: complete step 5, including the conversion.
- **`SETUP INCOMPLETE: "Allow users to relate a contact to multiple accounts" is not enabled`**: complete step 6. If you have already seeded without it, the 400 secondary Account-Contact relationships did not load and the seed reported success anyway. Enable the setting and use a fresh org.
- **`ALREADY SEEDED`**: the seed ran before in this org. Use a fresh org.
- **GiftTransaction step reports SKIPPED or errors**: Fundraising is not enabled (step 3) or the Fundraising Admin permission set group is not assigned (step 4).
- **GiftTransaction delta is short but every job reported Completed**: this is the partial-success
  behaviour described at step 10. The loader does not fail a job on individual row errors, so a
  short delta with four Completed jobs means rows were rejected silently. Report the exact
  shortfall to your instructor; it is a package problem, not something you can fix in the org.
- **StandardValueSet warning on deploy**: deploying `OpportunityStage`/`LeadStatus` replaces the full org value sets. Intended for disposable training orgs only. See step 7.
- **My org expired part-way through**: all trial and demo orgs expire in 30 days. Request a new one at step 1 and re-run this setup. Nothing carries over.
- **The seed did not appear to finish**: check **Setup > Apex Jobs**. The seed runs as four chained jobs; all four should show Completed. If a job shows Failed, open it for the error.

## Regenerating the dataset

The TARGET dataset and metadata are reproducible from the builder scripts in the EXPRESS
curriculum workspace (seed `20260706`). The SOURCE (defective) dataset is intentionally
NOT in this repo; it is distributed to learners as a workbook, not loaded to the org.

> **Facilitators: do not run a regenerate-and-diff before a cohort until the builders have been
> reconciled with this repo.** They are currently out of sync, and regenerating overwrites fixes
> that exist only here. See the programme admin runbook.
