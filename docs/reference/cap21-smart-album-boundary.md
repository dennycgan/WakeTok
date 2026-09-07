# Cap 21.4b — Smart Album boundary (Build a Pool catalog)

Acceptance / product boundary for which PhotoKit smart albums appear in the
Build a Pool catalog. **STATE.md** holds only a Contract pointer here.

## Dead table (runtime whitelist)

Only these `PHAssetCollectionSubtype` raw values may appear in the Smart
Albums section. **Nothing else auto-joins** when iOS adds subtypes — owner
must edit this table (and ARB labels) deliberately.

### Always-on product order (after emptiness filter)

| Order | Raw | EN label (ARB) | Notes |
|------:|----:|----------------|-------|
| 0 (pin) | 203 | Favorites | Pinned first when non-empty |
| 1 | 213 | Live Photos | Fixed product priority — **not** count-sorted |
| 2 | 211 | Screenshots | Fixed product priority |
| 3 | 214 | Animated | Fixed product priority |
| 4 | 210 | Selfies | Fixed product priority |
| 5 | 202 | Videos | Only Build path for “all videos” after Cap 21.4 built-in omit |
| 6 | 220 | Screen Recordings | Fixed product priority |

### Remaining whitelist (stable sort = subtype ascending)

| Raw | EN label (ARB) |
|----:|----------------|
| 201 | Panoramas |
| 204 | Time-lapse |
| 207 | Bursts |
| 208 | Slo-mo |
| 212 | Portrait |
| 215 | Long Exposure |
| 217 | RAW |
| 218 | Cinematic |
| 219 | Spatial |
| 221 | Dual Capture |

### Explicit excludes (never catalog)

| Raw | Title (EN probe) | Why (reference only — not runtime heuristics) |
|----:|------------------|-----------------------------------------------|
| 209 | Recents | Recently-family: moving time window, not an “album” |
| 206 | Recently Added | Recently-family |
| 1000000218 | Recently Saved | Recently-family; undocumented subtype |
| 1000000201 | Recently Deleted | Recently-family; undocumented (**not** 201 Panoramas) |
| 1000000219 | Recovered | System maintenance, not a content class |
| 216 | Unable to Upload | System / diagnostic status |
| 205 | Hidden | Cap 11.2 D3=A (pre-existing) |
| — | Illustrations / QR codes / People and Pets | Not exposed as public `PHAssetCollection` smart albums (PhotoKit hard limit; needs a later Cap / private API / Vision) |

Any subtype absent from both whitelist and this exclude table is still
**out of catalog** (fixed table — omission = exclude).

### Full probe ↔ table reconciliation (Kafka, 2026-09-07)

Re-checked before Cap 21.4b ship: every subtype seen in PASS_A (`.any`)
**plus** PASS_B brute extras (206, 216) **plus** Hidden / Recently Deleted
is accounted for — either whitelist or explicit exclude. **No second
Slo-mo-class gap** (present in probe data but missing from both tables).

Machine guard: `test/domain/source/smart_album_boundary_test.dart`
`B-21.4b-3`.

## Live rules (runtime)

1. **Enumerate with brute-force (or equivalent complete strategy).** Do
   **not** rely on `fetchAssetCollections(with: .smartAlbum, subtype: .any)`
   alone — Cap 21.4b probe showed `.any` omitted **206** and **216**.
2. **`resolveCount` / emptiness** uses the same image|video predicate as
   album resolve (`makeAlbumAssetFetchOptions`). UI does **not** show
   counts; Host emptiness may use `fetchLimit = 1`.
3. **Zero content ⇒ hide for this session** (not removed from whitelist).
   When the user later has content, the row can appear without an app
   update. Fixed-order slots leave **no empty gap** when a pinned/fixed
   row is hidden.
4. **Favorites** obeys zero-hide (no special case). When non-empty, it is
   always first among visible smart rows.
5. **Naming:** Dart ARB map keyed by subtype (Q6=C). Initial zh strings
   copied from Apple `localizedTitle` under a temporary zh-Hans probe —
   App is **not** formally declaring zh-Hans in Cap 21.4b (release-handoff).
6. **UI:** Same row chrome as user albums (cover + title + trailing check).
   No count badge.

## Probe reconciliation (Kafka, 2026-09-07)

PASS_B brute subtypes observed vs final table:

| Raw | Probe title | Disposition |
|----:|-------------|-------------|
| 201 | Panoramas | whitelist (remaining) |
| 202 | Videos | whitelist (fixed #5) |
| 203 | Favorites | whitelist (pin) |
| 204 | Time-lapse | whitelist (remaining) |
| 205 | Hidden | exclude (Cap 11.2) |
| 206 | Recently Added | exclude (Recently) — also omitted by `.any` |
| 207 | Bursts | whitelist (remaining) |
| 208 | Slo-mo | whitelist (remaining) — added after gap check |
| 209 | Recents | exclude (Recently) |
| 210–215, 217–221 | (media classes) | whitelist per tables above |
| 216 | Unable to Upload | exclude — also omitted by `.any` |
| 1000000201 | Recently Deleted | exclude (Recently) |
| 1000000218 | Recently Saved | exclude (Recently) |
| 1000000219 | Recovered | exclude |

No second “Slo-mo-class” gap remained after 208 was added.
