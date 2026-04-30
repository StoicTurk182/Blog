---
title: "Locating Mainroad Pagination CSS"
created: 2026-04-30T00:00:00
updated: 2026-04-30T00:00:00
---
# Locating Mainroad Pagination CSS

**Table of Contents**

1. [Markup Under Investigation](#markup-under-investigation)
2. [Why It Is Not Stock Mainroad](#why-it-is-not-stock-mainroad)
3. [Where the Controlling CSS Can Live](#where-the-controlling-css-can-live)
4. [Diagnostic Commands](#diagnostic-commands)
	1. [Find the CSS Rules](#find-the-css-rules)
	2. [Find the Partial That Emits the Markup](#find-the-partial-that-emits-the-markup)
	3. [DevTools Confirmation](#devtools-confirmation)
5. [Override CSS Template](#override-css-template)
6. [Where to Apply](#where-to-apply)
7. [If the Partial Lives in the Theme Submodule](#if-the-partial-lives-in-the-theme-submodule)
8. [Verification](#verification)
9. [References](#references)

Guide for locating the CSS that controls a custom Mainroad-style pagination block in a Hugo site, and applying overrides without modifying theme source files. Applies to a Hugo site using the Mainroad theme as a Git submodule with overrides in `static/css/custom.css`.

## Markup Under Investigation

```html
<nav class="pagination">
  <a href="/posts/page/2/" class="pagination-prev">
    <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
      <path d="M11.5 14.5 4 8l7.5-6.5v13z"></path>
    </svg>
    Previous
  </a>
  <span class="pagination-info">Page 3 of 3</span>
</nav>
```

The classes used are: `pagination`, `pagination-prev`, `pagination-info`, and (by inference) `pagination-next`.

## Why It Is Not Stock Mainroad

Stock Mainroad uses BEM (Block Element Modifier) naming for pagination, with double-underscore element separators:

| Class | Purpose |
|---|---|
| `pagination` | Wrapper |
| `pagination__item` | Each page link |
| `pagination__item--current` | Current page |

This is visible in the theme source `themes/mainroad/assets/css/style.css` under the `/* Pagination */` block, where rules target `.pagination__item` and `.pagination__item:hover, .pagination__item--current`. The markup you're inspecting uses single-hyphen modifiers (`pagination-prev`, `pagination-info`), which is incompatible with that selector set.

The most likely explanations, in descending order of probability:

1. A custom `pagination.html` partial has been added to your repository (either at `layouts/partials/pagination.html` to override the theme, or directly inside the theme submodule on your `custom-theme` branch).
2. An upstream change you pulled at some point introduced a reworked pagination template using these class names.
3. A copy-paste of pagination markup from another theme has been added inline somewhere.

In any of those cases, the matching CSS rules will be in one of a small set of files, listed below.

## Where the Controlling CSS Can Live

| Priority | Path | Likelihood | Why |
|---|---|---|---|
| 1 | `themes/mainroad/assets/css/style.css` | High | Compiled theme stylesheet; Hugo runs this through `resources.ExecuteAsTemplate` so it's also where `$highlightColor` injection happens. |
| 2 | `static/css/custom.css` | Medium | Your own override file. If an earlier session added the rules here directly, this is where they live. |
| 3 | `themes/mainroad/assets/css/_pagination.scss` or partial SCSS | Low | Only if your custom-theme branch broke the single-file `style.css` into partials. |
| 4 | Inline `<style>` in a layout | Low | Sometimes added inside `baseof.html` or a pagination partial. |
| 5 | No CSS at all | Possible | If the rules don't exist yet and the element is rendering with browser defaults plus `nav.pagination` inheritance, that explains why it looks unstyled. |

The Hugo site loads CSS in this order, so later files override earlier ones:

1. Theme `style.css` (processed by Hugo)
2. Files listed in `Params.customCSS` (your `static/css/custom.css`)

## Diagnostic Commands

Run these from the site root, e.g. `C:\Users\Administrator\Andrew J IT Labs\Blog`. Adjust the path to match your repository.

### Find the CSS Rules

```powershell
Get-ChildItem -Recurse -Include *.css,*.scss |
    Select-String -Pattern "pagination-prev|pagination-info|pagination-next"
```

This walks the entire site (including the theme submodule) and reports every CSS or SCSS line that mentions any of the three class names. The output gives you the exact file path and line number.

If you want to exclude the theme submodule and search only your site overrides:

```powershell
Get-ChildItem -Recurse -Include *.css,*.scss -Exclude themes |
    Where-Object { $_.FullName -notmatch '\\themes\\' } |
    Select-String -Pattern "pagination-prev|pagination-info|pagination-next"
```

### Find the Partial That Emits the Markup

```powershell
Get-ChildItem -Recurse -Include *.html |
    Select-String -Pattern "pagination-prev|pagination-info"
```

This locates the Go template that generates the HTML. Standard Hugo partial resolution order means a file at `layouts/partials/pagination.html` in the site root will override one at `themes/mainroad/layouts/partials/pagination.html`, so the closer-to-root match is the one actually being rendered.

### DevTools Confirmation

Open the rendered page in Chrome or Firefox, right-click on the `Previous` link, and choose Inspect. In the Styles panel, scroll until you find the rules matching `.pagination-prev`. The right-hand column shows the source file and line number, formatted as `style.css:412` or similar. Click the file name to jump to it. This gives you a definitive answer that does not depend on grep.

If no rules appear in the Styles panel apart from user-agent defaults and inherited rules, the conclusion is that no CSS exists for these classes yet, and the override block below will create the styling from scratch.

## Override CSS Template

Append this block to `static/css/custom.css`. It targets the exact classes in the snippet, lays them out as a horizontal flex bar, and pulls colour values from variables you can edit in one place.

```css
/* =============================================================================
   PAGINATION - Custom override for nav.pagination block
   Targets: .pagination, .pagination-prev, .pagination-next, .pagination-info
   Loaded after theme style.css so no !important is needed unless the theme
   defines stronger selectors for the same classes.
   ============================================================================= */

:root {
    --pagination-bg: #f5f5f5;
    --pagination-bg-hover: #cc0000;
    --pagination-fg: #000000;
    --pagination-fg-hover: #ffffff;
    --pagination-info-fg: #555555;
    --pagination-gap: 1rem;
    --pagination-pad-y: 0.6rem;
    --pagination-pad-x: 1rem;
}

nav.pagination {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: var(--pagination-gap);
    margin-top: 2rem;
    padding-top: 1.5rem;
    border-top: 1px solid #ebebeb;
}

nav.pagination .pagination-prev,
nav.pagination .pagination-next {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    padding: var(--pagination-pad-y) var(--pagination-pad-x);
    font-weight: 600;
    color: var(--pagination-fg);
    background: var(--pagination-bg);
    text-decoration: none;
    transition: background-color 0.2s ease, color 0.2s ease, transform 0.2s ease;
}

nav.pagination .pagination-prev:hover,
nav.pagination .pagination-next:hover {
    color: var(--pagination-fg-hover);
    background: var(--pagination-bg-hover);
}

nav.pagination .pagination-prev svg {
    transition: transform 0.2s ease;
}

nav.pagination .pagination-prev:hover svg {
    transform: translateX(-3px);
}

nav.pagination .pagination-next svg {
    transition: transform 0.2s ease;
}

nav.pagination .pagination-next:hover svg {
    transform: translateX(3px);
}

nav.pagination .pagination-info {
    font-size: 0.9rem;
    color: var(--pagination-info-fg);
    margin-left: auto;
}

/* Single child (only Prev or only Next) — push the info to the opposite side */
nav.pagination .pagination-prev:only-of-type ~ .pagination-info {
    margin-left: auto;
}
```

The `:root` custom properties keep colour and spacing values centralised, so further tweaks don't require hunting through selectors.

## Where to Apply

Edit the file at `static/css/custom.css` in your site root. This file is already declared in your `config.toml` under `Params.customCSS`, so Hugo will include it automatically:

```toml
[Params]
  customCSS = ["css/custom.css"]
```

After saving, run:

```powershell
hugo --minify
```

For local preview before deploying:

```powershell
hugo server -D
```

## If the Partial Lives in the Theme Submodule

If `Select-String` shows the partial inside `themes/mainroad/layouts/partials/`, copy it up to your site root rather than editing it inside the submodule. Hugo's partial resolution will then prefer your local copy:

```powershell
Copy-Item .\themes\mainroad\layouts\partials\pagination.html .\layouts\partials\pagination.html
```

This isolates any markup changes from the submodule and keeps `git pull` on the submodule clean. The same applies if the CSS rules live inside the theme — the cleaner workflow is to leave the theme rules untouched and override them in `static/css/custom.css`.

## Verification

After deploying, confirm in DevTools:

1. Open the page that shows pagination, e.g. `https://blog.ajolnet.com/posts/page/2/`.
2. Right-click the `Previous` link and choose Inspect.
3. In the Styles panel, the rules from `custom.css` should appear above (i.e. take precedence over) any rules from `style.css`.
4. Hover the link in the live page; background should transition to the override colour.

If the override does not take effect, the most likely cause is browser cache. Hard refresh with Ctrl+Shift+R, or append a cache-busting query string when loading the page.

## References

- Mainroad theme source: https://github.com/Vimux/Mainroad
- Hugo pagination documentation: https://gohugo.io/templates/pagination/
- Hugo partial template lookup order: https://gohugo.io/templates/lookup-order/
- MDN — CSS specificity and the cascade: https://developer.mozilla.org/en-US/docs/Web/CSS/Specificity
- MDN — `Select-String` equivalent (grep concept): https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/select-string
