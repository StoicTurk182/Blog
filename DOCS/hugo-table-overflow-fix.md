---
title: "Hugo Blog Table Overflow Fix"
created: 2026-04-24T00:00:00
updated: 2026-04-24T00:00:00
---

# Hugo Blog Table Overflow Fix

## Table of Contents

1. [Problem](#problem)
2. [Root Cause](#root-cause)
3. [Fix](#fix)
   1. [assets/style.css](#assetsstylecss)
   2. [static/css/custom.css](#staticcsscustomcss)
4. [Why This Works](#why-this-works)
5. [What Not to Do](#what-not-to-do)
6. [References](#references)

---

Wide tables (typically 4+ columns) overflow their container instead of triggering horizontal scroll on the Hugo blog at `blog.ajolnet.com`. The Mainroad theme is affected. The issue recurs when table CSS rules accumulate across both `assets/style.css` and `static/css/custom.css`.

## Problem

Tables expand beyond the content container rather than scrolling horizontally. The symptom is columns breaking out to the right edge of the viewport, with no scroll bar appearing.

## Root Cause

Three compounding issues:

**1. `display: table` breaks overflow containment**

`display: table` does not establish a block formatting context. A table with this display value will not respect the `overflow-x: auto` of its parent container — it escapes the scroll boundary. `display: block` is required for scroll containment to work.

**2. `width: 100%` suppresses scroll**

Setting `width: 100%` instructs the table to fill its container exactly. The browser then squashes columns to fit rather than allowing the table to exceed the container width and scroll. This silently prevents the scroll trigger.

**3. Conflicting rules across both CSS files**

With `!important` declarations spread across `style.css` and `custom.css`, cascade order becomes unpredictable. Multiple table rule blocks targeting the same properties override each other depending on source order, producing inconsistent results across page rebuilds and theme updates.

Additionally, any `.table-wrapper` approach is ineffective in this context. Hugo's Goldmark markdown renderer does not wrap `<table>` elements in a parent div automatically, so wrapper-dependent rules have no element to match.

## Fix

The fix splits responsibility cleanly: `style.css` handles base structural defaults only, `custom.css` is the single authoritative source for all display and overflow overrides.

### assets/style.css

Remove all existing table rule blocks from `style.css`. Replace with the following base-only block containing no `!important`:

```css
/* Table - base layout only, overflow handled by custom.css */
table {
    border-collapse: collapse;
    border-spacing: 0;
}
```

Remove any `.table-wrapper` blocks from `style.css` entirely.

### static/css/custom.css

Add or replace all table rules with one authoritative block:

```css
/* Table overflow scroll */
table {
    display: block !important;
    width: max-content !important;
    min-width: unset !important;
    max-width: 100% !important;
    overflow-x: auto !important;
    -webkit-overflow-scrolling: touch;
    border: 1px solid #ebebeb !important;
    border-collapse: collapse;
    border-radius: 0 !important;
}
```

## Why This Works

| Property | Value | Reason |
|---|---|---|
| `display: block` | `!important` | Establishes block formatting context; table respects parent overflow boundary |
| `width: max-content` | `!important` | Table sizes to its natural content width; does not squash columns to fit container |
| `min-width: unset` | `!important` | Removes any floor value that would force full-width before content pushes wider |
| `max-width: 100%` | `!important` | Prevents the table asserting a width wider than the viewport on small screens |
| `overflow-x: auto` | `!important` | Scroll context is on the table element itself; does not depend on a wrapper div |

`custom.css` loads after the Mainroad theme's `style.css` in Hugo's asset pipeline, so it wins specificity ties at equal weight. Concentrating `!important` exclusively in `custom.css` makes cascade behaviour predictable: `style.css` sets defaults, `custom.css` overrides.

## What Not to Do

**Do not use `display: table !important`**

This is the semantically correct CSS value for a `<table>` element but it breaks overflow scroll containment in this layout. It will always cause tables to escape their container.

**Do not use `width: 100%` or `min-width: 100%`**

Either value prevents the browser from allowing the table to be wider than its container, which is the condition required to trigger `overflow-x: auto`. The result is column squashing instead of scrolling.

**Do not use `.table-wrapper` rules without a corresponding layout change**

Hugo's Goldmark renderer outputs bare `<table>` elements with no wrapping div. Wrapper-based CSS rules will never match unless a Hugo render hook or shortcode explicitly adds the wrapper element.

**Do not split `!important` overrides across both CSS files**

Once `!important` appears in both files on the same property, load order determines the winner and this can change across theme updates or Hugo version changes.

## References

- Hugo Goldmark renderer (table output): https://gohugo.io/getting-started/configuration-markup/#goldmark
- MDN - CSS display property: https://developer.mozilla.org/en-US/docs/Web/CSS/display
- MDN - overflow-x: https://developer.mozilla.org/en-US/docs/Web/CSS/overflow-x
- MDN - Block formatting context: https://developer.mozilla.org/en-US/docs/Web/Guide/CSS/Block_formatting_context
- Mainroad theme repository: https://github.com/vimux/mainroad
