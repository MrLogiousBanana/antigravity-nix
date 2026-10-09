#!/usr/bin/env python3
"""
Open Antigravity Eligibility Patcher (Pure Python)
Bypasses region and auth eligibility restrictions in Google Antigravity CLI and Manager
Derived from Open Antigravity / QNIX-Dev eligibility-antigravity-patcher.
Zero external dependencies (pure Python standard library).
"""

import sys
import os
import re
import struct
import argparse

# ----------------- ELF Executable Ranges & Arch -----------------

def get_elf_executable_info(data):
    if len(data) < 16 or data[:4] != b"\x7fELF":
        return ((0, len(data)),), "unknown"
    elf_class = data[4]
    data_order = data[5]
    endian = "<" if data_order == 1 else ">" if data_order == 2 else None
    if not endian:
        return ((0, len(data)),), "unknown"
    machine = struct.unpack(endian + "H", data[18:20])[0] if len(data) >= 20 else 0
    arch = {0x8664: "x64", 0x3e: "x64", 0xaa64: "arm64", 0xb7: "arm64"}.get(machine, "unknown")

    ranges = []
    if elf_class == 2:  # 64-bit ELF
        phoff = struct.unpack_from(endian + "Q", data, 32)[0]
        phentsize, phnum = struct.unpack_from(endian + "HH", data, 54)
        for i in range(phnum):
            entry_offset = phoff + i * phentsize
            if entry_offset + 32 > len(data):
                break
            p_type = struct.unpack_from(endian + "I", data, entry_offset)[0]
            p_flags = struct.unpack_from(endian + "I", data, entry_offset + 4)[0]
            p_offset = struct.unpack_from(endian + "Q", data, entry_offset + 8)[0]
            p_filesz = struct.unpack_from(endian + "Q", data, entry_offset + 32)[0]
            if p_type == 1 and (p_flags & 1):  # PT_LOAD and PF_X
                ranges.append((p_offset, min(len(data), p_offset + p_filesz)))
    elif elf_class == 1:  # 32-bit ELF
        phoff = struct.unpack_from(endian + "I", data, 28)[0]
        phentsize, phnum = struct.unpack_from(endian + "HH", data, 42)
        for i in range(phnum):
            entry_offset = phoff + i * phentsize
            if entry_offset + 20 > len(data):
                break
            p_type = struct.unpack_from(endian + "I", data, entry_offset)[0]
            p_offset = struct.unpack_from(endian + "I", data, entry_offset + 4)[0]
            p_filesz = struct.unpack_from(endian + "I", data, entry_offset + 16)[0]
            p_flags = struct.unpack_from(endian + "I", data, entry_offset + 24)[0]
            if p_type == 1 and (p_flags & 1):
                ranges.append((p_offset, min(len(data), p_offset + p_filesz)))

    return (ranges or ((0, len(data)),)), arch

# ----------------- Signatures & Gates -----------------

class Gate:
    def __init__(self, unpatched_sig, patched_sig, fix, offset=0, name="gate", arch=None):
        self.unpatched_re = re.compile(unpatched_sig, re.S)
        self.patched_re = re.compile(patched_sig, re.S)
        self.fix = fix
        self.offset = offset
        self.name = name
        self.arch = arch

CLI_GATES = [
    # CLI 1.2.16+ x64 (current)
    Gate(
        rb"\x48\x85\xc0\x0f\x84....\x80\x78\x08\x00\x0f\x85...."
        rb"\xe8....\x48\x89\x84\x24\xd8\x00\x00\x00"
        rb"\x48\x89\x9c\x24\xe0\x00\x00\x00\x48\x89\x8c\x24\xe8\x00\x00\x00",
        rb"\x48\x85\xc0\x0f\x84....\x48\x85\xc0\x90\x0f\x85...."
        rb"\xe8....\x48\x89\x84\x24\xd8\x00\x00\x00"
        rb"\x48\x89\x9c\x24\xe0\x00\x00\x00\x48\x89\x8c\x24\xe8\x00\x00\x00",
        b"\x48\x85\xc0\x90", offset=9, name="cli_x64_current", arch="x64"
    ),
    # CLI x64 stack80 (1.2.x)
    Gate(
        rb"\x48\x85\xc0\x0f\x84....\x80\x78\x08\x00\x0f\x85...."
        rb"\xe8....\x48\x89\x84\x24\x80\x00\x00\x00\x48\x89\x5c\x24\x50"
        rb"\x48\x89\x4c\x24\x70",
        rb"\x48\x85\xc0\x0f\x84....\x48\x85\xc0\x90\x0f\x85...."
        rb"\xe8....\x48\x89\x84\x24\x80\x00\x00\x00\x48\x89\x5c\x24\x50"
        rb"\x48\x89\x4c\x24\x70",
        b"\x48\x85\xc0\x90", offset=9, name="cli_x64_stack80", arch="x64"
    ),
    # CLI x64 stack88
    Gate(
        rb"\x48\x85\xc0\x0f\x84....\x80\x78\x08\x00\x0f\x85...."
        rb"\xe8....\x48\x89\x84\x24\x88\x00\x00\x00\x48\x89\x5c\x24\x50"
        rb"\x48\x89\x4c\x24\x78",
        rb"\x48\x85\xc0\x0f\x84....\x48\x85\xc0\x90\x0f\x85...."
        rb"\xe8....\x48\x89\x84\x24\x88\x00\x00\x00\x48\x89\x5c\x24\x50"
        rb"\x48\x89\x4c\x24\x78",
        b"\x48\x85\xc0\x90", offset=9, name="cli_x64_stack88", arch="x64"
    ),
    # CLI ARM64 (Linux/macOS)
    Gate(
        rb"\x02\x20\x40\x39[\x02\x22\x42\x62\x82\xa2\xc2\xe2].[\x00-\x07]\x37"
        rb"...[\x94-\x97]\xe0\x07\x0e\xa9\xe2\x0f\x0f\xa9\xe4\x17\x10\xa9\xe6\x1f\x11\xa9",
        rb"\x22\x00\x80\x52[\x02\x22\x42\x62\x82\xa2\xc2\xe2].[\x00-\x07]\x37"
        rb"...[\x94-\x97]\xe0\x07\x0e\xa9\xe2\x0f\x0f\xa9\xe4\x17\x10\xa9\xe6\x1f\x11\xa9",
        b"\x22\x00\x80\x52", offset=0, name="cli_arm64", arch="arm64"
    ),
]

MANAGER_GATES = [
    # Manager x64 (language_server)
    Gate(
        rb"\x80\x78\x08\x00\x74.\x48\x8b.\x24.\x48\x89.\x60",
        rb"\xc6\x40\x08\x01\x90\x90\x48\x8b.\x24.\x48\x89.\x60",
        b"\xc6\x40\x08\x01\x90\x90", offset=0, name="manager_x64", arch="x64"
    ),
    # Manager ARM64 (language_server)
    Gate(
        rb"\x03\x20\x40\x39[\x03\x23\x43\x63\x83\xa3\xc3\xe3]."
        rb"[\x00-\x07]\x36\xe3\x13\x48\xa9\x03\x10\x06\xa9",
        rb"\x23\x00\x80\x52\x03\x20\x00\x39\xe3\x13\x48\xa9"
        rb"\x03\x10\x06\xa9",
        b"\x23\x00\x80\x52\x03\x20\x00\x39", offset=0, name="manager_arm64", arch="arm64"
    ),
]

# ----------------- Patch Function -----------------

def patch_binary(file_path, target_type, dry_run=False):
    if not os.path.isfile(file_path):
        print(f"Error: Target file not found: {file_path}", file=sys.stderr)
        return False

    with open(file_path, "rb") as f:
        data = bytearray(f.read())

    ranges, detected_arch = get_elf_executable_info(data)
    print(f"[*] Analyzing {file_path} (size={len(data)}, detected arch={detected_arch})")

    gates = CLI_GATES if target_type == "cli" else MANAGER_GATES

    # Filter gates by architecture if known
    matching_gates = [g for g in gates if detected_arch == "unknown" or g.arch is None or g.arch == detected_arch]
    if not matching_gates:
        matching_gates = gates

    # Search in executable ranges
    found_patched = None
    found_unpatched = None
    selected_gate = None

    for gate in matching_gates:
        for start, end in ranges:
            chunk = data[start:end]
            
            # Check patched first
            m_patched = gate.patched_re.search(chunk)
            if m_patched:
                found_patched = start + m_patched.start() + gate.offset
                selected_gate = gate
                break
            
            # Check unpatched
            m_unpatched = gate.unpatched_re.search(chunk)
            if m_unpatched:
                found_unpatched = start + m_unpatched.start() + gate.offset
                selected_gate = gate
                break
        if found_patched or found_unpatched:
            break

    if found_patched is not None:
        print(f"[OK] {target_type.upper()} is already patched ({selected_gate.name} at 0x{found_patched:x})")
        return True

    if found_unpatched is None:
        print(f"[ERROR] Could not find patch signature for {target_type} in {file_path}", file=sys.stderr)
        return False

    print(f"[*] Found unpatched gate ({selected_gate.name}) at offset 0x{found_unpatched:x}")
    if dry_run:
        print("[*] Dry run mode; no changes written.")
        return True

    # Apply patch
    fix = selected_gate.fix
    data[found_unpatched : found_unpatched + len(fix)] = fix

    # Verify
    verify_match = False
    for start, end in ranges:
        if selected_gate.patched_re.search(data[start:end]):
            verify_match = True
            break

    if not verify_match:
        print("[ERROR] Post-patch signature verification failed!", file=sys.stderr)
        return False

    # Write out
    with open(file_path, "wb") as f:
        f.write(data)

    print(f"[SUCCESS] Successfully patched {target_type.upper()} ({selected_gate.name} at 0x{found_unpatched:x})")
    return True

def main():
    parser = argparse.ArgumentParser(description="Open Antigravity Eligibility Patcher")
    parser.add_argument("type", choices=["cli", "manager"], help="Target type: 'cli' (agy) or 'manager' (language_server)")
    parser.add_argument("file", help="Path to binary file")
    parser.add_argument("--dry-run", action="store_true", help="Only verify without modifying")
    args = parser.parse_args()

    success = patch_binary(args.file, args.type, dry_run=args.dry_run)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
