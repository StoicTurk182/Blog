document.addEventListener('DOMContentLoaded', function() {
    const copyIcon = `<svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor"><path d="M0 6.75C0 5.784.784 5 1.75 5h1.5a.75.75 0 0 1 0 1.5h-1.5a.25.25 0 0 0-.25.25v7.5c0 .138.112.25.25.25h7.5a.25.25 0 0 0 .25-.25v-1.5a.75.75 0 0 1 1.5 0v1.5A1.75 1.75 0 0 1 9.25 16h-7.5A1.75 1.75 0 0 1 0 14.25Z"></path><path d="M5 1.75C5 .784 5.784 0 6.75 0h7.5C15.216 0 16 .784 16 1.75v7.5A1.75 1.75 0 0 1 14.25 11h-7.5A1.75 1.75 0 0 1 5 9.25Zm1.75-.25a.25.25 0 0 0-.25.25v7.5c0 .138.112.25.25.25h7.5a.25.25 0 0 0 .25-.25v-7.5a.25.25 0 0 0-.25-.25Z"></path></svg>`;
    const checkIcon = `<svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor"><path d="M13.78 4.22a.75.75 0 0 1 0 1.06l-7.25 7.25a.75.75 0 0 1-1.06 0L2.22 9.28a.751.751 0 0 1 .018-1.042.751.751 0 0 1 1.042-.018L6 10.94l6.72-6.72a.75.75 0 0 1 1.06 0Z"></path></svg>`;

    document.querySelectorAll('.highlight').forEach(highlight => {
        // --- CLEANUP START ---
        // Find and remove ANY existing buttons, spans, or SVGs injected by the theme
        // We look for common theme classes like 'copy', 'btn', or just raw SVGs
        const themeElements = highlight.querySelectorAll('button, .copy-code, .copy-button, svg, i.fa');
        themeElements.forEach(el => el.remove());
        // --- CLEANUP END ---

        const btn = document.createElement('button');
        btn.className = 'copy-code-btn';
        btn.innerHTML = copyIcon;
        btn.setAttribute('aria-label', 'Copy code');

        btn.addEventListener('click', async () => {
            const code = highlight.querySelector('code')?.innerText || highlight.innerText;
            try {
                await navigator.clipboard.writeText(code);
                btn.innerHTML = checkIcon;
                btn.classList.add('copied');
                setTimeout(() => {
                    btn.innerHTML = copyIcon;
                    btn.classList.remove('copied');
                }, 2000);
            } catch (err) { console.error('Copy failed', err); }
        });

        highlight.appendChild(btn);
    });
});

    // 2. Setup Dropdowns
    document.querySelectorAll('.custom-dropdown').forEach(dropdown => {
        const btn = dropdown.querySelector('.dropdown-selected');
        if (!btn) return;

        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            document.querySelectorAll('.custom-dropdown.open').forEach(open => {
                if (open !== dropdown) open.classList.remove('open');
            });
            dropdown.classList.toggle('open');
        });
    });

    document.addEventListener('click', () => {
        document.querySelectorAll('.custom-dropdown.open').forEach(d => d.classList.remove('open'));
    });
});


// Simple dropdown toggle for multiple dropdowns
document.addEventListener('DOMContentLoaded', function() {
    document.querySelectorAll('.custom-dropdown').forEach(function(dropdown) {
        var btn = dropdown.querySelector('.dropdown-selected');
        var list = dropdown.querySelector('.dropdown-list');

        if (btn && list) {
            btn.addEventListener('click', function(e) {
                e.stopPropagation();
                // Close other open dropdowns
                document.querySelectorAll('.custom-dropdown.open').forEach(function(openDropdown) {
                    if (openDropdown !== dropdown) openDropdown.classList.remove('open');
                });
                dropdown.classList.toggle('open');
            });

            // Optional: close on ESC
            dropdown.addEventListener('keydown', function(e) {
                if (e.key === "Escape") dropdown.classList.remove('open');
            });
        }
    });

    // Close dropdowns when clicking outside
    document.addEventListener('click', function() {
        document.querySelectorAll('.custom-dropdown.open').forEach(function(dropdown) {
            dropdown.classList.remove('open');
        });
    });
});