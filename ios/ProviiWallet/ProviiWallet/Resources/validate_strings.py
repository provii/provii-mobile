#!/usr/bin/env python3
"""
Validate iOS Localizable.strings files for common issues.

Checks for:
1. Unescaped double quotes inside values
2. Missing semicolons
3. Malformed key-value pairs
4. Encoding issues

Usage:
    python3 validate_strings.py                    # Validate all .lproj files
    python3 validate_strings.py es.lproj           # Validate specific language
    python3 validate_strings.py --fix es.lproj     # Fix issues in place
"""

import os
import sys
import re
import glob
import subprocess

def find_unescaped_quotes(line, line_num):
    """Find unescaped quotes inside a value string."""
    issues = []

    # Match key = "value"; pattern
    match = re.match(r'^"([^"]+)"\s*=\s*"(.*)"\s*;\s*$', line)
    if not match:
        return issues

    key, value = match.groups()

    # Look for unescaped quotes in value
    # Valid: \" (escaped quote)
    # Invalid: " not preceded by \
    i = 0
    while i < len(value):
        if value[i] == '\\' and i + 1 < len(value):
            # Skip escaped character
            i += 2
            continue
        if value[i] == '"':
            issues.append({
                'line': line_num,
                'key': key,
                'type': 'unescaped_quote',
                'message': f'Unescaped quote in value at position {i}',
                'value_snippet': value[max(0,i-10):i+10]
            })
        i += 1

    return issues

def validate_line(line, line_num):
    """Validate a single line."""
    issues = []
    stripped = line.strip()

    # Skip empty lines and comments
    if not stripped or stripped.startswith('//') or stripped.startswith('/*'):
        return issues

    # Check for key-value format
    if stripped.startswith('"'):
        # Should match: "key" = "value";

        # Check for missing semicolon
        if not stripped.endswith(';'):
            # Could be a multi-line value or error
            if '";' not in stripped and '" =' in stripped:
                issues.append({
                    'line': line_num,
                    'type': 'missing_semicolon',
                    'message': 'Line appears to be missing semicolon',
                    'content': stripped[:80]
                })

        # Check for unescaped quotes
        issues.extend(find_unescaped_quotes(stripped, line_num))

    return issues

def validate_file(filepath):
    """Validate a Localizable.strings file."""
    issues = []

    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except UnicodeDecodeError:
        # Try UTF-16
        try:
            with open(filepath, 'r', encoding='utf-16') as f:
                lines = f.readlines()
        except Exception as e:
            return [{'line': 0, 'type': 'encoding', 'message': f'Cannot read file: {e}'}]

    in_multiline_comment = False

    for i, line in enumerate(lines, 1):
        # Track multi-line comments
        if '/*' in line:
            in_multiline_comment = True
        if '*/' in line:
            in_multiline_comment = False
            continue
        if in_multiline_comment:
            continue

        issues.extend(validate_line(line, i))

    # Also run plutil for additional validation
    result = subprocess.run(['plutil', '-lint', filepath],
                          capture_output=True, text=True)
    if 'OK' not in result.stdout:
        issues.append({
            'line': 0,
            'type': 'plutil',
            'message': result.stderr.strip()
        })

    return issues

def fix_unescaped_quotes(content):
    """Fix unescaped quotes in a strings file content."""
    lines = content.split('\n')
    fixed_lines = []

    for line in lines:
        stripped = line.strip()

        # Skip non-data lines
        if not stripped.startswith('"') or '=' not in stripped:
            fixed_lines.append(line)
            continue

        # Parse key and value
        match = re.match(r'^(\s*)"([^"]+)"\s*=\s*"(.*)";\s*$', line)
        if not match:
            fixed_lines.append(line)
            continue

        indent, key, value = match.groups()

        # Fix unescaped quotes in value
        fixed_value = []
        i = 0
        while i < len(value):
            if value[i] == '\\' and i + 1 < len(value):
                # Keep escaped sequences as-is
                fixed_value.append(value[i:i+2])
                i += 2
            elif value[i] == '"':
                # Escape unescaped quote
                fixed_value.append('\\"')
                i += 1
            else:
                fixed_value.append(value[i])
                i += 1

        fixed_line = f'{indent}"{key}" = "{"".join(fixed_value)}";'
        fixed_lines.append(fixed_line)

    return '\n'.join(fixed_lines)

def main():
    args = sys.argv[1:]
    fix_mode = '--fix' in args
    if fix_mode:
        args.remove('--fix')

    # Determine which files to validate
    if args:
        targets = args
    else:
        targets = glob.glob('*.lproj')

    total_issues = 0
    files_with_issues = []

    for target in targets:
        if os.path.isdir(target):
            filepath = os.path.join(target, 'Localizable.strings')
        else:
            filepath = target

        if not os.path.exists(filepath):
            print(f"Skipping {target}: file not found")
            continue

        issues = validate_file(filepath)

        if issues:
            files_with_issues.append(target)
            total_issues += len(issues)
            print(f"\n❌ {target}: {len(issues)} issue(s)")
            for issue in issues[:10]:  # Show first 10
                print(f"   Line {issue.get('line', '?')}: {issue['type']} - {issue['message']}")
            if len(issues) > 10:
                print(f"   ... and {len(issues) - 10} more")

            if fix_mode and any(i['type'] == 'unescaped_quote' for i in issues):
                print(f"   Fixing {filepath}...")
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()
                fixed = fix_unescaped_quotes(content)
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(fixed)
                print(f"   Fixed!")
        else:
            print(f"✓ {target}: OK")

    print(f"\n{'='*50}")
    print(f"Total: {len(targets)} files checked, {len(files_with_issues)} with issues, {total_issues} total issues")

    if files_with_issues:
        print(f"\nFiles with issues: {', '.join(files_with_issues)}")
        return 1
    return 0

if __name__ == '__main__':
    sys.exit(main())
