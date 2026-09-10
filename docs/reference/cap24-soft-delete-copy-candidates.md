# Cap 24 soft-delete — locked copy candidates (pre-ARB)

**Status:** Owner-locked in Cap 24.1 design chat; **not** yet in
`lib/l10n/*.arb`. Cap 24.2+ implementing work must paste these into ARB
(EN + zh-Hans key sets match — ADR-012) unless the owner revises this file
first.

**Not** a substitute for ADR-050 (contract stays in `docs/DECISIONS.md`).
This file only preserves the exact strings so a later session does not
re-invent copy from ADR “copy class” prose alone.

Related: ADR-050 Decisions 3, 4, 7.

---

## 1. Confirm dialog (ADR-050 Decision 3)

Suggested keys: `cap24SoftDeleteConfirmTitle` /
`cap24SoftDeleteConfirmBody` / `cap24SoftDeleteConfirm` /
`cap24SoftDeleteConfirmCancel`.

### EN

```
title: Delete this item?
body: This item will be deleted from iCloud Photos on all your devices. It will stay in Recently Deleted for 30 days.
confirmButton: Delete
cancelButton: Cancel
```

### zh-Hans

```
title: 删除此项？
body: 此项目将从你所有设备上的「iCloud 照片」中删除。它会在「最近删除」中保留 30 天。
confirmButton: 删除
cancelButton: 取消
```

Notes: media-neutral (“this item” / 此项·此项目); no “cannot be undone”;
same dialog shell family as Cap 22 / Cap 23 (`browseSavedPoolAlertDialog`).

---

## 2. Minute landmark timezone note (ADR-050 Decision 7)

Key: `cap24SoftDeleteSheetMinuteTimezoneNote`.

Formatters (separate keys; not Overlay `mediaInfoExactDateApprox`):

- Bare EXIF: `cap24SoftDeleteSheetExactMinute` → `yyyy-MM-dd HH:mm[:ss]`
- Instant fallback: `cap24SoftDeleteSheetExactMinuteApprox` →
  `~ yyyy-MM-dd HH:mm`

### EN

```
For photos or videos saved across time zones, the hour shown may be
wrong, and in rare cases the date may be off by up to a day.
```

### zh-Hans

```
跨时区保存的照片或视频，显示的小时可能不准确；极少数情况下，
日期也可能相差一天左右。
```

Notes: ±1 calendar day (ADR-038), not “3 days”; hour is the primary
failure mode. Half-sheet EXIF date may disagree with Overlay row 2 —
accepted (ADR-050 Decision 7).

---

## 3. Soft-delete failure toast (ADR-050 Decision 4)

Key: `cap24SoftDeleteFailed`.

### EN

```
Couldn't delete. Try again.
```

### zh-Hans

```
无法删除，请重试。
```

Notes: same toast *style* as `cap19PanelAddToAlbumError`; **do not**
reuse that key (album-add wording).
