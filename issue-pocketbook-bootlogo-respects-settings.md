# CoverImage plugin sets PocketBook boot logo unconditionally, ignoring device settings

**Device:** PocketBook (all models with Personalize → Logos settings, e.g. InkPad 3, InkPad Color 3, Verse Pro Color)
**KOReader version:** 2026.03 and later (introduced in #14985)

## Issue

The CoverImage plugin now calls `iv2sh WriteStartupLogo` every time a book cover is
written to the cover image file (on book open/close). This always overwrites the device's
boot logo, regardless of what setting the user has selected in the PocketBook firmware under
**Personalize → Logos → Boot Logo**.

PocketBook's firmware has at least these boot logo options:
- PocketBook logo
- Book Cover
- Current Page
- Random logo (`@random_logo`)

Before #14985, if a user chose "Current Page" (so that the device could resume to the last
read page almost instantly after power-on) or any other option, KOReader would leave it
alone. After #14985, KOReader always overwrites the boot logo with the book cover whenever
the user opens a book.

In particular, this conflicts with using the
[pocketbooksync.koplugin](https://github.com/ckilb/pocketbooksync.koplugin) to set the boot
logo to the current page (see also #15124), but it's a general problem: the PocketBook
firmware intentionally exposes independent settings for the power-off logo and the boot logo,
and KOReader should respect that.

## Expected behaviour

The CoverImage plugin should only call `WriteStartupLogo` (update the boot logo) when the
PocketBook system setting for the boot logo is set to **Book Cover** (`@cover_logo`).
When the boot logo is set to anything else, KOReader must not touch the boot logo.

Note: the power-off logo (`/mnt/ext1/system/logo/bookcover` symlink/path) is a separate
concern and is already handled correctly.

## Proposed solution

Read PocketBook's global config using the `GetGlobalConfig` / `ReadString` inkview API
calls to check the value of the `bootlogo` key before calling `WriteStartupLogo`:

```lua
ffi.cdef[[
struct iconfig_s * GetGlobalConfig();
const char *ReadString(struct iconfig_s *cfg, const char *name, const char *deflt);
]]

function CoverImage:updatePocketBookBootLogo()
    if Device.isPocketBook() then
        local inkview = ffi.load("inkview")
        local bootlogo = ffi.string(inkview.ReadString(inkview.GetGlobalConfig(), "bootlogo", "@default_boot_logo"))
        if bootlogo == "@cover_logo" then
            logger.dbg("CoverImage: updating PocketBook boot logo from", self.cover_image_path)
            os.execute("iv2sh WriteStartupLogo " .. util.shell_escape({self.cover_image_path}) .. " &")
        end
    end
end
```

A proof-of-concept userpatch that implements this (and the related performance fix) was
shared in the discussion on #14985.

## Related

- #14985 — the PR that introduced the regression
- #15124 — feature request for "Current Page" boot logo support (blocked by this issue)
- https://github.com/ckilb/pocketbooksync.koplugin — third-party plugin affected by this
