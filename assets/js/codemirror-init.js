import {EditorView, basicSetup} from "codemirror"
import {EditorState} from "@codemirror/state"
import {keymap} from "@codemirror/view"
import {indentWithTab} from "@codemirror/commands"
import {python} from "@codemirror/lang-python"
import {StreamLanguage} from "@codemirror/language"
import {powerShell} from "@codemirror/legacy-modes/mode/powershell"

const languageExtensions = {
    python: () => python(),
    py: () => python(),
    powershell: () => StreamLanguage.define(powerShell),
    ps1: () => StreamLanguage.define(powerShell),
    pwsh: () => StreamLanguage.define(powerShell)
}

function initCodeMirror() {
    const codeBlocks = document.querySelectorAll('[data-codemirror]')
    
    codeBlocks.forEach(block => {
        const language = block.dataset.language || 'python'
        const readOnly = block.dataset.readonly === 'true'
        const content = block.textContent || ''
        
        block.textContent = ''
        
        const extensions = [
            basicSetup,
            keymap.of([indentWithTab]),
            EditorView.lineWrapping
        ]
        
        if (languageExtensions[language.toLowerCase()]) {
            extensions.push(languageExtensions[language.toLowerCase()]())
        }
        
        if (readOnly) {
            extensions.push(EditorState.readOnly.of(true))
        }
        
        new EditorView({
            state: EditorState.create({
                doc: content.trim(),
                extensions: extensions
            }),
            parent: block
        })
    })
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initCodeMirror)
} else {
    initCodeMirror()
}