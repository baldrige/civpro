// Rule 6(a) deadline calculator. Used by the "Try It" box in frcp.qmd.
// Plain JavaScript, no dependencies; HTML output only.
(function () {
  "use strict";

  const DAY = 86400000;
  const WEEKDAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
  const MONTHS = ["January", "February", "March", "April", "May", "June", "July",
    "August", "September", "October", "November", "December"];

  // Dates are UTC midnights, so daylight saving time never shifts a day.
  const utc = (y, m, d) => Date.UTC(y, m, d);
  const dow = (t) => new Date(t).getUTCDay();
  const iso = (t) => new Date(t).toISOString().slice(0, 10);
  const fmt = (t) => {
    const d = new Date(t);
    return `${WEEKDAYS[d.getUTCDay()]}, ${MONTHS[d.getUTCMonth()]} ${d.getUTCDate()}, ${d.getUTCFullYear()}`;
  };
  const parse = (s) => {
    const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec((s || "").trim());
    return m ? utc(+m[1], +m[2] - 1, +m[3]) : null;
  };

  // nth weekday (0 = Sunday) of a month; n = -1 for the last one.
  function nthWeekday(y, m, wd, n) {
    if (n > 0) {
      const first = utc(y, m, 1);
      return first + (((wd - dow(first) + 7) % 7) + 7 * (n - 1)) * DAY;
    }
    const last = utc(y, m + 1, 0);
    return last - ((dow(last) - wd + 7) % 7) * DAY;
  }

  // Federal legal holidays (5 U.S.C. § 6103), as listed in Rule 6(a)(6)(A).
  // A holiday on a Saturday is observed the Friday before; on a Sunday,
  // the Monday after.
  function federalHolidays(y) {
    const out = [];
    const fixed = (m, d, name) => {
      let t = utc(y, m, d);
      let note = "";
      if (dow(t) === 6) { t -= DAY; note = " (observed)"; }
      else if (dow(t) === 0) { t += DAY; note = " (observed)"; }
      out.push([t, name + note]);
    };
    fixed(0, 1, "New Year's Day");
    out.push([nthWeekday(y, 0, 1, 3), "Martin Luther King Jr.'s Birthday"]);
    out.push([nthWeekday(y, 1, 1, 3), "Washington's Birthday"]);
    out.push([nthWeekday(y, 4, 1, -1), "Memorial Day"]);
    if (y >= 2021) fixed(5, 19, "Juneteenth National Independence Day");
    fixed(6, 4, "Independence Day");
    out.push([nthWeekday(y, 8, 1, 1), "Labor Day"]);
    out.push([nthWeekday(y, 9, 1, 2), "Columbus Day"]);
    fixed(10, 11, "Veterans' Day");
    out.push([nthWeekday(y, 10, 4, 4), "Thanksgiving Day"]);
    fixed(11, 25, "Christmas Day");
    return out;
  }

  function holidayTable(fromYear, toYear, declared, state, after) {
    const table = new Map();
    for (let y = fromYear - 1; y <= toYear + 1; y++) {
      for (const [t, name] of federalHolidays(y)) table.set(t, name);
    }
    for (const t of declared) table.set(t, "holiday declared by the President or Congress");
    if (after) for (const t of state) if (!table.has(t)) table.set(t, "state legal holiday");
    return table;
  }

  function closedReason(t, holidays) {
    if (dow(t) === 6) return "a Saturday";
    if (dow(t) === 0) return "a Sunday";
    if (holidays.has(t)) return `a legal holiday (${holidays.get(t)})`;
    return null;
  }

  // Rule 6(a)(1)(C) and (a)(5): roll to the next day that is not a
  // weekend or holiday, counting forward or backward.
  function roll(t, step, holidays, steps) {
    let reason = closedReason(t, holidays);
    while (reason) {
      steps.push(`${fmt(t)} is ${reason}, so the period continues to run to the ${step > 0 ? "next" : "previous"} day.`);
      t += step * DAY;
      reason = closedReason(t, holidays);
    }
    return t;
  }

  function parseList(s) {
    return (s || "").split(/[\s,;]+/).filter(Boolean).map(parse);
  }

  function compute(input) {
    const steps = [];
    const sign = input.after ? 1 : -1;
    const yr = new Date(input.trigger).getUTCFullYear();
    const spanYears = Math.ceil((input.days + 3) / 365) + 1;
    const holidays = holidayTable(yr - spanYears, yr + spanYears, input.declared, input.state, input.after);

    steps.push(`Exclude the day of the triggering event, ${fmt(input.trigger)}. (Rule 6(a)(1)(A))`);
    let t = input.trigger + sign * input.days * DAY;
    steps.push(`Count every day, including weekends and holidays: ${input.days} day${input.days === 1 ? "" : "s"} ${input.after ? "after" : "before"} the event is ${fmt(t)}. (Rule 6(a)(1)(B))`);
    const before = t;
    t = roll(t, sign, holidays, steps);
    if (t === before) steps.push(`${fmt(t)} is not a weekend or legal holiday, so it is the last day. (Rule 6(a)(1)(C))`);
    else steps.push(`The last day is ${fmt(t)}. (Rule 6(a)(1)(C), (a)(5))`);

    if (input.mail && input.after) {
      const plus = t + 3 * DAY;
      steps.push(`Service was by mail (or another method listed in Rule 6(d)), so add 3 days after the period would otherwise expire: ${fmt(plus)}. (Rule 6(d))`);
      const rolled = roll(plus, 1, holidays, steps);
      if (rolled !== plus) steps.push(`The last day is ${fmt(rolled)}. (Rule 6(a)(1)(C))`);
      t = rolled;
    }
    return { deadline: t, steps };
  }

  const PRESETS = {
    custom: { label: "Custom period", days: null },
    answer: { label: "Answer the complaint: 21 days after being served with the summons and complaint (Rule 12(a)(1)(A)(i))", days: 21, after: true, mail: false,
      note: "Service of the summons and complaint is made under Rule 4, not Rule 5, so Rule 6(d)'s extra 3 days don't apply. A defendant who waives service has 60 days after the request was sent (Rule 12(a)(1)(A)(ii))." },
    amend: { label: "Amend once as a matter of course: 21 days after serving the pleading (Rule 15(a)(1)(A))", days: 21, after: true, mail: false,
      note: "This period runs from the pleader's own service, not from being served, so Rule 6(d) doesn't apply. If the pleading requires a response, the pleader may instead amend within 21 days after service of the response or of a Rule 12(b), (e), or (f) motion (Rule 15(a)(1)(B))." },
    respondAmended: { label: "Respond to an amended pleading: 14 days after being served with it (Rule 15(a)(3))", days: 14, after: true, mail: null,
      note: "Rule 15(a)(3) gives the later of this date and the time remaining to respond to the original pleading." },
    safeHarbor: { label: "Rule 11 safe harbor: 21 days after the motion is served (Rule 11(c)(2))", days: 21, after: true, mail: null,
      note: "The motion may not be filed until the safe harbor has run. This is the period Hicks let pass in Christian v. Mattel." },
    discovery: { label: "Respond to interrogatories, document requests, or requests for admission: 30 days after being served (Rules 33(b)(2), 34(b)(2)(A), 36(a)(3))", days: 30, after: true, mail: null,
      note: "An unanswered request for admission is deemed admitted when this period runs (Rule 36(a)(3))." },
    hearing: { label: "Serve a written motion and notice of hearing: at least 14 days before the hearing (Rule 6(c)(1))", days: 14, after: false, mail: false,
      note: "For a period measured before an event, the \"next day\" is found by counting backward (Rule 6(a)(5)), so a weekend or holiday moves the deadline earlier. State holidays don't count for these periods (Rule 6(a)(6)(C))." },
    postTrial: { label: "Renewed motion for judgment as a matter of law or motion for a new trial: 28 days after entry of judgment (Rules 50(b), 59(b))", days: 28, after: true, mail: false,
      note: "The court can't extend these deadlines (Rule 6(b)(2)). The period runs from entry of judgment, not from service, so Rule 6(d) doesn't apply." },
    appeal: { label: "Notice of appeal: 30 days after entry of judgment (Fed. R. App. P. 4(a)(1)(A))", days: 30, after: true, mail: false,
      note: "Appellate Rule 26(a) computes time the same way as Civil Rule 6(a). The period is 60 days if the United States or its officer or agency is a party (Fed. R. App. P. 4(a)(1)(B))." },
  };

  function init(root) {
    const $ = (sel) => root.querySelector(sel);
    const preset = $(".r6-preset");
    for (const [key, p] of Object.entries(PRESETS)) {
      const o = document.createElement("option");
      o.value = key;
      o.textContent = p.label;
      preset.appendChild(o);
    }
    const today = new Date();
    $(".r6-trigger").value = iso(utc(today.getFullYear(), today.getMonth(), today.getDate()));

    function applyPreset() {
      const p = PRESETS[preset.value];
      if (p.days !== null) {
        $(".r6-days").value = p.days;
        $(".r6-direction").value = p.after ? "after" : "before";
        if (p.mail !== null) $(".r6-mail").checked = p.mail;
      }
      $(".r6-note").textContent = p.note || "";
      run();
    }

    function run() {
      const out = $(".r6-output");
      const after = $(".r6-direction").value === "after";
      $(".r6-mail").disabled = !after;
      if (!after) $(".r6-mail").checked = false;
      $(".r6-state-wrap").style.opacity = after ? "1" : "0.5";
      const trigger = parse($(".r6-trigger").value);
      const days = parseInt($(".r6-days").value, 10);
      const declared = parseList($(".r6-declared").value);
      const state = parseList($(".r6-state").value);
      out.innerHTML = "";
      if (trigger === null || !(days >= 1 && days <= 3650)) {
        out.textContent = "Enter a triggering date and a period of 1 or more days.";
        return;
      }
      if (declared.includes(null) || state.includes(null)) {
        out.textContent = "Enter additional holidays as dates like 2026-11-27, separated by commas.";
        return;
      }
      const r = compute({ trigger, days, after, mail: $(".r6-mail").checked, declared, state });
      const h = document.createElement("p");
      h.className = "r6-deadline";
      h.innerHTML = `<strong>Last day: ${fmt(r.deadline)}</strong>`;
      out.appendChild(h);
      const ol = document.createElement("ol");
      for (const s of r.steps) {
        const li = document.createElement("li");
        li.textContent = s;
        ol.appendChild(li);
      }
      out.appendChild(ol);
      const tail = document.createElement("p");
      tail.className = "r6-small";
      tail.textContent = "Unless a statute, local rule, or order says otherwise, the last day ends at midnight in the court's time zone for electronic filing, or when the clerk's office closes for other filing (Rule 6(a)(4)).";
      out.appendChild(tail);
    }

    preset.addEventListener("change", applyPreset);
    root.querySelectorAll("input, select").forEach((el) => {
      if (el !== preset) el.addEventListener("input", () => {
        if (el.classList.contains("r6-days") || el.classList.contains("r6-direction")) preset.value = "custom";
        run();
      });
    });
    applyPreset();
  }

  // Exposed for testing.
  if (typeof module !== "undefined") module.exports = { compute, federalHolidays, parse, iso };
  if (typeof document !== "undefined") {
    const start = () => document.querySelectorAll(".rule6-calculator").forEach(init);
    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start);
    else start();
  }
})();
