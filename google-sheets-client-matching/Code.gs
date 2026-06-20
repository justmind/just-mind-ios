/**
 * Code.gs — "Client Matching Tool" rebuilt in Google Sheets (clone of Airtable base appUsUyUKTz8yC2rs).
 *
 * WHAT THIS BUILDS (mirrors the 5 Airtable interface tabs):
 *   1. Therapist Directory            — 52 therapists, every field + dropdowns  (list tab)
 *   2. Client Request Submissions     — 21 submissions + scored matching        (list tab + "record review")
 *   3. Therapist Metrics              — dashboard (Total Therapists, Currently Accepting, breakdowns + chart)
 *   4. Client Submissions Dashboard   — dashboard (totals, assigned/unassigned, breakdowns + chart)
 *
 * HOW TO USE:
 *   1. Create a new Google Sheet → Extensions → Apps Script.
 *   2. Add two files: this one (Code.gs) and Data.gs (the generated data).
 *   3. Run setupWorkbook() once (authorize when asked).
 *   4. Reload the Sheet — a "Client Matching" menu appears.
 *
 * MATCHING: edit any criteria on a Client row (or use the menu) and the tool fills
 * "Matched Therapists" with eligible therapists ranked by a weighted overlap score,
 * plus a "Match Details" breakdown. See computeMatch() for the rules.
 *
 * Multi-value cells store options separated by a NEWLINE (one option per line).
 */

/* ------------------------------------------------------------------ */
/*  Configuration                                                      */
/* ------------------------------------------------------------------ */

var SHEET = {
  THERAPIST: 'Therapist Directory',
  CLIENT: 'Client Request Submissions',
  DASH_T: 'Therapist Metrics',
  DASH_C: 'Client Submissions Dashboard'
};

// Therapist columns — MUST stay in the same order as THERAPIST_ROWS in Data.gs.
// Trailing "Total Assigned Clients" is a formula column added by setup (not in the data).
var THERAPIST_COLUMNS = [
  'Name', 'Accepting Clients?', 'Seniority Level', 'Therapy (Client) Types', 'Age Groups',
  'Office Location', 'Virtual vs. In Person', 'Insurance Accepted?', 'Insurance Carriers',
  'Specialities', 'Sub-Specialties', 'Specialties- Maybe Comfortable Working With',
  'Sub-Specialties- Maybe Comfortable Working With', 'DOES NOT TAKE', 'Language(s) Spoken',
  'States Licensed (Other than TX)', 'Individuals Fee Structure', 'Couples Fee Structure',
  'Info Added', 'Identity (shareable)', 'Enjoys Working With (notes)', 'Assigned Clients',
  'Matched Clients', 'Total Assigned Clients'
];

// Client columns — MUST stay in the same order as CLIENT_ROWS in Data.gs.
// Trailing "Match Details" is added by setup (not in the data).
var CLIENT_COLUMNS = [
  'Name', 'Submission Date', 'New Client', 'Therapy Type', 'Age Category', 'Specialities',
  'Sub-Specialties', 'Virtual vs. In Person', 'Office Location', 'Using Insurance',
  'Insurance Carrier', 'Availability', 'Assigned Therapist', 'Matched Therapists', 'Match Details'
];

// header -> { group: 'therapist'|'client', multi: bool }  (drives data-validation dropdowns)
var THERAPIST_DROPDOWNS = {
  'Accepting Clients?': false, 'Seniority Level': false, 'Insurance Accepted?': false,
  'Therapy (Client) Types': true, 'Age Groups': true, 'Office Location': true,
  'Virtual vs. In Person': true, 'Insurance Carriers': true, 'Specialities': true,
  'Sub-Specialties': true, 'Specialties- Maybe Comfortable Working With': true,
  'Sub-Specialties- Maybe Comfortable Working With': true, 'DOES NOT TAKE': true,
  'Language(s) Spoken': true, 'States Licensed (Other than TX)': true
};
var CLIENT_DROPDOWNS = {
  'New Client': false, 'Age Category': false, 'Office Location': false,
  'Using Insurance': false, 'Insurance Carrier': false, 'Therapy Type': true,
  'Specialities': true, 'Sub-Specialties': true, 'Virtual vs. In Person': true,
  'Availability': true
};

var HEADER_BG = '#16324f';      // deep blue header
var HEADER_FG = '#ffffff';
var ACCENT = '#2d6a4f';         // JM-ish green accent for dashboards
var BANDING = '#eef3f8';

/* ------------------------------------------------------------------ */
/*  Menu                                                               */
/* ------------------------------------------------------------------ */

function onOpen() {
  SpreadsheetApp.getUi()
    .createMenu('Client Matching')
    .addItem('➕ New client form…', 'openNewClientForm')
    .addItem('🔎 View data (Airtable-style)…', 'openDataView')
    .addSeparator()
    .addItem('Recompute matches for ALL clients', 'recomputeAllMatches')
    .addItem('Recompute match for current row', 'recomputeCurrentRow')
    .addSeparator()
    .addItem('Refresh dashboards', 'buildDashboards')
    .addSeparator()
    .addItem('⚙ Rebuild entire workbook (re-import data)', 'setupWorkbook')
    .addToUi();
}

/* ------------------------------------------------------------------ */
/*  Main setup                                                         */
/* ------------------------------------------------------------------ */

function setupWorkbook() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();

  buildListSheet(ss, SHEET.THERAPIST, THERAPIST_COLUMNS, THERAPIST_ROWS, THERAPIST_DROPDOWNS, 'therapist');
  buildListSheet(ss, SHEET.CLIENT, CLIENT_COLUMNS, CLIENT_ROWS, CLIENT_DROPDOWNS, 'client');

  applyTherapistExtras(ss);
  applyClientExtras(ss);

  recomputeAllMatches();
  buildDashboards();
  reorderSheets(ss);

  ss.toast('Workbook built: ' + THERAPIST_ROWS.length + ' therapists, ' +
           CLIENT_ROWS.length + ' clients.', 'Client Matching', 8);
}

function buildListSheet(ss, name, columns, rows, dropdowns, group) {
  var sh = ss.getSheetByName(name) || ss.insertSheet(name);
  if (sh.getFilter()) sh.getFilter().remove();
  sh.getBandings().forEach(function (b) { b.remove(); });
  sh.clear();
  sh.clearConditionalFormatRules();
  sh.getRange(1, 1, Math.max(1, sh.getMaxRows()), sh.getMaxColumns()).clearDataValidations();

  // Header
  sh.getRange(1, 1, 1, columns.length).setValues([columns])
    .setFontWeight('bold').setFontColor(HEADER_FG).setBackground(HEADER_BG)
    .setVerticalAlignment('middle').setWrap(true);
  sh.setFrozenRows(1);
  sh.setFrozenColumns(1);
  sh.setRowHeight(1, 38);

  // Body — pad each data row to full column count (formula/extra cols stay blank)
  if (rows.length) {
    var body = rows.map(function (r) {
      var out = r.slice(0, columns.length);
      while (out.length < columns.length) out.push('');
      return out;
    });
    sh.getRange(2, 1, body.length, columns.length).setValues(body);
  }
  var lastRow = Math.max(2, rows.length + 1);

  // Wrapping + top alignment so newline multi-values read nicely
  sh.getRange(2, 1, lastRow - 1, columns.length)
    .setVerticalAlignment('top').setWrap(true);

  // Dropdown validation
  var opts = (group === 'therapist') ? THERAPIST_OPTIONS : CLIENT_OPTIONS;
  for (var c = 0; c < columns.length; c++) {
    var header = columns[c];
    if (!dropdowns.hasOwnProperty(header)) continue;
    var list = opts[header];
    if (!list || !list.length) continue;
    var multi = dropdowns[header];
    var rule = SpreadsheetApp.newDataValidation()
      .requireValueInList(list, true)
      .setAllowInvalid(multi)   // multi cells hold newline-joined values → must allow "invalid"
      .setHelpText(multi ? 'Pick one or more (one per line).' : 'Pick one.')
      .build();
    sh.getRange(2, c + 1, Math.max(1, lastRow - 1), 1).setDataValidation(rule);
  }

  // Banded data rows (header keeps its custom navy styling) + filter
  if (lastRow >= 2) {
    sh.getRange(2, 1, lastRow - 1, columns.length).applyRowBanding(
      SpreadsheetApp.BandingTheme.LIGHT_GREY, false, false);
  }
  sh.getRange(1, 1, lastRow, columns.length).createFilter();

  sizeColumns(sh, columns);

  // Polish: clean font, bold name column, subtle gridline color
  sh.getDataRange().setFontFamily('Arial').setFontSize(10);
  sh.getRange(1, 1, 1, columns.length).setFontSize(11);
  var nameIdx = colIndex(columns, 'Name');
  if (nameIdx && lastRow >= 2) {
    sh.getRange(2, nameIdx, lastRow - 1, 1).setFontWeight('bold').setFontColor(HEADER_BG);
  }
  return sh;
}

function colorByValue(sh, columns, header, map) {
  var idx = colIndex(columns, header);
  var last = sh.getLastRow();
  if (!idx || last < 2) return;
  var rng = sh.getRange(2, idx, last - 1, 1);
  var rules = sh.getConditionalFormatRules();
  Object.keys(map).forEach(function (val) {
    var c = map[val];
    rules.push(SpreadsheetApp.newConditionalFormatRule()
      .whenTextEqualTo(val).setBackground(c.bg).setFontColor(c.fg || '#1f2733')
      .setRanges([rng]).build());
  });
  sh.setConditionalFormatRules(rules);
}

function centerColumns(sh, columns, headers) {
  var last = sh.getLastRow();
  if (last < 2) return;
  headers.forEach(function (h) {
    var idx = colIndex(columns, h);
    if (idx) sh.getRange(2, idx, last - 1, 1).setHorizontalAlignment('center');
  });
}

function sizeColumns(sh, columns) {
  var WIDE = { 'Specialities': 260, 'Sub-Specialties': 300,
    'Specialties- Maybe Comfortable Working With': 260,
    'Sub-Specialties- Maybe Comfortable Working With': 300,
    'Matched Therapists': 220, 'Matched Clients': 220, 'Assigned Clients': 160,
    'DOES NOT TAKE': 160, 'Identity (shareable)': 240, 'Enjoys Working With (notes)': 240,
    'Match Details': 280, 'Name': 140 };
  for (var c = 0; c < columns.length; c++) {
    sh.setColumnWidth(c + 1, WIDE[columns[c]] || 130);
  }
}

function applyTherapistExtras(ss) {
  var sh = ss.getSheetByName(SHEET.THERAPIST);
  var last = sh.getLastRow();
  if (last < 2) return;
  var col = colIndex(THERAPIST_COLUMNS, 'Info Added');
  // Info Added -> real checkboxes
  var rng = sh.getRange(2, col, last - 1, 1);
  var vals = rng.getValues().map(function (r) {
    return [String(r[0]).toUpperCase() === 'TRUE'];
  });
  rng.insertCheckboxes();
  rng.setValues(vals);

  // Total Assigned Clients -> live formula counting client rows assigned to this therapist
  var tac = colIndex(THERAPIST_COLUMNS, 'Total Assigned Clients');
  var assignedCol = colLetter(colIndex(CLIENT_COLUMNS, 'Assigned Therapist'));
  var nameColLetter = colLetter(colIndex(THERAPIST_COLUMNS, 'Name'));
  var formulas = [];
  for (var r = 2; r <= last; r++) {
    formulas.push(["=IF($" + nameColLetter + r + "=\"\",\"\",COUNTIF('" + SHEET.CLIENT +
      "'!$" + assignedCol + "$2:$" + assignedCol + ", $" + nameColLetter + r + "))"]);
  }
  sh.getRange(2, tac, last - 1, 1).setFormulas(formulas)
    .setHorizontalAlignment('center').setFontWeight('bold').setFontColor(ACCENT);

  // Status color-coding
  colorByValue(sh, THERAPIST_COLUMNS, 'Accepting Clients?', {
    'Yes': { bg: '#d6f0e0', fg: '#1b5e3f' }, 'No': { bg: '#fbe0de', fg: '#a02b22' }
  });
  colorByValue(sh, THERAPIST_COLUMNS, 'Insurance Accepted?', {
    'Yes': { bg: '#d6f0e0', fg: '#1b5e3f' }, 'No': { bg: '#fbe0de', fg: '#a02b22' }
  });
  colorByValue(sh, THERAPIST_COLUMNS, 'Seniority Level', {
    'Senior': { bg: '#e7e0f7' }, 'Mid.level': { bg: '#dfeaf7' }, 'Junior': { bg: '#fdf0d4' }
  });
  centerColumns(sh, THERAPIST_COLUMNS,
    ['Accepting Clients?', 'Insurance Accepted?', 'Seniority Level', 'Info Added']);
}

function applyClientExtras(ss) {
  var sh = ss.getSheetByName(SHEET.CLIENT);
  var last = sh.getLastRow();
  if (last < 2) return;
  // Format submission date column
  var dCol = colIndex(CLIENT_COLUMNS, 'Submission Date');
  sh.getRange(2, dCol, last - 1, 1).setNumberFormat('yyyy-mm-dd hh:mm');

  // Make "Assigned Therapist" a dropdown of therapist names (one-click reassign on the sheet)
  var names = THERAPIST_ROWS.map(function (r) { return r[0]; })
    .filter(function (n) { return n; }).sort();
  var aIdx = colIndex(CLIENT_COLUMNS, 'Assigned Therapist');
  sh.getRange(2, aIdx, last - 1, 1).setDataValidation(
    SpreadsheetApp.newDataValidation().requireValueInList(names, true).setAllowInvalid(true)
      .setHelpText('Pick the assigned therapist.').build());

  // Light highlight on unassigned rows
  var aCol = colLetter(aIdx);
  var nameCol = colLetter(colIndex(CLIENT_COLUMNS, 'Name'));
  var range = sh.getRange(2, 1, last - 1, CLIENT_COLUMNS.length);
  var rules = sh.getConditionalFormatRules();
  rules.push(SpreadsheetApp.newConditionalFormatRule()
    .whenFormulaSatisfied('=AND($' + nameCol + '2<>"",$' + aCol + '2="")')
    .setBackground('#fff4e5').setRanges([range]).build());
  sh.setConditionalFormatRules(rules);

  colorByValue(sh, CLIENT_COLUMNS, 'New Client', {
    'Yes': { bg: '#d6f0e0', fg: '#1b5e3f' }, 'No': { bg: '#eceff3' }
  });
  colorByValue(sh, CLIENT_COLUMNS, 'Using Insurance', {
    'Yes': { bg: '#d6f0e0', fg: '#1b5e3f' }, 'No': { bg: '#eceff3' }
  });
  centerColumns(sh, CLIENT_COLUMNS, ['New Client', 'Age Category', 'Using Insurance']);
}

function reorderSheets(ss) {
  var order = [SHEET.THERAPIST, SHEET.CLIENT, SHEET.DASH_T, SHEET.DASH_C];
  for (var i = 0; i < order.length; i++) {
    var sh = ss.getSheetByName(order[i]);
    if (sh) { ss.setActiveSheet(sh); ss.moveActiveSheet(i + 1); }
  }
  // Drop the default empty "Sheet1" if present and unused
  var def = ss.getSheetByName('Sheet1');
  if (def && ss.getSheets().length > 1) { try { ss.deleteSheet(def); } catch (e) {} }
  ss.setActiveSheet(ss.getSheetByName(SHEET.CLIENT));
}

/* ------------------------------------------------------------------ */
/*  Matching engine  (Auto + score)                                    */
/* ------------------------------------------------------------------ */

var WEIGHTS = {
  specialty: 3, specialtyMaybe: 2,
  subSpecialty: 3, subSpecialtyMaybe: 2,
  age: 2, therapyType: 2, location: 2, modality: 1,
  insuranceCarrier: 3, insuranceGeneral: 1
};
var MAX_MATCHES_LISTED = 25;

function recomputeAllMatches() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var cSh = ss.getSheetByName(SHEET.CLIENT);
  var tSh = ss.getSheetByName(SHEET.THERAPIST);
  if (!cSh || !tSh) { SpreadsheetApp.getUi().alert('Run "Rebuild entire workbook" first.'); return; }

  var therapists = readObjects(tSh, THERAPIST_COLUMNS);
  var last = cSh.getLastRow();
  if (last < 2) return;

  var matchedCol = colIndex(CLIENT_COLUMNS, 'Matched Therapists');
  var detailCol = colIndex(CLIENT_COLUMNS, 'Match Details');
  var clients = readObjects(cSh, CLIENT_COLUMNS);

  var matchedOut = [], detailOut = [];
  clients.forEach(function (client) {
    var res = matchClient(client, therapists);
    matchedOut.push([res.listText]);
    detailOut.push([res.detailText]);
  });
  cSh.getRange(2, matchedCol, matchedOut.length, 1).setValues(matchedOut).setWrap(true).setVerticalAlignment('top');
  cSh.getRange(2, detailCol, detailOut.length, 1).setValues(detailOut).setWrap(true).setVerticalAlignment('top');
  ss.toast('Recomputed matches for ' + clients.length + ' clients.', 'Client Matching', 5);
}

function recomputeCurrentRow() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var cSh = ss.getActiveSheet();
  if (cSh.getName() !== SHEET.CLIENT) {
    SpreadsheetApp.getUi().alert('Select a row on the "' + SHEET.CLIENT + '" sheet first.');
    return;
  }
  var row = cSh.getActiveRange().getRow();
  if (row < 2) return;
  recomputeRow(cSh, row);
  ss.toast('Recomputed row ' + row + '.', 'Client Matching', 4);
}

function recomputeRow(cSh, row) {
  var ss = cSh.getParent();
  var tSh = ss.getSheetByName(SHEET.THERAPIST);
  var therapists = readObjects(tSh, THERAPIST_COLUMNS);
  var values = cSh.getRange(row, 1, 1, CLIENT_COLUMNS.length).getValues()[0];
  var client = rowToObject(values, CLIENT_COLUMNS);
  var res = matchClient(client, therapists);
  cSh.getRange(row, colIndex(CLIENT_COLUMNS, 'Matched Therapists')).setValue(res.listText).setWrap(true);
  cSh.getRange(row, colIndex(CLIENT_COLUMNS, 'Match Details')).setValue(res.detailText).setWrap(true);
}

function matchClientScored(client, therapists) {
  var scored = [];
  therapists.forEach(function (t) {
    if (!t['Name']) return;
    var m = computeMatch(client, t);
    if (m.eligible) scored.push({ name: t['Name'], score: m.score, reasons: m.reasons });
  });
  scored.sort(function (a, b) { return b.score - a.score || a.name.localeCompare(b.name); });
  return scored;
}

function matchClient(client, therapists) {
  var scored = matchClientScored(client, therapists);
  var top = scored.slice(0, MAX_MATCHES_LISTED);
  var listText = top.map(function (s) { return s.name + ' (' + s.score + ')'; }).join('\n');
  var detailText;
  if (!scored.length) {
    detailText = 'No eligible therapists (check therapy type / age / accepting status).';
  } else {
    var best = scored[0];
    detailText = scored.length + ' eligible. Top: ' + best.name + ' (' + best.score + ') — ' +
      best.reasons.join(', ') + '.';
  }
  return { listText: listText, detailText: detailText };
}

/**
 * Hard filters (must pass to be eligible) + weighted score.
 * Returns { eligible: bool, score: number, reasons: [string] }.
 */
function computeMatch(client, t) {
  var reasons = [];
  var score = 0;

  // ---- HARD FILTERS ----
  // 1. Therapist not explicitly declining new clients
  if (norm(t['Accepting Clients?']) === 'no') return notEligible();

  // 2. Therapy type overlap (only enforced when both sides specify)
  var cType = splitMulti(client['Therapy Type']);
  var tType = splitMulti(t['Therapy (Client) Types']);
  if (cType.length && tType.length && !intersects(cType, tType)) return notEligible();
  if (intersects(cType, tType)) { score += WEIGHTS.therapyType; reasons.push('therapy type'); }

  // 3. Age range (enforced when therapist lists age groups)
  var cAge = norm(client['Age Category']);
  var tAges = splitMulti(t['Age Groups']).map(norm);
  if (cAge && tAges.length && tAges.indexOf(cAge) === -1) return notEligible();
  if (cAge && tAges.indexOf(cAge) !== -1) { score += WEIGHTS.age; reasons.push('age'); }
  // "DOES NOT TAKE" age/issue exclusions (string contains client age label)
  var dnt = splitMulti(t['DOES NOT TAKE']).map(norm);
  if (cAge && dnt.indexOf(cAge) !== -1) return notEligible();

  // 4. Insurance: if client is using insurance, exclude therapists who take none
  var usingIns = norm(client['Using Insurance']) === 'yes';
  if (usingIns && norm(t['Insurance Accepted?']) === 'no') return notEligible();

  // ---- SCORING ----
  // Specialties (primary + "maybe comfortable")
  var cSpec = splitMulti(client['Specialities']).map(norm);
  var n1 = countOverlap(cSpec, splitMulti(t['Specialities']).map(norm));
  var n2 = countOverlap(cSpec, splitMulti(t['Specialties- Maybe Comfortable Working With']).map(norm));
  if (n1) { score += n1 * WEIGHTS.specialty; reasons.push(n1 + ' specialty'); }
  if (n2) { score += n2 * WEIGHTS.specialtyMaybe; reasons.push(n2 + ' specialty(maybe)'); }

  // Sub-specialties (primary + "maybe comfortable")
  var cSub = splitMulti(client['Sub-Specialties']).map(norm);
  var s1 = countOverlap(cSub, splitMulti(t['Sub-Specialties']).map(norm));
  var s2 = countOverlap(cSub, splitMulti(t['Sub-Specialties- Maybe Comfortable Working With']).map(norm));
  if (s1) { score += s1 * WEIGHTS.subSpecialty; reasons.push(s1 + ' sub-specialty'); }
  if (s2) { score += s2 * WEIGHTS.subSpecialtyMaybe; reasons.push(s2 + ' sub-specialty(maybe)'); }

  // Location (office) overlap
  var cLoc = splitMulti(client['Office Location']).map(norm);
  var tLoc = splitMulti(t['Office Location']).map(norm);
  if (intersects(cLoc, tLoc)) { score += WEIGHTS.location; reasons.push('location'); }

  // Modality (virtual / in person) overlap
  var cMod = splitMulti(client['Virtual vs. In Person']).map(norm);
  var tMod = splitMulti(t['Virtual vs. In Person']).map(norm);
  if (intersects(cMod, tMod)) { score += WEIGHTS.modality; reasons.push('modality'); }

  // Insurance carrier match
  if (usingIns) {
    var carrier = norm(client['Insurance Carrier']);
    var tCarriers = splitMulti(t['Insurance Carriers']).map(norm);
    if (carrier && tCarriers.indexOf(carrier) !== -1) {
      score += WEIGHTS.insuranceCarrier; reasons.push('insurance carrier');
    } else if (norm(t['Insurance Accepted?']) === 'yes') {
      score += WEIGHTS.insuranceGeneral; reasons.push('takes insurance');
    }
  }

  return { eligible: true, score: score, reasons: reasons.length ? reasons : ['baseline'] };

  function notEligible() { return { eligible: false, score: 0, reasons: [] }; }
}

/* ------------------------------------------------------------------ */
/*  New Client form  (HTML dialog → append row + live matches)         */
/* ------------------------------------------------------------------ */

function openNewClientForm() {
  var html = HtmlService.createHtmlOutputFromFile('Form')
    .setWidth(1040).setHeight(760).setTitle('New Client Form');
  SpreadsheetApp.getUi().showModalDialog(html, 'New Client Form');
}

// Standalone web-app entry point: Deploy ▸ New deployment ▸ Web app → gives a public URL
// that serves the same New Client Form (intake outside the spreadsheet).
function doGet() {
  return HtmlService.createHtmlOutputFromFile('Form')
    .setTitle('New Client — Just Mind')
    .addMetaTag('viewport', 'width=device-width, initial-scale=1');
}

// Opens an Airtable-style HTML grid of the data (colored chips, sticky header/column).
function openDataView() {
  var html = HtmlService.createHtmlOutputFromFile('DataView')
    .setWidth(1200).setHeight(800).setTitle('Data view');
  SpreadsheetApp.getUi().showModalDialog(html, 'Data view (Airtable-style)');
}

// Field render-type for a column, so the HTML view knows what to draw.
function fieldType(group, header) {
  var multi = (group === 'therapist') ? THERAPIST_DROPDOWNS : CLIENT_DROPDOWNS;
  if (multi.hasOwnProperty(header)) return multi[header] ? 'multi' : 'single';
  var LINKS = { 'Assigned Clients': 1, 'Matched Clients': 1, 'Matched Therapists': 1 };
  if (LINKS.hasOwnProperty(header)) return 'multi';
  if (header === 'Assigned Therapist') return 'single';
  if (header === 'Info Added') return 'checkbox';
  if (header === 'Submission Date') return 'date';
  if (header === 'Total Assigned Clients') return 'number';
  return 'text';
}

// Returns {columns, types, rows} for the data view. which = 'therapist' | 'client'.
function getSheetData(which) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var group = (which === 'therapist') ? 'therapist' : 'client';
  var name = (group === 'therapist') ? SHEET.THERAPIST : SHEET.CLIENT;
  var columns = (group === 'therapist') ? THERAPIST_COLUMNS : CLIENT_COLUMNS;
  var sh = ss.getSheetByName(name);
  if (!sh) throw new Error('Run setup first.');
  var types = columns.map(function (h) { return fieldType(group, h); });

  var last = sh.getLastRow();
  var rows = [];
  if (last >= 2) {
    var values = sh.getRange(2, 1, last - 1, columns.length).getDisplayValues();
    var raw = sh.getRange(2, 1, last - 1, columns.length).getValues();
    for (var r = 0; r < values.length; r++) {
      if (!String(raw[r][0]).trim()) continue;  // skip blank rows
      var rec = [];
      for (var c = 0; c < columns.length; c++) {
        var t = types[c];
        if (t === 'multi') rec.push(splitMulti(raw[r][c]));
        else if (t === 'checkbox') rec.push(raw[r][c] === true);
        else rec.push(values[r][c]);   // display value (formatted dates/numbers)
      }
      rows.push(rec);
    }
  }
  return { which: group, title: name, columns: columns, types: types, rows: rows };
}

// Reassign: write a chosen therapist into a client row's "Assigned Therapist".
// Called from the form results ("Assign") and usable directly.
function assignTherapist(rowNumber, therapistName) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var cSh = ss.getSheetByName(SHEET.CLIENT);
  if (!cSh) throw new Error('No "' + SHEET.CLIENT + '" sheet — run setup first.');
  cSh.getRange(rowNumber, colIndex(CLIENT_COLUMNS, 'Assigned Therapist')).setValue(therapistName);
  return { ok: true, rowNumber: rowNumber, therapist: therapistName };
}

// Served to the HTML form so its dropdowns use the exact same option lists.
function getClientFormOptions() {
  return CLIENT_OPTIONS;
}

/**
 * Called by Form.html on submit. Appends a Client Request Submission, scores
 * therapists, writes the results back to the row, and returns the matches.
 * payload = { name, newClient, therapyType[], ageCategory, specialities[],
 *             subSpecialties[], availability[], virtual[], usingInsurance,
 *             insuranceCarrier, officeLocation, submissionDate(ISO string) }
 */
function submitClientForm(payload) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var cSh = ss.getSheetByName(SHEET.CLIENT);
  if (!cSh) throw new Error('Run "Rebuild entire workbook" first.');

  var name = (payload.name || '').trim();
  if (!name) throw new Error('Name is required.');

  var join = function (a) { return (a && a.length) ? a.join('\n') : ''; };
  var when = payload.submissionDate ? new Date(payload.submissionDate) : new Date();

  // Build the client object (used for matching) then the row (sheet order).
  var client = {
    'Name': name,
    'Submission Date': when,
    'New Client': payload.newClient || '',
    'Therapy Type': join(payload.therapyType),
    'Age Category': payload.ageCategory || '',
    'Specialities': join(payload.specialities),
    'Sub-Specialties': join(payload.subSpecialties),
    'Virtual vs. In Person': join(payload.virtual),
    'Office Location': payload.officeLocation || '',
    'Using Insurance': payload.usingInsurance || '',
    'Insurance Carrier': payload.insuranceCarrier || '',
    'Availability': join(payload.availability),
    'Assigned Therapist': '',
    'Matched Therapists': '',
    'Match Details': ''
  };

  var therapists = readObjects(ss.getSheetByName(SHEET.THERAPIST), THERAPIST_COLUMNS);
  var scored = matchClientScored(client, therapists);
  var top = scored.slice(0, MAX_MATCHES_LISTED);
  client['Matched Therapists'] = top.map(function (s) { return s.name + ' (' + s.score + ')'; }).join('\n');
  client['Match Details'] = scored.length
    ? scored.length + ' eligible. Top: ' + scored[0].name + ' (' + scored[0].score + ') — ' + scored[0].reasons.join(', ') + '.'
    : 'No eligible therapists (check therapy type / age / accepting status).';

  // Write the row in column order.
  var row = CLIENT_COLUMNS.map(function (h) { return client[h]; });
  var target = cSh.getLastRow() + 1;
  cSh.getRange(target, 1, 1, CLIENT_COLUMNS.length).setValues([row]);
  cSh.getRange(target, colIndex(CLIENT_COLUMNS, 'Submission Date')).setNumberFormat('yyyy-mm-dd hh:mm');
  cSh.getRange(target, 1, 1, CLIENT_COLUMNS.length).setVerticalAlignment('top').setWrap(true);

  return {
    rowNumber: target,
    eligibleCount: scored.length,
    matches: scored.slice(0, 15)   // {name, score, reasons[]}
  };
}

/* ------------------------------------------------------------------ */
/*  Dashboards                                                         */
/* ------------------------------------------------------------------ */

function buildDashboards() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  buildTherapistDashboard(ss);
  buildClientDashboard(ss);
  ss.toast('Dashboards refreshed.', 'Client Matching', 4);
}

function buildTherapistDashboard(ss) {
  var sh = resetSheet(ss, SHEET.DASH_T);
  var T = "'" + SHEET.THERAPIST + "'";
  var nameCol = colLetter(colIndex(THERAPIST_COLUMNS, 'Name'));
  var accCol = colLetter(colIndex(THERAPIST_COLUMNS, 'Accepting Clients?'));
  var senCol = colLetter(colIndex(THERAPIST_COLUMNS, 'Seniority Level'));
  var insCol = colLetter(colIndex(THERAPIST_COLUMNS, 'Insurance Accepted?'));

  title(sh, 'Therapist Metrics');

  bigNumber(sh, 3, 1, 'Total Therapists', '=COUNTA(' + T + '!' + nameCol + '2:' + nameCol + ')');
  bigNumber(sh, 3, 3, 'Currently Accepting Clients',
    '=COUNTIF(' + T + '!' + accCol + '2:' + accCol + ',"Yes")');
  bigNumber(sh, 3, 5, 'Accepting Insurance',
    '=COUNTIF(' + T + '!' + insCol + '2:' + insCol + ',"Yes")');

  // Breakdown: Accepting status
  sectionHeader(sh, 7, 1, 'By Accepting Status');
  sh.getRange(8, 1).setFormula(
    '=QUERY(' + T + '!' + accCol + '2:' + accCol + ',"select ' + accCol +
    ', count(' + accCol + ') where ' + accCol + " is not null group by " + accCol +
    ' order by count(' + accCol + ') desc label ' + accCol + " 'Accepting?', count(" + accCol + ") 'Therapists'\",0)");

  // Breakdown: Seniority
  sectionHeader(sh, 7, 4, 'By Seniority Level');
  sh.getRange(8, 4).setFormula(
    '=QUERY(' + T + '!' + senCol + '2:' + senCol + ',"select ' + senCol +
    ', count(' + senCol + ') where ' + senCol + " is not null group by " + senCol +
    ' order by count(' + senCol + ') desc label ' + senCol + " 'Seniority', count(" + senCol + ") 'Therapists'\",0)");

  // Chart: accepting status
  SpreadsheetApp.flush();
  addPieChart(sh, sh.getRange(8, 1, 6, 2), 'Accepting New Clients', 1, 7);

  styleDashboard(sh);
}

function buildClientDashboard(ss) {
  var sh = resetSheet(ss, SHEET.DASH_C);
  var C = "'" + SHEET.CLIENT + "'";
  var nameCol = colLetter(colIndex(CLIENT_COLUMNS, 'Name'));
  var newCol = colLetter(colIndex(CLIENT_COLUMNS, 'New Client'));
  var ageCol = colLetter(colIndex(CLIENT_COLUMNS, 'Age Category'));
  var locCol = colLetter(colIndex(CLIENT_COLUMNS, 'Office Location'));
  var insCol = colLetter(colIndex(CLIENT_COLUMNS, 'Using Insurance'));
  var assignCol = colLetter(colIndex(CLIENT_COLUMNS, 'Assigned Therapist'));

  title(sh, 'Client Submissions Dashboard');

  bigNumber(sh, 3, 1, 'Total Submissions', '=COUNTA(' + C + '!' + nameCol + '2:' + nameCol + ')');
  bigNumber(sh, 3, 3, 'New Clients', '=COUNTIF(' + C + '!' + newCol + '2:' + newCol + ',"Yes")');
  bigNumber(sh, 3, 5, 'Assigned',
    '=COUNTIF(' + C + '!' + assignCol + '2:' + assignCol + ',"<>")');
  bigNumber(sh, 3, 7, 'Unassigned',
    '=COUNTA(' + C + '!' + nameCol + '2:' + nameCol + ')-COUNTIF(' + C + '!' + assignCol + '2:' + assignCol + ',"<>")');

  sectionHeader(sh, 7, 1, 'By Age Category');
  sh.getRange(8, 1).setFormula(
    '=QUERY(' + C + '!' + ageCol + '2:' + ageCol + ',"select ' + ageCol +
    ', count(' + ageCol + ') where ' + ageCol + " is not null group by " + ageCol +
    ' order by count(' + ageCol + ') desc label ' + ageCol + " 'Age', count(" + ageCol + ") 'Clients'\",0)");

  sectionHeader(sh, 7, 4, 'By Office Location');
  sh.getRange(8, 4).setFormula(
    '=QUERY(' + C + '!' + locCol + '2:' + locCol + ',"select ' + locCol +
    ', count(' + locCol + ') where ' + locCol + " is not null group by " + locCol +
    ' order by count(' + locCol + ') desc label ' + locCol + " 'Location', count(" + locCol + ") 'Clients'\",0)");

  sectionHeader(sh, 7, 7, 'Using Insurance?');
  sh.getRange(8, 7).setFormula(
    '=QUERY(' + C + '!' + insCol + '2:' + insCol + ',"select ' + insCol +
    ', count(' + insCol + ') where ' + insCol + " is not null group by " + insCol +
    ' order by count(' + insCol + ') desc label ' + insCol + " 'Using Insurance', count(" + insCol + ") 'Clients'\",0)");

  SpreadsheetApp.flush();
  addColumnChart(sh, sh.getRange(8, 1, 8, 2), 'Clients by Age', 1, 7);

  styleDashboard(sh);
}

/* ---- dashboard helpers ---- */

function resetSheet(ss, name) {
  var sh = ss.getSheetByName(name) || ss.insertSheet(name);
  sh.getCharts().forEach(function (c) { sh.removeChart(c); });
  sh.getRange(1, 1, sh.getMaxRows(), sh.getMaxColumns()).breakApart();
  sh.clear();
  sh.setHiddenGridlines(true);
  return sh;
}
function title(sh, text) {
  sh.getRange(1, 1, 1, 8).merge().setValue(text)
    .setFontSize(18).setFontWeight('bold').setFontColor('#ffffff').setBackground(HEADER_BG)
    .setHorizontalAlignment('left').setVerticalAlignment('middle');
  sh.setRowHeight(1, 44);
}
function bigNumber(sh, row, col, label, formula) {
  sh.getRange(row, col, 1, 2).merge().setValue(label)
    .setFontWeight('bold').setFontColor('#5b6b7b').setBackground(BANDING)
    .setHorizontalAlignment('center');
  sh.getRange(row + 1, col, 1, 2).merge().setFormula(formula)
    .setFontSize(30).setFontWeight('bold').setFontColor(ACCENT).setBackground(BANDING)
    .setHorizontalAlignment('center');
  sh.setRowHeight(row + 1, 52);
}
function sectionHeader(sh, row, col, text) {
  sh.getRange(row, col, 1, 2).merge().setValue(text)
    .setFontWeight('bold').setFontColor('#ffffff').setBackground(ACCENT)
    .setHorizontalAlignment('left');
}
function addPieChart(sh, range, name, anchorCol, anchorRow) {
  var chart = sh.newChart().asPieChart().addRange(range)
    .setPosition(anchorRow + 8, anchorCol, 0, 0)
    .setOption('title', name).setOption('width', 360).setOption('height', 240)
    .setNumHeaders(1).build();
  sh.insertChart(chart);
}
function addColumnChart(sh, range, name, anchorCol, anchorRow) {
  var chart = sh.newChart().asColumnChart().addRange(range)
    .setPosition(anchorRow + 8, anchorCol, 0, 0)
    .setOption('title', name).setOption('width', 460).setOption('height', 260)
    .setOption('legend', { position: 'none' }).setNumHeaders(1).build();
  sh.insertChart(chart);
}
function styleDashboard(sh) {
  sh.setColumnWidths(1, 8, 120);
  sh.getRange('A1').setFontFamily('Arial');
}

/* ------------------------------------------------------------------ */
/*  Auto-match on edit                                                 */
/* ------------------------------------------------------------------ */

var MATCH_TRIGGER_COLUMNS = ['Therapy Type', 'Age Category', 'Specialities', 'Sub-Specialties',
  'Virtual vs. In Person', 'Office Location', 'Using Insurance', 'Insurance Carrier'];

function onEdit(e) {
  try {
    if (!e || !e.range) return;
    var sh = e.range.getSheet();
    if (sh.getName() !== SHEET.CLIENT) return;
    var row = e.range.getRow();
    if (row < 2) return;
    var editedCol = e.range.getColumn();
    var triggerCols = MATCH_TRIGGER_COLUMNS.map(function (h) { return colIndex(CLIENT_COLUMNS, h); });
    // Re-run if the edit touched any criteria column (or a multi-cell paste)
    var touched = false;
    for (var c = editedCol; c < editedCol + e.range.getNumColumns(); c++) {
      if (triggerCols.indexOf(c) !== -1) { touched = true; break; }
    }
    if (!touched) return;
    recomputeRow(sh, row);
  } catch (err) {
    // never let onEdit throw
  }
}

/* ------------------------------------------------------------------ */
/*  Small utilities                                                    */
/* ------------------------------------------------------------------ */

function colIndex(columns, header) { return columns.indexOf(header) + 1; } // 1-based
function colLetter(idx1) {          // 1-based index -> A1 letter
  var s = '', n = idx1;
  while (n > 0) { var m = (n - 1) % 26; s = String.fromCharCode(65 + m) + s; n = Math.floor((n - 1) / 26); }
  return s;
}
function norm(v) { return String(v == null ? '' : v).trim().toLowerCase(); }
function splitMulti(v) {
  if (v == null) return [];
  return String(v).split('\n').map(function (x) { return x.trim(); }).filter(function (x) { return x.length; });
}
function intersects(a, b) {
  for (var i = 0; i < a.length; i++) if (b.indexOf(a[i]) !== -1) return true;
  return false;
}
function countOverlap(a, b) {
  var n = 0;
  for (var i = 0; i < a.length; i++) if (b.indexOf(a[i]) !== -1) n++;
  return n;
}
function readObjects(sh, columns) {
  var last = sh.getLastRow();
  if (last < 2) return [];
  var values = sh.getRange(2, 1, last - 1, columns.length).getValues();
  return values.map(function (row) { return rowToObject(row, columns); });
}
function rowToObject(row, columns) {
  var o = {};
  for (var i = 0; i < columns.length; i++) o[columns[i]] = row[i];
  return o;
}
