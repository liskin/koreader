# CoverImage plugin makes rotation changes slow (~5–10 s) on PocketBook

**Device:** PocketBook (e.g. InkPad 3 on firmware 6.8)
**KOReader version:** 2026.03 and later (introduced in #14985)

## Issue

PR #14985 added a call to `os.execute("sync")` inside `CoverImage:updatePocketBookBootLogo()`.
This call is **synchronous** — KOReader blocks until the kernel has flushed all dirty pages to
storage, which can take several seconds.

`updatePocketBookBootLogo()` is called every time the cover image file is (re)written.
The cover image is rewritten on every rotation change (because the cover plugin by default
applies the "Rotate image" setting to match screen orientation). As a result, every
orientation change now takes **5–10 seconds** on affected devices, instead of being nearly
instant.

On InkPad 3 / firmware 6.8 the `sync` alone introduces ~5–7 seconds of blocking; the
subsequent `iv2sh WriteStartupLogo` (run in the background) is fast (~1 second) and does
not contribute to the freeze.

## Expected behaviour

Changing screen orientation (or opening/closing a book) should not cause a multi-second
freeze.

## Proposed solutions

### Option A — remove `sync` (preferred if safe)

The `sync` was added to ensure the cover image file is flushed to disk before
`WriteStartupLogo` reads it. However, `WriteStartupLogo` reads from the in-memory `/tmp`
tmpfs path — it does **not** read the user-visible cover image file directly. Based on
decompilation of `libinkview.so` on firmware 6.8, there is no code path that would require
a prior `sync`. If testing confirms this, the `sync` call should simply be removed.

### Option B — move `sync` to the background (safe fallback)

If `sync` turns out to be required on some firmware versions, both commands can be
combined into a single shell invocation so that neither blocks KOReader:

```lua
os.execute("{ sync; iv2sh WriteStartupLogo " .. util.shell_escape({self.cover_image_path}) .. "; } &")
```

### Option C — skip cover image recreation on rotation when rotation is disabled

Regardless of the `sync` question, when the "Rotate image" option is disabled in the
CoverImage plugin settings, there is no need to recreate the cover image on rotation
changes at all. Adding an early-return guard in `onSetRotationMode` would eliminate the
unnecessary work:

```lua
function CoverImage:onSetRotationMode(rotation)
    logger.dbg("CoverImage: onSetRotationMode", rotation)
    if self.cover_image_rotate then
        self:createCoverImage(self.ui.doc_settings)
    end
end
```

This alone saves ~0.5 s per rotation on InkPad 3 even after the `sync` issue is fixed.

## Testing notes

- Reported on InkPad 3 (firmware 6.8); the `sync` takes ~5–7 s there.
- On Verse Pro Color and InkPad Color 3 (newer firmware), the reporter of #14985 observed
  no slowdown, suggesting firmware behaviour may differ. It is worth testing Option A on
  multiple devices before committing to removing `sync`.

## Related

- #14985 — the PR that introduced the regression
- The companion issue about boot logo ignoring system settings (see `issue-pocketbook-bootlogo-respects-settings.md`)
