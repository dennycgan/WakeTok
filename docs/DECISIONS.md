# WakeTok — Decision Log (ADR)

> Major technical/engineering decisions. Each entry is immutable: never edit or
> delete its reasoning. To overturn a decision, write a NEW entry and only flip
> the old entry's Status line to "Superseded by ADR-xxx".
> The top "Plain summary" line is for the project owner to verify — it must be
> understandable without deep technical knowledge.
> Workflow: draft the ADR in chat -> owner approves the draft -> append here
> (see state-decisions-maintenance.mdc and release-handoff.mdc).
> Append new entries at the end; numbering starts at ADR-001 and increments.
> Always record the date and a commit/PR anchor.
> **Accepted date** = `git log -1 --format=%cs <anchor-sha>` (the day the
> implementing commit lands on `main`), not the design-discussion day.
>
> Status values: Accepted | Superseded by ADR-xxx (date) | Deprecated (no
> replacement) | Reverted-in-code (implementation rolled back; see note)
>
> Revert reconciliation: if a code revert crosses the implementation point of an
> Accepted ADR, do NOT silently leave the log stale. Either (a) write a new ADR
> explaining the rollback, or (b) flip the old entry's Status to
> "Reverted-in-code (date, reason)" and add a one-line note. The original
> reasoning stays untouched.
>
> Note: lettered ADR references inside the local kickoff (ADR-K, ADR-P.5, …) are
> kickoff-internal spec anchors, NOT entries in this log. This log starts empty
> at ADR-001.

---

## ADR Template
- Status: Accepted (YYYY-MM-DD)  <!-- date = git log -1 --format=%cs <anchor-sha> -->
- Commit/PR anchor: <sha or #PR>
- Plain summary (owner reads this): <one plain-language sentence>
- Context / what problem forced this:
- Decision (what was chosen):
- Rejected alternatives (why not B):
- Consequences / constraints accepted:

---

<!-- No entries yet. ADR-001 is expected after Project Bootstrap Commit 1
     (bundle ID com.dennycgan.waketok; deployment target deferred to POC-04). -->
