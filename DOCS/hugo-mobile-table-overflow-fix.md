# Hugo Mobile Table Overflow Fix

Tables with more than three columns were collapsing on mobile viewports instead of scrolling horizontally. This document covers the investigation and final fix.

## Problem
---

Markdown tables rendered in Hugo posts were not scrollable on mobile. Wide tables (4+ columns) would collapse and overflow the content area rather than displaying a horizontal scrollbar.

## Environment
---

| Component | Detail |
|-----------|--------|
| Hugo version | v0.154.5 extended |
| Theme | Mainroad |
| Custom CSS location | `static/css/custom.css` |
| Asset CSS location | `assets/css/style.css` |

## Investigation
---

### Step 1: Find existing overflow rules
---

```powershell
Get-ChildItem -Recurse -Include "*.css" | Select-String -Pattern "overflow-x"
```

Result confirmed `overflow-x: auto` existed only in `assets/css/style.css` inside a `.table-wrapper` class — a wrapper that was never being applied to the rendered HTML.

### Step 2: Check all table-related CSS
---

```powershell
Get-ChildItem -Recurse -Include "*.css","*.scss" | Select-String -Pattern "table|overflow-x" | Select-Object Filename, LineNumber, Line
```

Revealed `.table-wrapper` CSS was in place but no render hook existed to output the wrapper div around tables.

### Step 3: Attempted render hook approach
---

Created `layouts/_default/_markup/render-table.html` to wrap every markdown table in a scrollable div. Hugo 0.154 table render hook context uses `.THead` and `.TBody` methods — not `.Body`, `.Header`, or `.Rows` as documented in older versions.

Correct hook syntax for Hugo 0.134+:

```html
<div class="table-wrapper">
  <table>
    <thead>
      {{- range .THead }}
      <tr>
        {{- range . }}
        <th{{- with .Alignment }} style="text-align: {{ . }}"{{ end }}>{{ .Text | safeHTML }}</th>
        {{- end }}
      </tr>
      {{- end }}
    </thead>
    <tbody>
      {{- range .TBody }}
      <tr>
        {{- range . }}
        <td{{- with .Alignment }} style="text-align: {{ . }}"{{ end }}>{{ .Text | safeHTML }}</td>
        {{- end }}
      </tr>
      {{- end }}
    </tbody>
  </table>
</div>
```

The render hook built successfully but tables remained unaffected. Inspecting the rendered HTML confirmed tables were output as plain `<table>` elements with no wrapper div — indicating the hook was not being invoked correctly.

This approach was abandoned in favour of a simpler pure CSS fix.

### Step 4: Add bare table CSS to assets/css/style.css
---

Added the following to the bottom of `assets/css/style.css`:

```css
/* Table */
table {
  display: block;
  width: 100%;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}
```

Still no effect. Browser DevTools confirmed the rule was not appearing in the Styles panel for the `table` element — meaning `style.css` was being loaded but losing the specificity battle, or being overridden by another stylesheet loaded after it.

### Step 5: DevTools inspection
---

Inspecting the table element in DevTools showed the following winning rule:

```css
table {
  width: 100%;
  margin-bottom: 20px;
  border-spacing: 0;
  border-collapse: collapse;
  border-top: 1px solid #ebebeb;
  border-left: 1px solid #ebebeb;
}
```

No `display: block` or `overflow-x` rule was present. The custom rule from `style.css` was absent entirely, indicating it was being overridden by a stylesheet with higher load order priority.

### Step 6: Identify the overriding file
---

```powershell
Get-ChildItem -Recurse -Include "*.css" | Select-Object FullName
```

Revealed `static/css/custom.css` — a separate stylesheet loaded after `assets/css/style.css`. Rules in `custom.css` take precedence because it loads later in the document.

## Fix
---

Add the table overflow rule to `static/css/custom.css`:

```powershell
Add-Content static\css\custom.css "`n/* Table */`ntable {`n  display: block !important;`n  width: 100%;`n  overflow-x: auto !important;`n  -webkit-overflow-scrolling: touch;`n}"
```

Verify:

```powershell
Get-Content static\css\custom.css | Select-Object -Last 10
```

Hard refresh the browser (`Ctrl + Shift + R`) and confirm `display: block` and `overflow-x: auto` appear in DevTools Styles panel for the `table` element.

## Why display: block is Required
---

The `overflow-x: auto` property has no effect on `table` elements by default because tables use `display: table` which does not respect overflow in the same way as block elements. Setting `display: block` converts the table to a block container, allowing `overflow-x: auto` to create a horizontal scrollbar when the content exceeds the container width.

| Property | Purpose |
|----------|---------|
| `display: block` | Enables overflow behaviour on the table element |
| `overflow-x: auto` | Shows horizontal scrollbar only when content overflows |
| `-webkit-overflow-scrolling: touch` | Enables momentum-based scrolling on iOS Safari |
| `!important` | Overrides theme CSS that would otherwise win the specificity battle |

## Commit
---

```powershell
git add -A
git commit -m "Fix: mobile table overflow scroll via custom.css"
git push
```

## Key Lesson
---

Hugo sites using Mainroad (and likely other themes) load `static/css/custom.css` after `assets/css/style.css`. Any overrides intended to beat theme styles must go in `custom.css`, not `style.css`. Use browser DevTools Styles panel to identify which file and rule is winning before adding CSS — it shows the exact filename and whether rules are being overridden (crossed out).

## References
---

- Hugo Table Render Hooks: https://gohugo.io/render-hooks/tables/
- MDN overflow-x: https://developer.mozilla.org/en-US/docs/Web/CSS/overflow-x
- MDN display: https://developer.mozilla.org/en-US/docs/Web/CSS/display
- CSS Specificity: https://developer.mozilla.org/en-US/docs/Web/CSS/Specificity
