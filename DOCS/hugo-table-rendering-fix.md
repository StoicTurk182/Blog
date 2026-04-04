# Hugo Table Rendering Fix

Documentation of the investigation and resolution of three related table rendering issues on blog.ajolnet.com. All fixes were applied to `static/css/custom.css` which loads after the Mainroad theme stylesheet and therefore takes precedence.

## Problems

| Issue | Symptom |
|-------|---------|
| Mobile overflow | Tables with 3+ columns collapsed instead of scrolling horizontally |
| Phantom column | Tables appeared to have a blank third column on wide viewports |
| Border styling | Rounded corners and mismatched border colour inconsistent with theme |

## Environment

| Component | Detail |
|-----------|--------|
| Hugo version | v0.154.5 extended |
| Theme | Mainroad |
| Custom CSS | `static/css/custom.css` |
| Asset CSS | `assets/css/style.css` |

---

## Investigation

### Locating existing CSS

```powershell
Get-ChildItem -Recurse -Include "*.css","*.scss" | Select-String -Pattern "table|overflow-x" | Select-Object Filename, LineNumber, Line
```

Result showed `.table-wrapper` CSS already existed in `assets/css/style.css` but no render hook was in place to output the wrapper div. A bare `table` rule with `overflow-x: auto` was also absent.

### Render hook attempt

A Hugo table render hook was created at `layouts/_default/_markup/render-table.html` to wrap tables in a scrollable div. Hugo 0.134+ uses `.THead` and `.TBody` methods on the table context — earlier field names `.Body`, `.Header`, and `.Rows` are not valid and produce build errors.

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

The hook built without errors but tables remained unaffected. Inspecting rendered HTML confirmed plain `<table>` elements with no wrapper div, indicating the hook was not being invoked. This approach was abandoned in favour of a pure CSS solution.

### Identifying the correct stylesheet

Adding `overflow-x: auto` to `assets/css/style.css` had no effect. Browser DevTools Styles panel showed the rule was present but the Mainroad theme's `article table` block at higher specificity was overriding it. The bare `table` selector in `style.css` was losing the specificity battle.

Running the following confirmed a second stylesheet:

```powershell
Get-ChildItem -Recurse -Include "*.css" | Select-Object FullName
```

`static/css/custom.css` loads after `assets/css/style.css` and therefore takes priority. All fixes were moved there.

### Phantom column root cause

DevTools inspection of the rendered `<table>` HTML confirmed exactly 2 columns — the markdown and Hugo output were correct. The phantom column was a CSS width issue. The `article table` rule in the Mainroad theme sets `width: 100%`, causing the two-column table to stretch across the full container width and leaving visible whitespace that appeared as a third column.

### Border root cause

The same `article table` rule at line 158 of the theme CSS applied `border-radius: 4px` and `border: 1px solid rgba(255, 255, 255, .1)` — rounded corners and a low-contrast border inconsistent with the sharp `#ebebeb` borders used elsewhere on the site.

---

## Fix

All rules added to `static/css/custom.css`:

```css
/* Table */
table {
  display: block !important;
  width: 100%;
  overflow-x: auto !important;
  -webkit-overflow-scrolling: touch;
}

/* Table width fix */
article table {
  width: max-content !important;
  max-width: 100%;
}

/* Table border fix */
article table {
  border-radius: 0 !important;
  border: 1px solid #ebebeb !important;
}
```

### Why each property is needed

| Property | Purpose |
|----------|---------|
| `display: block !important` | Enables overflow behaviour — tables use `display: table` by default which ignores `overflow-x` |
| `overflow-x: auto !important` | Horizontal scrollbar appears only when content exceeds container width |
| `-webkit-overflow-scrolling: touch` | Momentum scrolling on iOS Safari |
| `width: max-content !important` | Table only as wide as its content, eliminating phantom column |
| `max-width: 100%` | Prevents table overflowing its container on narrow viewports |
| `border-radius: 0 !important` | Removes theme rounded corners |
| `border: 1px solid #ebebeb !important` | Matches the sharp border style used elsewhere in the theme |

---

## PowerShell Commands Used

Find all CSS files and table-related rules:

```powershell
Get-ChildItem -Recurse -Include "*.css","*.scss" | Select-String -Pattern "table|overflow-x" | Select-Object Filename, LineNumber, Line
```

Append rules to custom.css:

```powershell
Add-Content static\css\custom.css "`n/* Table */`ntable {`n  display: block !important;`n  width: 100%;`n  overflow-x: auto !important;`n  -webkit-overflow-scrolling: touch;`n}"

Add-Content static\css\custom.css "`n/* Table width fix */`narticle table {`n  width: max-content !important;`n  max-width: 100%;`n}"

Add-Content static\css\custom.css "`n/* Table border fix */`narticle table {`n  border-radius: 0 !important;`n  border: 1px solid #ebebeb !important;`n}"
```

Verify changes landed:

```powershell
Get-Content static\css\custom.css | Select-Object -Last 20
```

---

## Commit

```powershell
git add -A
git commit -m "Fix: mobile table overflow, width, border radius and border colour"
git push
```

---

## Key Lessons

### CSS load order matters

Hugo sites using Mainroad load `static/css/custom.css` after `assets/css/style.css`. Any rules intended to override theme styles must go in `custom.css`. Rules in `style.css` lose the specificity battle against the theme.

### Use DevTools Styles panel to diagnose overrides

The Styles panel shows every rule affecting an element in cascade order, with overridden rules crossed out and the source filename and line number next to each block. This is the fastest way to identify which stylesheet and selector is winning.

### Specificity matching

The Mainroad theme uses `article table` as its selector. To reliably override it, use the same selector in `custom.css` rather than bare `table`. Where the theme uses `!important`, mirror it.

### Render hook field names changed in Hugo 0.134

Table render hook templates use `.THead` and `.TBody`. The fields `.Header`, `.Body`, and `.Rows` are not valid in Hugo 0.134+ and will produce build errors referencing `tableContext`.

---

## References

- Hugo Table Render Hooks: https://gohugo.io/render-hooks/tables/
- MDN overflow-x: https://developer.mozilla.org/en-US/docs/Web/CSS/overflow-x
- MDN width: max-content: https://developer.mozilla.org/en-US/docs/Web/CSS/width
- CSS Specificity: https://developer.mozilla.org/en-US/docs/Web/CSS/Specificity
- Mainroad Theme: https://github.com/Vimux/Mainroad
