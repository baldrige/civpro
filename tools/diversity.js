// Diversity jurisdiction checker (28 U.S.C. § 1332). Used by the "Try It"
// box in subject_matter_jurisdiction.qmd. Plain JavaScript, HTML only.
// A teaching tool: it covers individuals, corporations, unincorporated
// entities, and legal representatives, but not class actions under CAFA,
// direct actions against insurers, or suits by foreign states.
(function () {
  "use strict";

  const STATES = ["Alabama", "Alaska", "Arizona", "Arkansas", "California", "Colorado",
    "Connecticut", "Delaware", "District of Columbia", "Florida", "Georgia", "Hawaii", "Idaho",
    "Illinois", "Indiana", "Iowa", "Kansas", "Kentucky", "Louisiana", "Maine", "Maryland",
    "Massachusetts", "Michigan", "Minnesota", "Mississippi", "Missouri", "Montana", "Nebraska",
    "Nevada", "New Hampshire", "New Jersey", "New Mexico", "New York", "North Carolina",
    "North Dakota", "Ohio", "Oklahoma", "Oregon", "Pennsylvania", "Puerto Rico",
    "Rhode Island", "South Carolina", "South Dakota", "Tennessee", "Texas", "Utah", "Vermont",
    "Virginia", "Washington", "West Virginia", "Wisconsin", "Wyoming",
    "Guam", "U.S. Virgin Islands", "Northern Mariana Islands", "American Samoa"];
  const ABBR = { AL: "Alabama", AK: "Alaska", AZ: "Arizona", AR: "Arkansas", CA: "California",
    CO: "Colorado", CT: "Connecticut", DE: "Delaware", DC: "District of Columbia", FL: "Florida",
    GA: "Georgia", HI: "Hawaii", ID: "Idaho", IL: "Illinois", IN: "Indiana", IA: "Iowa",
    KS: "Kansas", KY: "Kentucky", LA: "Louisiana", ME: "Maine", MD: "Maryland",
    MA: "Massachusetts", MI: "Michigan", MN: "Minnesota", MS: "Mississippi", MO: "Missouri",
    MT: "Montana", NE: "Nebraska", NV: "Nevada", NH: "New Hampshire", NJ: "New Jersey",
    NM: "New Mexico", NY: "New York", NC: "North Carolina", ND: "North Dakota", OH: "Ohio",
    OK: "Oklahoma", OR: "Oregon", PA: "Pennsylvania", PR: "Puerto Rico", RI: "Rhode Island",
    SC: "South Carolina", SD: "South Dakota", TN: "Tennessee", TX: "Texas", UT: "Utah",
    VT: "Vermont", VA: "Virginia", WA: "Washington", WV: "West Virginia", WI: "Wisconsin",
    WY: "Wyoming", GU: "Guam", VI: "U.S. Virgin Islands", MP: "Northern Mariana Islands",
    AS: "American Samoa" };
  const ABROAD = "__abroad";
  const FOREIGN = "__foreign";

  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  const list = (xs) => xs.length <= 1 ? xs.join("") : xs.length === 2 ? xs.join(" and ") : xs.slice(0, -1).join(", ") + ", and " + xs[xs.length - 1];

  function stateOf(token) {
    const t = token.trim();
    if (!t) return null;
    if (ABBR[t.toUpperCase()]) return ABBR[t.toUpperCase()];
    const hit = STATES.find((s) => s.toLowerCase() === t.toLowerCase());
    return hit || null;
  }

  // A party's citizenship: the States it is a citizen of, whether it is (or
  // includes) a citizen or subject of a foreign state, whether it is
  // "stateless," and the reasoning, one line per rule applied.
  function citizenship(p) {
    const c = { states: new Set(), alien: false, stateless: false, lpr: null, why: [] };
    const name = p.name || "This party";
    if (p.type === "individual" || p.type === "representative") {
      const who = p.type === "representative" ? "the person represented" : name;
      if (p.type === "representative") c.why.push(`A legal representative of an estate, infant, or incompetent is deemed a citizen only of the same State as ${p.estate ? "the decedent" : "the infant or incompetent"} (§ 1332(c)(2)).`);
      if (p.nationality === "us") {
        if (p.domicile === ABROAD) {
          c.stateless = true;
          c.why.push(`${who} is a U.S. citizen domiciled abroad: a citizen of no State and not an alien, so ${p.type === "representative" ? "the representative" : "this party"} can't be a party to a diversity suit.`);
        } else {
          c.states.add(p.domicile);
          c.why.push(`${who} is a U.S. citizen domiciled in ${p.domicile}, so a citizen of ${p.domicile}. Domicile is where one lives with the intent to remain indefinitely.`);
        }
      } else {
        c.alien = true;
        if (p.nationality === "lpr" && p.domicile !== ABROAD) {
          c.lpr = p.domicile;
          c.why.push(`${who} is a citizen of a foreign state admitted for permanent residence and domiciled in ${p.domicile}. ${p.type === "representative" ? "The representative" : "This party"} counts as an alien, but § 1332(a)(2) doesn't reach a suit between this party and a citizen of ${p.domicile}.`);
        } else {
          c.why.push(`${who} is a citizen or subject of a foreign state (an alien).`);
        }
      }
    } else if (p.type === "corporation") {
      for (const [place, label] of [[p.inc, "incorporated"], [p.ppb, "has its principal place of business"]]) {
        if (place === FOREIGN) c.alien = true;
        else c.states.add(place);
      }
      const incTxt = p.inc === FOREIGN ? "a foreign country" : p.inc;
      const ppbTxt = p.ppb === FOREIGN ? "a foreign country" : p.ppb;
      c.why.push(`A corporation is a citizen of every State and foreign state where it is incorporated and of the State or foreign state where it has its principal place of business (§ 1332(c)(1)); under *Hertz*, that is its \"nerve center.\" ${name} is incorporated in ${incTxt} with its principal place of business in ${ppbTxt}.`);
    } else if (p.type === "entity") {
      const members = (p.members || "").split(/[,;]+/).map((s) => s.trim()).filter(Boolean);
      const bad = [];
      for (const m of members) {
        if (/^abroad$/i.test(m) || /domiciled abroad/i.test(m)) c.stateless = true;
        else if (stateOf(m)) c.states.add(stateOf(m));
        else c.alien = true;
        if (!stateOf(m) && !/abroad/i.test(m)) bad.push(m);
      }
      c.why.push(`An unincorporated entity (a partnership, LLC, union, or other association) is a citizen of every State and foreign state of which any of its members is a citizen.${members.length ? "" : " Enter the members' citizenships."}`);
      if (bad.length) c.why.push(`Treated as foreign: ${list(bad.map((b) => `"${b}"`))}. (Enter U.S. members by State name or postal abbreviation.)`);
      if (c.stateless) c.why.push("A member who is a U.S. citizen domiciled abroad makes the entity stateless for diversity purposes.");
    }
    return c;
  }

  function describe(c) {
    const parts = [...c.states];
    if (c.alien) parts.push("a foreign state");
    if (c.stateless) return "stateless (a U.S. citizen domiciled abroad)";
    return parts.length ? list(parts) : "(not yet entered)";
  }

  function analyze(parties, opts) {
    const P = parties.filter((p) => p.side === "P").map((p) => ({ p, c: citizenship(p) }));
    const D = parties.filter((p) => p.side === "D").map((p) => ({ p, c: citizenship(p) }));
    const out = { ok: true, lines: [], parties: [...P, ...D] };
    const no = (msg) => { out.ok = false; out.lines.push(["no", msg]); };
    const yes = (msg) => out.lines.push(["yes", msg]);
    const note = (msg) => out.lines.push(["note", msg]);

    if (!P.length || !D.length) { out.ok = false; out.lines.push(["note", "Add at least one plaintiff and one defendant."]); return out; }

    const stateless = out.parties.filter((x) => x.c.stateless);
    if (stateless.length) no(`${list(stateless.map((x) => x.p.name))} ${stateless.length > 1 ? "are" : "is"} stateless for diversity purposes. A U.S. citizen domiciled abroad is neither a citizen of a State nor an alien, so § 1332 doesn't cover the suit.`);

    // Complete diversity among the parties' State citizenships (Strawbridge).
    const shared = [];
    for (const a of P) for (const b of D) for (const s of a.c.states) if (b.c.states.has(s)) shared.push(`${a.p.name} and ${b.p.name} are both citizens of ${s}`);
    if (shared.length) no(`Complete diversity fails: ${list(shared)}. Under *Strawbridge v. Curtiss*, no plaintiff may be a citizen of the same State as any defendant.`);

    const anyState = (side) => side.some((x) => x.c.states.size > 0);
    const anyAlien = (side) => side.some((x) => x.c.alien);
    const allPureAlien = (side) => side.every((x) => x.c.alien && x.c.states.size === 0);
    const allPureState = (side) => side.every((x) => !x.c.alien && x.c.states.size > 0);

    if (out.ok) {
      if (!anyAlien(P) && !anyAlien(D)) {
        yes("Every party is a citizen of a State, and no State is on both sides. This is a suit between \"citizens of different States\" (§ 1332(a)(1)).");
      } else if ((allPureState(P) && allPureAlien(D)) || (allPureAlien(P) && allPureState(D))) {
        const [st, al] = allPureState(P) ? [P, D] : [D, P];
        const lprClash = [];
        for (const a of al) if (a.c.lpr) for (const s of st) if (s.c.states.has(a.c.lpr)) lprClash.push(`${a.p.name} (a permanent resident domiciled in ${a.c.lpr}) and ${s.p.name} (a citizen of ${a.c.lpr})`);
        if (lprClash.length) no(`This would be alienage jurisdiction, but § 1332(a)(2) excludes a suit between a citizen of a State and a permanent resident alien domiciled in the same State: ${list(lprClash)}.`);
        else yes("Citizens of a State are on one side and citizens or subjects of a foreign state are on the other. This is alienage jurisdiction (§ 1332(a)(2)).");
      } else if (anyState(P) && anyState(D)) {
        const bothAlien = anyAlien(P) && anyAlien(D);
        yes(`Citizens of different States are on both sides, with aliens as additional parties (§ 1332(a)(3)).${bothAlien ? " Aliens appear on both sides. Most courts allow that under (a)(3) as long as the State citizens are completely diverse." : ""}`);
      } else {
        no("Aliens are on both sides of the case without diverse State citizens on each side. Section 1332 doesn't cover a suit between aliens, even if one of them is also a citizen of a State (such as a corporation incorporated abroad with its principal place of business here), unless § 1332(a)(3) applies.");
      }
    }

    // Amount in controversy.
    const amounts = P.map((x) => ({ x, amt: x.p.amount }));
    const entered = amounts.filter((a) => a.amt !== null);
    if (!entered.length) {
      note("Enter each plaintiff's amount in controversy to check § 1332(a)'s requirement that it exceed $75,000.");
    } else {
      const over = entered.filter((a) => a.amt > 75000);
      const under = entered.filter((a) => a.amt <= 75000);
      if (!over.length) {
        no(`No plaintiff's claim exceeds $75,000, exclusive of interest and costs. (Exactly $75,000 isn't enough.) Separate plaintiffs can't add their claims together to reach the amount.`);
      } else if (under.length) {
        const msg = `${list(over.map((a) => a.x.p.name))} ${over.length > 1 ? "claim" : "claims"} more than $75,000, but ${list(under.map((a) => a.x.p.name))} ${under.length > 1 ? "do" : "does"} not.`;
        if (out.ok) yes(`${msg} Under *Exxon Mobil Corp. v. Allapattah Services*, if at least one plaintiff satisfies the amount and diversity is complete, § 1367 gives supplemental jurisdiction over the other plaintiffs' smaller claims arising from the same case or controversy.`);
        else note(msg);
      } else {
        yes(`Each plaintiff claims more than $75,000, exclusive of interest and costs. (A single plaintiff may add together all of her claims against a single defendant.)`);
      }
      if (entered.length < amounts.length) note("Some plaintiffs' amounts are blank.");
    }

    // Removal and the forum-defendant rule.
    if (opts.removedFrom) {
      const forum = D.filter((x) => x.c.states.has(opts.removedFrom));
      if (!out.ok) note(`The case couldn't be removed from ${opts.removedFrom} state court on the basis of diversity, because it couldn't have been filed in federal court originally (§ 1441(a)).`);
      else if (forum.length) no(`Removal from ${opts.removedFrom} state court is barred by the forum-defendant rule: ${list(forum.map((x) => x.p.name))} ${forum.length > 1 ? "are citizens" : "is a citizen"} of ${opts.removedFrom} (§ 1441(b)(2)). The rule applies only to defendants \"properly joined and served,\" and the plaintiff can waive it by not moving to remand within 30 days (§ 1447(c)).`);
      else yes(`No defendant is a citizen of ${opts.removedFrom}, so the forum-defendant rule doesn't block removal (§ 1441(b)(2)).`);
    }
    return out;
  }

  const EXAMPLES = {
    strawbridge: { label: "The Strawbridge self-check (New York and New Jersey v. Connecticut and New Jersey)", removedFrom: "", parties: [
      { side: "P", name: "P1", type: "individual", nationality: "us", domicile: "New York", amount: 200000 },
      { side: "P", name: "P2", type: "individual", nationality: "us", domicile: "New Jersey", amount: 200000 },
      { side: "D", name: "D1", type: "individual", nationality: "us", domicile: "Connecticut", amount: null },
      { side: "D", name: "D2", type: "individual", nationality: "us", domicile: "New Jersey", amount: null }] },
    mas: { label: "Mas v. Perry", removedFrom: "", parties: [
      { side: "P", name: "Mrs. Mas", type: "individual", nationality: "us", domicile: "Mississippi", amount: null },
      { side: "P", name: "Mr. Mas", type: "individual", nationality: "alien", domicile: ABROAD, amount: null },
      { side: "D", name: "Perry", type: "individual", nationality: "us", domicile: "Louisiana", amount: null }] },
    hertz: { label: "Hertz Corp. v. Friend", removedFrom: "California", parties: [
      { side: "P", name: "Friend", type: "individual", nationality: "us", domicile: "California", amount: null },
      { side: "D", name: "Hertz", type: "corporation", inc: "Delaware", ppb: "New Jersey", amount: null }] },
  };

  function placeOptions(selected, extra) {
    let html = extra.map(([v, l]) => `<option value="${v}"${v === selected ? " selected" : ""}>${l}</option>`).join("");
    html += STATES.map((s) => `<option${s === selected ? " selected" : ""}>${s}</option>`).join("");
    return html;
  }

  function init(root) {
    const rows = root.querySelector(".dv-parties");
    const result = root.querySelector(".dv-result");
    const removed = root.querySelector(".dv-removed");
    removed.innerHTML = placeOptions("", [["", "Filed in federal court"]]).replace(/<option>/g, "<option>");
    let parties = [];
    let nextId = 1;

    function fields(p) {
      const id = `dv${p.id}`;
      if (p.type === "corporation") {
        return `<label>Incorporated in <select class="form-select form-select-sm" data-k="inc">${placeOptions(p.inc, [[FOREIGN, "A foreign country"]])}</select></label>
          <label>Principal place of business <select class="form-select form-select-sm" data-k="ppb">${placeOptions(p.ppb, [[FOREIGN, "A foreign country"]])}</select></label>`;
      }
      if (p.type === "entity") {
        return `<label class="dv-wide">Members' citizenships <input class="form-control form-control-sm" data-k="members" placeholder="e.g., Texas, NY, France" value="${esc(p.members || "")}"></label>`;
      }
      const whose = p.type === "representative" ? `<label>Represents <select class="form-select form-select-sm" data-k="estate"><option value="1"${p.estate ? " selected" : ""}>a decedent's estate</option><option value=""${p.estate ? "" : " selected"}>an infant or incompetent</option></select></label>` : "";
      const subj = p.type === "representative" ? "That person is" : "Citizenship";
      return `${whose}<label>${subj} <select class="form-select form-select-sm" data-k="nationality">
          <option value="us"${p.nationality === "us" ? " selected" : ""}>U.S. citizen</option>
          <option value="alien"${p.nationality === "alien" ? " selected" : ""}>Foreign citizen</option>
          <option value="lpr"${p.nationality === "lpr" ? " selected" : ""}>Foreign citizen, permanent resident</option></select></label>
        <label>Domiciled in <select class="form-select form-select-sm" data-k="domicile">${placeOptions(p.domicile, [[ABROAD, "Outside the United States"]])}</select></label>`;
    }

    function render() {
      rows.innerHTML = "";
      for (const p of parties) {
        const div = document.createElement("div");
        div.className = "dv-party";
        div.innerHTML = `<div class="dv-row">
            <select class="form-select form-select-sm dv-side" data-k="side" aria-label="Side"><option value="P"${p.side === "P" ? " selected" : ""}>Plaintiff</option><option value="D"${p.side === "D" ? " selected" : ""}>Defendant</option></select>
            <input class="form-control form-control-sm dv-name" data-k="name" value="${esc(p.name)}" aria-label="Name">
            <select class="form-select form-select-sm" data-k="type" aria-label="Kind of party">
              <option value="individual"${p.type === "individual" ? " selected" : ""}>Individual</option>
              <option value="corporation"${p.type === "corporation" ? " selected" : ""}>Corporation</option>
              <option value="entity"${p.type === "entity" ? " selected" : ""}>Partnership, LLC, or association</option>
              <option value="representative"${p.type === "representative" ? " selected" : ""}>Legal representative</option></select>
            <button type="button" class="btn btn-sm btn-outline-secondary dv-remove" aria-label="Remove ${esc(p.name)}">Remove</button>
          </div>
          <div class="dv-row dv-fields">${fields(p)}${p.side === "P" ? `<label>Amount claimed ($) <input class="form-control form-control-sm" data-k="amount" inputmode="numeric" value="${p.amount === null ? "" : p.amount}"></label>` : ""}</div>`;
        div.querySelectorAll("[data-k]").forEach((el) => {
          el.addEventListener(el.tagName === "INPUT" ? "input" : "change", () => {
            const k = el.dataset.k;
            let v = el.value;
            if (k === "amount") { const n = parseFloat(v.replace(/[$,\s]/g, "")); v = isNaN(n) ? null : n; }
            if (k === "estate") v = !!v;
            p[k] = v;
            if (k === "type" || k === "side") { defaults(p); render(); } else update();
          });
        });
        div.querySelector(".dv-remove").addEventListener("click", () => { parties = parties.filter((q) => q !== p); render(); });
        rows.appendChild(div);
      }
      update();
    }

    function defaults(p) {
      p.nationality = p.nationality || "us";
      p.domicile = p.domicile || "Texas";
      p.inc = p.inc || "Delaware";
      p.ppb = p.ppb || "New York";
      if (p.amount === undefined) p.amount = null;
      if (p.estate === undefined) p.estate = true;
    }

    function add(side) {
      const n = parties.filter((p) => p.side === side).length + 1;
      const p = { id: nextId++, side, name: `${side === "P" ? "Plaintiff" : "Defendant"} ${n}`, type: "individual" };
      defaults(p);
      parties.push(p);
      render();
    }

    function load(key) {
      const ex = EXAMPLES[key];
      parties = ex.parties.map((p) => { const q = { ...p, id: nextId++ }; defaults(q); return q; });
      removed.value = ex.removedFrom;
      render();
    }

    function update() {
      const r = analyze(parties, { removedFrom: removed.value });
      const icon = { yes: "✓", no: "✗", note: "•" };
      const verdict = !parties.some((p) => p.side === "P") || !parties.some((p) => p.side === "D") ? "" :
        r.ok ? `<p class="dv-verdict dv-ok"><strong>Diversity jurisdiction${removed.value ? " and removal" : ""}: satisfied${r.lines.some((l) => l[1].startsWith("Enter each plaintiff")) ? " (once the amount is shown)" : ""}.</strong></p>`
             : `<p class="dv-verdict dv-bad"><strong>${removed.value && r.lines.filter((l) => l[0] === "no").every((l) => l[1].startsWith("Removal")) ? "Removal is barred." : "No diversity jurisdiction."}</strong></p>`;
      result.innerHTML = verdict +
        `<ul class="dv-lines">${r.lines.map(([k, m]) => `<li class="dv-${k}"><span aria-hidden="true">${icon[k]}</span> ${md(m)}</li>`).join("")}</ul>` +
        `<details><summary>Each party's citizenship</summary><ul>${r.parties.map((x) => `<li><strong>${esc(x.p.name)}</strong> (${x.p.side === "P" ? "plaintiff" : "defendant"}): ${esc(describe(x.c))}. ${x.c.why.map(md).join(" ")}</li>`).join("")}</ul></details>`;
    }

    const md = (s) => esc(s).replace(/\*([^*]+)\*/g, "<em>$1</em>").replace(/\\&quot;/g, "&quot;");

    root.querySelector(".dv-add-p").addEventListener("click", () => add("P"));
    root.querySelector(".dv-add-d").addEventListener("click", () => add("D"));
    removed.addEventListener("change", update);
    const exSel = root.querySelector(".dv-example");
    for (const [k, ex] of Object.entries(EXAMPLES)) {
      const o = document.createElement("option");
      o.value = k;
      o.textContent = ex.label;
      exSel.appendChild(o);
    }
    exSel.addEventListener("change", () => { if (exSel.value) load(exSel.value); });
    add("P");
    add("D");
  }

  if (typeof module !== "undefined") module.exports = { analyze, citizenship };
  if (typeof document !== "undefined") {
    const start = () => document.querySelectorAll(".diversity-checker").forEach(init);
    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start);
    else start();
  }
})();
