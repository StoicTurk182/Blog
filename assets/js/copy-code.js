document.querySelectorAll('.highlight').forEach(function(highlight) {
    if (highlight.querySelector('.copy-code-btn')) return;
    
    const copyButton = document.createElement('button');
    copyButton.className = 'copy-code-btn'; // Use ONLY the class name
    copyButton.innerHTML = 'Copy';

        copyButton.addEventListener('click', async function() {
            const code = highlight.querySelector('code')?.innerText || highlight.innerText;
            
            try {
                await navigator.clipboard.writeText(code);
                copyButton.innerHTML = 'Copied!';
                copyButton.classList.add('copied'); // You can add specific "success" CSS if you want
                
                setTimeout(() => {
                    copyButton.innerHTML = 'Copy';
                    copyButton.classList.remove('copied');
                }, 2000);
            } catch (err) {
                // Basic fallback
                const textArea = document.createElement('textarea');
                textArea.value = code;
                document.body.appendChild(textArea);
                textArea.select();
                document.execCommand('copy');
                document.body.removeChild(textArea);
                copyButton.innerHTML = 'Copied!';
                setTimeout(() => { copyButton.innerHTML = 'Copy'; }, 2000);
            }
        });
        
        highlight.appendChild(copyButton);
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