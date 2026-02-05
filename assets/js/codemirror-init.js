import {EditorView, basicSetup} from "codemirror"
import {EditorState} from "@codemirror/state"
import {keymap} from "@codemirror/view"
import {indentWithTab} from "@codemirror/commands"
import {python} from "@codemirror/lang-python"
import {StreamLanguage, syntaxHighlighting} from "@codemirror/language"
import {powerShell} from "@codemirror/legacy-modes/mode/powershell"
import {oneDarkHighlightStyle} from "@codemirror/theme-one-dark"

// --- 1. Custom Black & Red Theme ---
const customBlackTheme = EditorView.theme({
    "&": {
        backgroundColor: "#000000",
        color: "#abb2bf" 
    },
    ".cm-content": {
        caretColor: "#ffffff"
    },
    ".cm-scroller": {
        fontFamily: "'Consolas', 'Monaco', monospace",
        overflow: "auto"
    },
    ".cm-gutters": {
        backgroundColor: "#000000",
        color: "#ff0000", 
        borderRight: "1px solid #333"
    },
    ".cm-activeLine": {
        backgroundColor: "#1a1a1a"
    },
    "&.cm-focused": {
        outline: "none"
    }
}, {dark: true})

const languageExtensions = {
    python: () => python(),
    py: () => python(),
    powershell: () => StreamLanguage.define(powerShell),
    ps1: () => StreamLanguage.define(powerShell),
    pwsh: () => StreamLanguage.define(powerShell)
}

// --- Helper: Deep Clean HTML Entities ---
function decodeHtmlEntities(text) {
    // 1. Basic decode using a temporary element
    const txt = document.createElement("textarea");
    txt.innerHTML = text;
    let decoded = txt.value;

    // 2. Aggressive manual fix for stubborn leftovers (Common Copy/Paste errors)
    // If the text was double-escaped, the step above might not catch everything.
    return decoded
        .replace(/&gt;/g, '>')
        .replace(/&lt;/g, '<')
        .replace(/&amp;/g, '&')
        .replace(/&#34;/g, '"')
        .replace(/&quot;/g, '"');
}

function initCodeMirror() {
    const containers = document.querySelectorAll('.codemirror-container')
    
    containers.forEach(container => {
        const language = container.dataset.language || 'python'
        const readOnly = container.dataset.readonly === 'true'
        
        // Find the textarea inside
        const textarea = container.querySelector('textarea')
        if (!textarea) return;

        // --- THE FIX: Apply the Deep Clean ---
        // We take the value and run it through our cleaner function
        const rawContent = textarea.value;
        const cleanContent = decodeHtmlEntities(rawContent);
        
        container.innerHTML = '';
        
        const extensions = [
            basicSetup,
            keymap.of([indentWithTab]),
            EditorView.lineWrapping,
            customBlackTheme,
            syntaxHighlighting(oneDarkHighlightStyle)
        ];
        
        if (languageExtensions[language.toLowerCase()]) {
            extensions.push(languageExtensions[language.toLowerCase()]())
        }
        
        if (readOnly) {
            extensions.push(EditorState.readOnly.of(true))
        }
        
        new EditorView({
            state: EditorState.create({
                doc: cleanContent.trim(),
                extensions: extensions
            }),
            parent: container
        })
    })
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initCodeMirror)
} else {
    initCodeMirror()
}