#!/usr/bin/env python3
"""
Parse .logs and detect memory range overlaps per MemoryBTree configuration.

HOW IT WORKS
------------
Scans the log for section boundaries marked by:
  "• MemoryBTree with node capacity <N>, merge threshold <T>, tail compression <T/F>, prefix compression <T/F>"

For each section, two independent trackers run in parallel:

1. BTree-level tracker
   Parses lines of the form:
     stdout [TAG] region=data addr=... end=...
   Tags: LEAF_ALLOC / BRANCH_KEY_ALLOC / PREFIX_KEY_ALLOC
         LEAF_FREE  / BRANCH_KEY_FREE  / PREFIX_KEY_FREE
         LEAF_KEY_RESIZE / BRANCH_KEY_RESIZE / PREFIX_KEY_RESIZE

2. MemoryRegion-level tracker
   Parses lines of the form:
     stdout MR_ALLOC   rid=<id> bytes=<n> addr=<result>
     stdout MR_DEALLOC rid=<id> addr=<n>  size=<n>
     stdout MR_RESIZE  rid=<id> old_addr=<n> size=<n> new_size=<n> new_addr=<result>

OUTPUT
------
For each section: prints violations, then summary.
Final table compares all sections side-by-side.
"""

import re
import sys
from sortedcontainers import SortedDict

LOG_FILE = ".logs/memoryblock-trace.log"
MAX_VIOLATIONS = 20


ALLOC_TAGS  = {"LEAF_ALLOC", "BRANCH_KEY_ALLOC", "PREFIX_KEY_ALLOC"}
FREE_TAGS   = {"LEAF_FREE",  "BRANCH_KEY_FREE",  "PREFIX_KEY_FREE"}
RESIZE_TAGS = {"LEAF_KEY_RESIZE", "BRANCH_KEY_RESIZE", "PREFIX_KEY_RESIZE"}

MR_ALLOC_TAG        = "MR_ALLOC"
MR_ALLOC_FROM_FREE_TAG = "MR_ALLOC_FROM_FREE"
MR_DEALLOC_TAG = "MR_DEALLOC"
MR_RESIZE_TAG  = "MR_RESIZE"

# Section marker pattern: "• MemoryBTree with node capacity <N>, merge threshold <T>, tail compression <T/F>, prefix compression <T/F>"
SECTION_MARKER_PATTERN = re.compile(
    r'MemoryBTree with node capacity (\d+), merge threshold ([\d.]+), tail compression (\w+), prefix compression (\w+)'
)


def parse_fields(s: str) -> dict:
    return {m.group(1): m.group(2) for m in re.finditer(r'(\w+)=([\d_]+)', s)}


def parse_num(s: str) -> int:
    return int(s.replace("_", ""))


def find_overlap(live: SortedDict, addr: int, end: int):
    """
    Return the first live range that overlaps [addr, end), or None.
    Checks only the predecessor, exact key, and immediate successor — O(log n).
    """
    idx = live.bisect_right(addr)           # index of first key > addr
    # candidates: one before addr, the exact slot, and one after addr
    for i in range(max(0, idx - 1), min(len(live), idx + 2)):
        ex_addr, (ex_end, ex_tag, ex_line) = live.peekitem(i)
        if ex_addr < end and ex_end > addr:  # intervals overlap
            return ex_addr, ex_end, ex_tag, ex_line
    return None


def print_violation(kind: str, vno: int, line_no: int, tag: str,
                    new_addr: int, new_end: int,
                    ex_addr: int, ex_end: int, ex_tag: str, ex_line: int):
    print(f"[VIOLATION #{vno}] {kind}  —  log line {line_no}")
    print(f"  NEW      [{tag:<25s}]  [{new_addr:>8}, {new_end:>8})")
    print(f"  EXISTING [{ex_tag:<25s}]  [{ex_addr:>8}, {ex_end:>8})  first seen at line {ex_line}")
    print()


class SectionAnalyzer:
    """Analyzes a single test section for violations."""
    
    def __init__(self, section_name: str, start_line: int):
        self.section_name = section_name
        self.start_line = start_line
        self.end_line = None
        
        # BTree-level tracking (dict of region_name → SortedDict)
        self.live = {}
        self.violations = []
        self.events_seen = 0
        self.warn_count = 0
        
        # MemoryRegion-level tracking
        self.mr_live = {}
        self.mr_violations = []
        self.mr_events_seen = 0
        self.mr_warn_count = 0
    
    def process_line(self, line_no: int, line: str) -> bool:
        """
        Process a log line within this section.
        Returns True if this line marks the end of the section, False otherwise.
        """
        # Check for section end (✓ or ✖ marker on the same line that started the section)
        if SECTION_MARKER_PATTERN.search(line) and ("✖" in line or "✓" in line):
            self.end_line = line_no
            return True
        
        # ── MemoryRegion-level events ──────────────────────────────────────
        mr_m = re.match(r'\s*stdout (MR_ALLOC_FROM_FREE|MR_ALLOC|MR_DEALLOC|MR_RESIZE) (.+)', line)
        if mr_m:
            mr_tag, mr_rest = mr_m.group(1), mr_m.group(2)
            # Strip fmem= field before numeric parsing
            mr_rest_no_fmem = re.sub(r'\s*fmem=\[.*\]\s*$', '', mr_rest)
            flds = parse_fields(mr_rest_no_fmem)
            rid  = parse_num(flds["rid"])
            if rid not in self.mr_live:
                self.mr_live[rid] = SortedDict()
            ld = self.mr_live[rid]
            self.mr_events_seen += 1

            if mr_tag in (MR_ALLOC_TAG, MR_ALLOC_FROM_FREE_TAG):
                addr  = parse_num(flds["addr"])
                size  = parse_num(flds["bytes"])
                end   = addr + size
                hit = find_overlap(ld, addr, end)
                if hit:
                    ex_addr, ex_end, ex_tag, ex_line = hit
                    self.mr_violations.append((line_no, "MR OVERLAP on ALLOC",
                                              f"{mr_tag}:rid={rid}", addr, end,
                                              ex_addr, ex_end, ex_tag, ex_line))
                    print_violation("MR OVERLAP on ALLOC", len(self.mr_violations), line_no,
                                    f"{mr_tag}:rid={rid}", addr, end,
                                    ex_addr, ex_end, ex_tag, ex_line)
                    if len(self.mr_violations) >= MAX_VIOLATIONS:
                        print(f"Reached MAX_VIOLATIONS={MAX_VIOLATIONS} (MR), stopping early.")
                        return False  # Signal to skip to next section
                ld[addr] = (end, f"{mr_tag}:rid={rid}", line_no)

            elif mr_tag == MR_DEALLOC_TAG:
                addr = parse_num(flds["addr"])
                size = parse_num(flds["size"])
                if addr in ld:
                    del ld[addr]
                else:
                    self.mr_warn_count += 1
                    print(f"  [MR DOUBLE-FREE line {line_no}] DEALLOC of untracked addr={addr} size={size} rid={rid}")

            elif mr_tag == MR_RESIZE_TAG:
                old_addr = parse_num(flds["old_addr"])
                new_addr = parse_num(flds["new_addr"])
                new_size = parse_num(flds["new_size"])
                new_end  = new_addr + new_size

                if old_addr in ld:
                    del ld[old_addr]
                else:
                    self.mr_warn_count += 1
                    print(f"  [MR DOUBLE-FREE line {line_no}] RESIZE of untracked old_addr={old_addr} rid={rid}")

                if new_addr not in ld:
                    hit = find_overlap(ld, new_addr, new_end)
                    if hit:
                        ex_addr, ex_end, ex_tag, ex_line = hit
                        self.mr_violations.append((line_no, "MR OVERLAP on RESIZE",
                                                  f"MR_RESIZE:rid={rid}", new_addr, new_end,
                                                  ex_addr, ex_end, ex_tag, ex_line, []))
                        print_violation("MR OVERLAP on RESIZE", len(self.mr_violations), line_no,
                                        f"MR_RESIZE:rid={rid}", new_addr, new_end,
                                        ex_addr, ex_end, ex_tag, ex_line)
                        if len(self.mr_violations) >= MAX_VIOLATIONS:
                            print(f"Reached MAX_VIOLATIONS={MAX_VIOLATIONS} (MR), stopping early.")
                            return False  # Signal to skip to next section
                    ld[new_addr] = (new_end, f"MR_RESIZE:rid={rid}", line_no)
            return False

        # ── Parse BTree structured log line ────────────────────────────────
        m = re.match(r'\s*stdout \[([A-Z_]+)\] region=(\w+) (.+)', line)
        if not m:
            return False

        tag, region, rest = m.group(1), m.group(2), m.group(3)
        flds = parse_fields(rest)
        self.events_seen += 1

        if region not in self.live:
            self.live[region] = SortedDict()
        ld = self.live[region]

        # ── ALLOC ────────────────────────────────────────────────────────────
        if tag in ALLOC_TAGS:
            addr = parse_num(flds["addr"])
            end  = parse_num(flds["end"])

            hit = find_overlap(ld, addr, end)
            if hit:
                ex_addr, ex_end, ex_tag, ex_line = hit
                self.violations.append((line_no, "OVERLAP on ALLOC", tag, addr, end,
                                       ex_addr, ex_end, ex_tag, ex_line))
                print_violation("OVERLAP on ALLOC", len(self.violations), line_no,
                                tag, addr, end, ex_addr, ex_end, ex_tag, ex_line)
                if len(self.violations) >= MAX_VIOLATIONS:
                    print(f"Reached MAX_VIOLATIONS={MAX_VIOLATIONS}, stopping early.")
                    return False  # Signal to skip to next section

            ld[addr] = (end, tag, line_no)

        # ── FREE ─────────────────────────────────────────────────────────────
        elif tag in FREE_TAGS:
            addr = parse_num(flds["addr"])
            end  = parse_num(flds["end"])

            if addr in ld:
                del ld[addr]
            else:
                self.warn_count += 1
                print(f"  [WARN line {line_no}] FREE of untracked addr={addr}  end={end}  [{tag}]")

        # ── RESIZE ───────────────────────────────────────────────────────────
        elif tag in RESIZE_TAGS:
            old_addr = parse_num(flds["old_addr"])
            new_addr = parse_num(flds["new_addr"])
            new_end  = parse_num(flds["new_end"])

            if old_addr in ld:
                del ld[old_addr]
            else:
                self.warn_count += 1
                print(f"  [WARN line {line_no}] RESIZE of untracked old_addr={old_addr}  [{tag}]")

            hit = find_overlap(ld, new_addr, new_end)
            if hit:
                ex_addr, ex_end, ex_tag, ex_line = hit
                self.violations.append((line_no, "OVERLAP on RESIZE", tag, new_addr, new_end,
                                       ex_addr, ex_end, ex_tag, ex_line))
                print_violation("OVERLAP on RESIZE", len(self.violations), line_no,
                                tag, new_addr, new_end, ex_addr, ex_end, ex_tag, ex_line)
                if len(self.violations) >= MAX_VIOLATIONS:
                    print(f"Reached MAX_VIOLATIONS={MAX_VIOLATIONS}, stopping early.")
                    return False  # Signal to skip to next section

            ld[new_addr] = (new_end, tag, line_no)

        return False
    
    def print_summary(self):
        """Print summary for this section."""
        print("=" * 70)
        print(f"SECTION: {self.section_name}")
        print("=" * 70)
        print(f"  Lines {self.start_line}–{self.end_line or '(EOF)'}")
        print()
        
        # BTree-level
        total_live = sum(len(v) for v in self.live.values())
        print("BTree-level:")
        print(f"  Events parsed    : {self.events_seen}")
        print(f"  Regions seen     : {sorted(self.live.keys())}")
        print(f"  Live ranges left : {total_live}")
        print(f"  Warnings         : {self.warn_count}")
        print(f"  Violations found : {len(self.violations)}")
        if self.violations:
            print(f"\n  {'#':<4} {'log line':>9}  {'kind':<22}  {'new range':<20}  {'ex range':<20}")
            for i, (ln, kind, tag, na, ne, ea, ee, et, el) in enumerate(self.violations, 1):
                new_range = f"[{na},{ne})"
                ex_range  = f"[{ea},{ee})"
                print(f"  {i:<4} {ln:>9}  {kind:<22}  {new_range:<20}  {ex_range:<20}")
        print()
        
        # MemoryRegion-level
        print("MemoryRegion-level:")
        total_mr_live = sum(len(v) for v in self.mr_live.values())
        print(f"  Events parsed    : {self.mr_events_seen}")
        print(f"  Regions seen     : {sorted(self.mr_live.keys())}")
        print(f"  Live blocks left : {total_mr_live}")
        print(f"  Double-free warns: {self.mr_warn_count}")
        print(f"  Violations found : {len(self.mr_violations)}")
        if self.mr_violations:
            print(f"\n  {'#':<4} {'log line':>9}  {'kind':<25}  {'new range':<20}  {'ex range':<20}")
            for i, (ln, kind, tag, na, ne, ea, ee, et, el, *_) in enumerate(self.mr_violations, 1):
                new_range = f"[{na},{ne})"
                ex_range  = f"[{ea},{ee})"
                print(f"  {i:<4} {ln:>9}  {kind:<25}  {new_range:<20}  {ex_range:<20}")
        print()



def main():
    """Scan log file, detect sections, and analyze each one."""
    sections = []
    current_section = None
    
    with open(LOG_FILE, "r") as f:
        for line_no, raw in enumerate(f, 1):
            line = raw.strip()
            
            # Check if this line marks a section start
            m = SECTION_MARKER_PATTERN.search(line)
            if m and "•" in raw:
                # Finalize previous section if any
                if current_section:
                    sections.append(current_section)
                
                # Start new section
                node_cap, merge_thresh, tail_compress, prefix_compress = m.groups()
                section_name = f"node_cap={node_cap}, merge_thresh={merge_thresh}, tail_compress={tail_compress}, prefix_compress={prefix_compress}"
                current_section = SectionAnalyzer(section_name, line_no)
                print(f"\n{'='*70}")
                print(f"Starting section: {section_name}")
                print(f"{'='*70}\n")
                continue
            
            # If we're in a section, process the line
            if current_section:
                should_end = current_section.process_line(line_no, line)
                if should_end:
                    print(f"\n[Section ended at line {line_no}]\n")
                    sections.append(current_section)
                    current_section = None
    
    # Handle final section if file ended without explicit boundary
    if current_section:
        current_section.end_line = "(EOF)"
        sections.append(current_section)
    
    # Print per-section summaries
    for section in sections:
        section.print_summary()
    
    # Print cross-section comparison table
    print("\n" + "=" * 100)
    print("CROSS-SECTION SUMMARY")
    print("=" * 100)
    print(f"{'Configuration':<60}  {'BTree Vio':>10}  {'MR Vio':>10}")
    print(f"{'-'*60}  {'-'*10}  {'-'*10}")
    for section in sections:
        config = section.section_name[:59]  # Truncate to fit
        print(f"{config:<60}  {len(section.violations):>10}  {len(section.mr_violations):>10}")
    
    # Overall stats
    total_violations = sum(len(s.violations) for s in sections)
    total_mr_violations = sum(len(s.mr_violations) for s in sections)
    print(f"{'-'*60}  {'-'*10}  {'-'*10}")
    print(f"{'TOTAL':<60}  {total_violations:>10}  {total_mr_violations:>10}")
    print()


if __name__ == "__main__":
    try:
        from sortedcontainers import SortedDict
    except ImportError:
        print("ERROR: 'sortedcontainers' not installed.  Run: pip install sortedcontainers")
        sys.exit(1)

    path = sys.argv[1] if len(sys.argv) > 1 else LOG_FILE
    LOG_FILE = path
    main()

