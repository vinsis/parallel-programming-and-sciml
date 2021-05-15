# parallel-programming-and-sciml
Code and notes for using Julia for parallel programming and SciML

## How to use Julia with VSCode
`↩`: Enter
`⌘`: Command
`⇧`: Shift
`⌃`: Control
`⌥`: Option

- Open command palette with `⌘ + ⇧ + P` then pick `Julia: Start REPL`
- `⌃ + ↩`: This command will either send the text that is currently selected in the active editor to the Julia REPL, or it will send the entire line where the cursor is currently positioned when no text is selected. 
- `⌥ + ↩`: Whenever, there is some Julia code selected in the currently active editor, this command will execute the selected code. If no text is selected, the command will identify the extent of the top-level language construct that the cursor is located in (except modules) and execute that code block.
- `⇧ + ↩`: The extension provides support for demarking code cells in standard Julia files with a specially formatted comment: ##. This command will identify in which code cell the cursor in the active editor currently is and then execute the code in that cell. If there are no code cells used in the current file, it will execute the entire file.