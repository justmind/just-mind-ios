# Client Matching Tool — Google Sheets + Apps Script

A faithful rebuild of the Airtable **Client Matching Tool** (base `appUsUyUKTz8yC2rs`) in Google Sheets,
driven by Apps Script. It recreates the data, the dropdowns, the dashboards, and adds an
**auto-scoring therapist↔client matching engine**.

## Files

| File | What it is |
|------|-----------|
| `Code.gs` | All logic: workbook builder, matching engine, dashboards, menu, on-edit auto-match, form endpoints. |
| `Data.gs` | Auto-generated from Airtable: every dropdown option list + all 52 therapists + 21 client submissions. |
| `Form.html` | The **New Client Form** dialog (searchable multi-selects) — the equivalent of the Airtable form interface. |
| `DataView.html` | An **Airtable-style read view** — colored chips, sticky header/Name column, tab + filter. |

## Setup (5 minutes)

1. Create a new Google Sheet.
2. **Extensions → Apps Script.**
3. Delete the empty `Code.gs` stub, then create the script/HTML files and paste in `Code.gs`, `Data.gs`,
   `Form.html`, and `DataView.html` from this folder. Names must match exactly — for the HTML files use
   **File → New → HTML file** named `Form` and `DataView` (Apps Script adds the `.html`).
4. Save. In the editor's function dropdown pick **`setupWorkbook`** and click **Run**.
   Authorize when prompted (first run only).
5. Go back to the Sheet and reload the tab. You'll see a **Client Matching** menu and four sheets.

## What gets built (mapped to the Airtable tabs)

| Airtable tab | Here |
|---|---|
| Therapist Directory (list) + Therapist Directory (Record Review) | **Therapist Directory** sheet — all 52 therapists, every field, full dropdowns, live `Total Assigned Clients` formula |
| Client Submissions (Record Review) | **Client Request Submissions** sheet — all 21 submissions + scored matching + `Match Details` |
| Therapist Metrics Dashboard | **Therapist Metrics** sheet — Total Therapists, Currently Accepting, Accepting Insurance, breakdowns + pie chart |
| Client Submissions (dashboard) | **Client Submissions Dashboard** sheet — totals, assigned/unassigned, breakdowns + column chart |

> The two Airtable "Record Review" tabs are just alternate layouts of the same two tables, so they
> collapse into the two data sheets here. Use the sheet **Filter** (already enabled) to slice/review.

## New Client Form (the Airtable form interface)

**Client Matching → ➕ New client form…** opens a dialog that mirrors the Airtable "New Client Form":
the same fields, the same dropdowns, with **searchable multi-selects** for the long specialty lists.
On submit it appends a record to **Client Request Submissions**, runs the scoring engine, and shows the
ranked therapist matches (score + why) right in the dialog. "Add another" clears it for the next intake.

Required fields: Name, Age Category, Specialities. (Sub-Specialties is optional.)
The form also collects an optional **Office Location**, which feeds the location score.

## Airtable-style data view

**Client Matching → 🔎 View data (Airtable-style)…** opens a read-only grid that renders records the way
Airtable does: multi-select and single-select values as **colored chips**, a sticky header and sticky
**Name** column, a tab to switch between Therapist Directory and Client Request Submissions, and a filter
box. Colors are assigned consistently per option value (Yes→green, No→red, etc.). This is the prettier
"rendered" view of the same data that lives in the sheets.

**Assign / reassign:** each match in the results has an **Assign** button that writes that therapist into
the row's `Assigned Therapist`. On the sheet, `Assigned Therapist` is also a dropdown of all therapist
names, so you can reassign inline — and `Total Assigned Clients` on the Therapist Directory updates live.

**Use the form outside the Sheet (web app):** in the Apps Script editor, **Deploy → New deployment →
Web app** (execute as *you*, access as needed) gives a public URL that serves the same form via `doGet()`.

## Matching engine (Auto + score)

Edit any criteria on a **Client Request Submissions** row and `Matched Therapists` recomputes
automatically (or use **Client Matching → Recompute…**). Therapists are filtered, then ranked by score.

**Hard filters** (must pass to appear): therapist not `Accepting Clients? = No`; therapy type overlaps
(when both specify); client age within the therapist's age groups; not excluded by `DOES NOT TAKE`;
if the client is using insurance, therapist must accept insurance.

**Score weights** (in `Code.gs → WEIGHTS`, tweak freely):

| Factor | Points |
|---|---|
| Specialty overlap (primary / "maybe comfortable") | 3 / 2 each |
| Sub-specialty overlap (primary / "maybe comfortable") | 3 / 2 each |
| Insurance carrier exact match / takes insurance | 3 / 1 |
| Age, therapy type, office location | 2 each |
| Virtual vs. in-person modality | 1 |

Output looks like `Brett (16)` — the therapist and total score — top 25 listed, with a one-line
`Match Details` summary.

## Conventions

- **Multi-value cells** (specialties, age groups, etc.) hold one option **per line** (newline-separated).
  The dropdowns suggest valid options; multi-value cells allow adding several.
- **Re-importing**: `Data.gs` is generated from Airtable. To refresh data, regenerate it and re-run
  `setupWorkbook` (menu: *Rebuild entire workbook*).

## Notes / fidelity

- Dropdown lists are the **full canonical Airtable option sets** (e.g. 60 specialties, 71 sub-specialties).
- **Styling:** color-coded status columns (Accepting / Insurance / New Client / Using Insurance), seniority
  shading, bold names, centered status fields, banded rows, a frozen header, and unassigned-row highlighting.
- `Total Assigned Clients` is a live `COUNTIF` over the client sheet's `Assigned Therapist` column,
  mirroring Airtable's rollup.
- `Matched Therapists` was historical/manual in Airtable; here it is recomputed by the scoring engine
  (the originally-imported values are overwritten on first `setupWorkbook` / recompute).
