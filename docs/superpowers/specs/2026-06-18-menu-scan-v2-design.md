# Menu Scan v2 — Annotated Image Design

**Date:** 2026-06-18
**Status:** Approved (pending spec review)

## Goal

Replace the menu scanner's text-list output with an **annotated menu image** produced by
OpenAI's `gpt-image-1` image-edit model: the user photographs a menu and gets back the same
menu with colour-coded translucent highlights and small badges flagging likely migraine
triggers. The structured Claude dish-list is retained as a fallback.

## Key decisions

- **Result type:** Annotated image **+** structured dish-list fallback (not image-only).
- **Logging:** Dropped. The scanner is **informational only** (the current tap-a-dish-to-log
  is removed).
- **Quality:** `gpt-image-1` at `quality: high` for legible menu text.
- **Known risk:** `gpt-image-1` regenerates the whole image; on dense photographed menus it can
  garble/rewrite text. The structured list fallback + a manual "See text breakdown" toggle are
  the mitigations. We do **not** attempt automatic garble-detection.

## Architecture & data flow

1. `MenuScanSheet` captures the menu photo (camera or album) → `store.scanMenu(imageBase64)`
   (existing entry point, unchanged signature on the app side).
2. New/extended Convex action runs **two calls in parallel** (`Promise.all`; total latency ≈ the
   slow OpenAI call):
   - **OpenAI `gpt-image-1`** via `POST https://api.openai.com/v1/images/edits`
     (multipart/form-data: `image` = the menu JPEG, `prompt` = the annotation prompt below,
     `model: gpt-image-1`, `quality: high`, `n: 1`). Returns `data[0].b64_json` (PNG).
   - **Claude vision** — the existing `scanMenu` logic → `{ dishes: MenuDish[] }`, kept only as a
     fallback / "text breakdown".
3. The action decodes the OpenAI PNG, stores it in **Convex file storage**
   (`ctx.storage.store`), and returns `{ annotatedUrl?: string, dishes: MenuDish[] }`.
   - Storage URL rather than raw base64: high-quality images are multiple MB; cleaner to load a
     URL via `AsyncImage` than to push base64 over the websocket.
   - If the OpenAI call fails/returns nothing, `annotatedUrl` is `nil` and only `dishes` is returned.

## Prompt

The user-supplied prompt is used **verbatim** (full badge colour system + legend instruction).
The user's suspected-trigger categories are appended as a light weighting hint (consistent with
how the current scan personalizes), e.g. "The user especially suspects: …". Faithful to the spec
otherwise.

## Result UI (`MenuScanSheet`)

- **Primary:** the annotated menu image, full-width, **pinch-to-zoom** (menus are dense). The
  legend is baked into the image by the prompt.
- **"See text breakdown" toggle:** reveals the read-only grouped Safe / Caution / Avoid list
  (the existing grouping UI, minus the tap-to-log buttons). This is the manual escape hatch when
  the model garbles the menu.
- **No logging** anywhere in the scanner.
- **Fallbacks:**
  - OpenAI failed but dishes present → show the list directly with a small note
    ("Couldn't annotate the image — here's the text breakdown").
  - Both empty → existing "Couldn't read that menu — retake" state.

## Loading state

The OpenAI call takes ~30–60s, so a single spinner is insufficient. A **staged loader** cycles
through "Reading the menu… → Spotting triggers… → Annotating…" on a timer so the wait feels alive.

## Components touched

- **`convex/ai.ts`** — extend/replace `scanMenu` action: parallel OpenAI edit + Claude list,
  store image, return `{ annotatedUrl?, dishes }`. Add an OpenAI helper (multipart form, base64
  decode). Reads `process.env.OPENAI_API_KEY`.
- **`HavenCore/.../MenuScan.swift`** — add `annotatedUrl: String?` to `MenuScan` (tolerant
  decode). `dishes` unchanged.
- **`HavenCore/.../{DayDataSource, TodayStore}.swift`** — `scanMenu` return type carries the URL.
- **`Haven/Sources/Services/ConvexService.swift`** — decode `annotatedUrl` from the action result.
- **`Haven/Sources/Today/Loggers/MenuScanSheet.swift`** — new result view: zoomable
  `AsyncImage`, "See text breakdown" toggle, staged loader; remove tap-to-log.

## Setup / cost

- `OPENAI_API_KEY` set in Convex **dev** (done) and **prod** (before next TestFlight build).
- ~$0.17/scan (gpt-image-1 high) + negligible Claude Haiku.
- Orphaned annotated images accumulate in Convex storage (no cleanup in v1) — noted as a follow-up.

## Testing

- Keep existing `menuParse` unit tests (still used for the fallback list).
- The OpenAI integration is network I/O — not unit-tested. Any pure helper (e.g. extracting
  `b64_json` from the response shape) gets a small vitest.
- Manual on-device verification: scan a real menu, confirm annotated image renders, toggle the
  text breakdown, and confirm the fallback path when the image is unavailable.

## Out of scope (v1)

- Automatic detection of garbled output.
- Storage cleanup of old annotated images.
- Re-introducing logging from the scanner.
