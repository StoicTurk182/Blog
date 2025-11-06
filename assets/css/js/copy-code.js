// Copy code functionality for Mainroad theme
document.addEventListener('DOMContentLoaded', function() {
    // Add copy buttons to all code blocks
    document.querySelectorAll('.highlight').forEach(function(highlight) {
        // Skip if already has copy button
        if (highlight.querySelector('.copy-code-btn')) return;
        
        const copyButton = document.createElement('button');
        copyButton.className = 'copy-code-btn';
        copyButton.innerHTML = '📋 Copy';
        copyButton.title = 'Copy code to clipboard';
        
        // Style for Mainroad theme
        copyButton.style.cssText = `
            position: absolute;
            top: 8px;
            right: 8px;
            background: rgba(255,255,255,0.9);
            border: 1px solid #e1e4e8;
            border-radius: 4px;
            padding: 4px 12px;
            font-size: 12px;
            cursor: pointer;
            opacity: 0;
            transition: all 0.2s ease;
            z-index: 10;
            font-family: system-ui, -apple-system, sans-serif;
            color: #24292e;
        `;
        
        highlight.style.position = 'relative';
        
        // Show button on hover
        highlight.addEventListener('mouseenter', function() {
            copyButton.style.opacity = '1';
        });
        
        highlight.addEventListener('mouseleave', function() {
            copyButton.style.opacity = '0';
        });
        
        // Copy functionality
        copyButton.addEventListener('click', async function() {
            const code = highlight.querySelector('code')?.textContent || highlight.textContent;
            try {
                await navigator.clipboard.writeText(code);
                copyButton.innerHTML = '✅ Copied!';
                copyButton.style.background = '#d4edda';
                copyButton.style.borderColor = '#c3e6cb';
                copyButton.style.color = '#155724';
                setTimeout(() => {
                    copyButton.innerHTML = '📋 Copy';
                    copyButton.style.background = 'rgba(255,255,255,0.9)';
                    copyButton.style.borderColor = '#e1e4e8';
                    copyButton.style.color = '#24292e';
                }, 2000);
            } catch (err) {
                // Fallback for older browsers
                const textArea = document.createElement('textarea');
                textArea.value = code;
                document.body.appendChild(textArea);
                textArea.select();
                document.execCommand('copy');
                document.body.removeChild(textArea);
                
                copyButton.innerHTML = '✅ Copied!';
                copyButton.style.background = '#d4edda';
                copyButton.style.borderColor = '#c3e6cb';
                setTimeout(() => {
                    copyButton.innerHTML = '📋 Copy';
                    copyButton.style.background = 'rgba(255,255,255,0.9)';
                    copyButton.style.borderColor = '#e1e4e8';
                }, 2000);
            }
        });
        
        highlight.appendChild(copyButton);
    });
});