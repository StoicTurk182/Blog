#!/usr/bin/env python3
"""
Add horizontal rules (---) under all headings in markdown files.
Usage: python3 add_heading_underlines.py [directory]
"""

import os
import sys
import re
from pathlib import Path

def process_markdown_file(filepath):
    """Add --- under headings in a markdown file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    new_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]
        new_lines.append(line)
        
        # Check if this is a heading (## or more, but not # which is usually title)
        if re.match(r'^##+ ', line.strip()):
            # Look ahead to see if next line is already a horizontal rule
            next_line = lines[i + 1].strip() if i + 1 < len(lines) else ''
            
            # Don't add if next line is already ---, ===, or empty followed by ---
            if next_line not in ['---', '===', '___', '***']:
                # Add the horizontal rule
                new_lines.append('---\n')
        
        i += 1
    
    # Write back to file
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    
    return True

def main():
    # Get directory from command line or use current directory
    directory = sys.argv[1] if len(sys.argv) > 1 else '.'
    
    # Convert to Path object
    base_path = Path(directory)
    
    if not base_path.exists():
        print(f"Error: Directory '{directory}' does not exist")
        sys.exit(1)
    
    # Find all markdown files
    markdown_files = list(base_path.rglob('*.md')) + list(base_path.rglob('*.markdown'))
    
    if not markdown_files:
        print(f"No markdown files found in {directory}")
        sys.exit(0)
    
    print(f"Found {len(markdown_files)} markdown file(s)")
    print()
    
    # Process each file
    for md_file in markdown_files:
        print(f"Processing: {md_file}")
        try:
            process_markdown_file(md_file)
            print(f"  ✓ Added underlines")
        except Exception as e:
            print(f"  ✗ Error: {e}")
    
    print()
    print("Done! All markdown files processed.")

if __name__ == '__main__':
    main()
