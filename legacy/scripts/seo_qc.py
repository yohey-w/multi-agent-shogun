#!/usr/bin/env python3
"""SEO Article Quality Check Script (seo_qc.py)

Usage:
    python3 scripts/seo_qc.py <site> [--base-dir /path/to/seo-affiliate] [--output yaml|json|summary]
    python3 scripts/seo_qc.py all    # Run all 9 sites

Examples:
    python3 scripts/seo_qc.py gaichuu
    python3 scripts/seo_qc.py all --output summary
"""

import argparse
import glob
import os
import re
import sys
import yaml
from collections import defaultdict
from datetime import datetime
from pathlib import Path

DEFAULT_BASE_DIR = "/home/yohei/seo-affiliate"
ALL_SITES = ["yane", "kagi", "kyutoki", "ohaka", "gaichuu", "kekkon", "ihin", "fuyouhin", "zeirishi"]

# Forbidden words (check_009)
FORBIDDEN_WORDS = ["必ず", "絶対", "間違いなく", "最高", "No.1", "ナンバーワン", "一番"]
FORBIDDEN_PATTERN = re.compile("|".join(re.escape(w) for w in FORBIDDEN_WORDS))

# Writing style patterns (check_012) - detect 常体 endings
JOTAI_PATTERN = re.compile(r"である。|であろう。|[^い]だ。")

# Date pattern for publishedAt
DATE_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}$")

# Required frontmatter fields
REQUIRED_FIELDS = ["title", "description", "publishedAt", "category", "area", "keyword", "keywords"]


def parse_frontmatter(content: str) -> tuple[dict, str]:
    """Parse YAML frontmatter from markdown content. Returns (frontmatter_dict, body)."""
    if not content.startswith("---"):
        return {}, content

    end = content.find("---", 3)
    if end == -1:
        return {}, content

    fm_str = content[3:end].strip()
    body = content[end + 3:].strip()

    try:
        fm = yaml.safe_load(fm_str)
        if not isinstance(fm, dict):
            fm = {}
    except yaml.YAMLError:
        fm = {}

    return fm, body


def strip_html_tags(text: str) -> str:
    """Remove HTML tags from text."""
    return re.sub(r"<[^>]+>", "", text)


def count_japanese_chars(text: str) -> int:
    """Count meaningful characters (Japanese + alphanumeric, excluding whitespace and markdown)."""
    # Remove HTML tags
    text = strip_html_tags(text)
    # Remove markdown link syntax
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)
    # Remove markdown formatting
    text = re.sub(r"[#*_`|>-]", "", text)
    # Remove whitespace and newlines
    text = re.sub(r"\s+", "", text)
    return len(text)


def find_h2_sections(body: str) -> list[tuple[str, str]]:
    """Find H2 sections and their content. Returns list of (heading, section_content)."""
    lines = body.split("\n")
    sections = []
    current_heading = None
    current_lines = []

    for line in lines:
        if line.startswith("## "):
            if current_heading is not None:
                sections.append((current_heading, "\n".join(current_lines)))
            current_heading = line
            current_lines = []
        elif current_heading is not None:
            current_lines.append(line)

    if current_heading is not None:
        sections.append((current_heading, "\n".join(current_lines)))

    return sections


def check_001_frontmatter_fields(fm: dict) -> tuple[bool, str]:
    """Check that all 7 required frontmatter fields exist."""
    missing = [f for f in REQUIRED_FIELDS if f not in fm]
    if missing:
        return False, f"missing: {', '.join(missing)}"
    return True, ""


def check_002_frontmatter_types(fm: dict) -> tuple[bool, str]:
    """Check frontmatter field types and values."""
    issues = []

    if "title" in fm and (not isinstance(fm["title"], str) or not fm["title"].strip()):
        issues.append("title empty or not string")

    if "description" in fm and (not isinstance(fm["description"], str) or not fm["description"].strip()):
        issues.append("description empty or not string")

    if "publishedAt" in fm:
        val = str(fm["publishedAt"])
        if not DATE_PATTERN.match(val):
            issues.append(f"publishedAt format: {val}")

    if "category" in fm and fm["category"] != "area":
        # Allow other categories like "ranking" etc.
        pass

    if "area" in fm and (not isinstance(fm["area"], str) or not fm["area"].strip()):
        issues.append("area empty or not string")

    if "keyword" in fm:
        if not isinstance(fm["keyword"], str) or not fm["keyword"].strip():
            issues.append("keyword empty or not string")
    # keyword might not exist (checked in 001)

    if "keywords" in fm:
        kw = fm["keywords"]
        if not isinstance(kw, list) or len(kw) < 1:
            issues.append("keywords not array or empty")

    if issues:
        return False, "; ".join(issues)
    return True, ""


def check_003_pr_notation(body: str) -> tuple[bool, str]:
    """Check for PR/affiliate disclosure within first 50 lines."""
    lines = body.split("\n")[:50]
    text = "\n".join(lines)
    if "アフィリエイト広告" in text or "PR" in text:
        return True, ""
    return False, "PR notation not found in first 50 lines"


def check_004_cta_count(body: str) -> tuple[bool, str]:
    """Check that exactly 3 CTA boxes exist."""
    count = body.count('<div class="cta-box">')
    # Also check for <!-- CTA: --> comments (rehype-affiliate-cta pattern)
    cta_comments = len(re.findall(r"<!--\s*CTA:", body))
    total = count + cta_comments
    if total == 3:
        return True, ""
    return False, f"CTA count: {total} (div: {count}, comment: {cta_comments})"


def check_005_cta_structure(body: str) -> tuple[bool, str]:
    """Check CTA box HTML structure."""
    # Find all cta-box divs
    cta_blocks = re.findall(
        r'<div class="cta-box">.*?</div>\s*</div>',
        body,
        re.DOTALL
    )

    # Also count CTA comments (these are valid - replaced at build time)
    cta_comments = len(re.findall(r"<!--\s*CTA:", body))

    if not cta_blocks and cta_comments == 0:
        return False, "no CTA found"

    issues = []
    for i, block in enumerate(cta_blocks):
        if 'cta-badge' not in block and 'cta-button' not in block:
            issues.append(f"CTA#{i+1}: missing badge or button")
        if 'nofollow' not in block or 'sponsored' not in block:
            issues.append(f"CTA#{i+1}: missing nofollow/sponsored")

    if issues:
        return False, "; ".join(issues)
    return True, ""


def check_006_h2_count(body: str) -> tuple[bool, str]:
    """Check that there are exactly 5 H2 headings."""
    h2s = re.findall(r"^## .+", body, re.MULTILINE)
    count = len(h2s)
    if count == 5:
        return True, ""
    return False, f"H2 count: {count}"


def check_007_faq_questions(body: str) -> tuple[bool, str]:
    """Check that FAQ section has 5 Q&A items."""
    sections = find_h2_sections(body)
    # FAQ is typically the 4th H2 section
    faq_content = ""
    for heading, content in sections:
        if "FAQ" in heading or "よくある質問" in heading:
            faq_content = content
            break

    # If no explicit FAQ heading, use 4th section
    if not faq_content and len(sections) >= 4:
        faq_content = sections[3][1]

    if not faq_content:
        return False, "FAQ section not found"

    # Count ### or #### headings in FAQ section
    questions = re.findall(r"^#{3,4} .+", faq_content, re.MULTILINE)
    count = len(questions)
    if count >= 5:
        return True, ""
    return False, f"FAQ questions: {count}"


def check_008_char_count(body: str) -> tuple[bool, str]:
    """Check that body has >= 2500 Japanese characters."""
    char_count = count_japanese_chars(body)
    if char_count >= 2500:
        return True, ""
    return False, f"chars: {char_count}"


def check_009_forbidden_words(body: str) -> tuple[bool, list]:
    """Check for forbidden words."""
    matches = FORBIDDEN_PATTERN.findall(body)
    if not matches:
        return True, []
    # Count occurrences
    word_counts = defaultdict(int)
    for m in matches:
        word_counts[m] += 1
    details = [f"{w}({c})" for w, c in word_counts.items()]
    return False, details


def check_010_cost_table(body: str) -> tuple[bool, str]:
    """Check that first H2 section contains a markdown table (>= 4 lines)."""
    sections = find_h2_sections(body)
    if not sections:
        return False, "no H2 sections"

    first_section = sections[0][1]
    table_lines = [l for l in first_section.split("\n") if l.strip().startswith("|")]
    if len(table_lines) >= 4:
        return True, ""
    return False, f"table lines in H2-1: {len(table_lines)}"


def check_011_markdown_table_syntax(body: str) -> tuple[bool, str]:
    """Check markdown table syntax: header -> separator -> data rows."""
    lines = body.split("\n")
    issues = []
    i = 0
    in_table = False
    has_separator = False

    while i < len(lines):
        line = lines[i].strip()
        if line.startswith("|"):
            if not in_table:
                # Start of a new table - this should be the header row
                in_table = True
                has_separator = False
                # Next line must be separator (|---|---|)
                if i + 1 < len(lines):
                    next_line = lines[i + 1].strip()
                    if next_line.startswith("|") and re.search(r"-{2,}", next_line):
                        has_separator = True
                    else:
                        issues.append(f"line {i+1}: table header not followed by separator")
            # else: continuation of table (data rows) - OK
        else:
            if in_table:
                in_table = False
                if not has_separator:
                    issues.append(f"table ending at line {i}: no separator row found")
        i += 1

    if issues:
        return False, "; ".join(issues[:3])
    return True, ""


def check_012_writing_style(body: str) -> tuple[bool, str]:
    """Check for consistent です・ます style (no 常体 endings)."""
    # Exclude HTML tags and frontmatter
    clean = strip_html_tags(body)
    matches = JOTAI_PATTERN.findall(clean)
    if not matches:
        return True, ""
    return False, f"常体 found: {matches[:5]}"


def check_013_area_frequency(fm: dict, body: str) -> tuple[bool, str]:
    """Check that area name appears >= 3 times in body."""
    area = fm.get("area", "")
    if not area:
        return False, "no area in frontmatter"

    count = body.count(area)
    if count >= 3:
        return True, ""
    return False, f"area '{area}' count: {count}"


def check_014_image_exists(slug: str, site_dir: str) -> tuple[bool, str]:
    """Check that OGP and thumbnail images exist for the article."""
    images_dir = os.path.join(site_dir, "public", "images", "articles")
    ogp_path = os.path.join(images_dir, f"{slug}-ogp.png")
    thumb_path = os.path.join(images_dir, f"{slug}-thumb.png")

    missing = []
    if not os.path.exists(ogp_path):
        missing.append("ogp")
    if not os.path.exists(thumb_path):
        missing.append("thumb")

    if not missing:
        return True, ""
    return False, f"missing: {', '.join(missing)}"


def run_checks(filepath: str, site_dir: str) -> dict:
    """Run all 14 checks on a single article file."""
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    fm, body = parse_frontmatter(content)
    slug = Path(filepath).stem  # filename without extension
    filename = Path(filepath).name

    results = {}

    # Check 001: Frontmatter fields
    passed, detail = check_001_frontmatter_fields(fm)
    results["check_001"] = {"pass": passed, "detail": detail}

    # Check 002: Frontmatter types
    passed, detail = check_002_frontmatter_types(fm)
    results["check_002"] = {"pass": passed, "detail": detail}

    # Check 003: PR notation
    passed, detail = check_003_pr_notation(body)
    results["check_003"] = {"pass": passed, "detail": detail}

    # Check 004: CTA count
    passed, detail = check_004_cta_count(body)
    results["check_004"] = {"pass": passed, "detail": detail}

    # Check 005: CTA structure
    passed, detail = check_005_cta_structure(body)
    results["check_005"] = {"pass": passed, "detail": detail}

    # Check 006: H2 count
    passed, detail = check_006_h2_count(body)
    results["check_006"] = {"pass": passed, "detail": detail}

    # Check 007: FAQ questions
    passed, detail = check_007_faq_questions(body)
    results["check_007"] = {"pass": passed, "detail": detail}

    # Check 008: Character count
    passed, detail = check_008_char_count(body)
    results["check_008"] = {"pass": passed, "detail": detail}

    # Check 009: Forbidden words
    passed, detail = check_009_forbidden_words(body)
    results["check_009"] = {"pass": passed, "detail": detail if not passed else ""}

    # Check 010: Cost table
    passed, detail = check_010_cost_table(body)
    results["check_010"] = {"pass": passed, "detail": detail}

    # Check 011: Markdown table syntax
    passed, detail = check_011_markdown_table_syntax(body)
    results["check_011"] = {"pass": passed, "detail": detail}

    # Check 012: Writing style
    passed, detail = check_012_writing_style(body)
    results["check_012"] = {"pass": passed, "detail": detail}

    # Check 013: Area frequency
    passed, detail = check_013_area_frequency(fm, body)
    results["check_013"] = {"pass": passed, "detail": detail}

    # Check 014: Image exists
    passed, detail = check_014_image_exists(slug, site_dir)
    results["check_014"] = {"pass": passed, "detail": detail}

    return results


def aggregate_results(all_results: dict[str, dict]) -> dict:
    """Aggregate per-file results into site-level summary."""
    check_ids = [f"check_{i:03d}" for i in range(1, 15)]
    summary = {}

    for cid in check_ids:
        pass_count = 0
        fail_count = 0
        fail_files = []

        for filename, checks in all_results.items():
            if cid in checks:
                if checks[cid]["pass"]:
                    pass_count += 1
                else:
                    fail_count += 1
                    fail_files.append(filename)

        total = pass_count + fail_count
        rate = f"{pass_count / total * 100:.0f}%" if total > 0 else "N/A"

        summary[cid] = {
            "pass": pass_count,
            "fail": fail_count,
            "pass_rate": rate,
            "fail_files": fail_files[:20],  # Limit to 20 samples
            "fail_files_total": len(fail_files),
        }

    return summary


def run_site(site: str, base_dir: str, output_format: str = "yaml") -> dict:
    """Run QC checks on all articles for a site."""
    site_dir = os.path.join(base_dir, site)
    area_dir = os.path.join(site_dir, "src", "content", "area")

    if not os.path.isdir(area_dir):
        print(f"ERROR: {area_dir} not found", file=sys.stderr)
        return {}

    # Find all .md and .mdx files
    md_files = sorted(glob.glob(os.path.join(area_dir, "*.md")))
    mdx_files = sorted(glob.glob(os.path.join(area_dir, "*.mdx")))
    all_files = md_files + mdx_files

    if not all_files:
        print(f"WARNING: No articles found in {area_dir}", file=sys.stderr)
        return {}

    print(f"Checking {site}: {len(all_files)} articles...", file=sys.stderr)

    all_results = {}
    for filepath in all_files:
        filename = Path(filepath).name
        try:
            results = run_checks(filepath, site_dir)
            all_results[filename] = results
        except Exception as e:
            print(f"  ERROR: {filename}: {e}", file=sys.stderr)
            all_results[filename] = {"error": str(e)}

    summary = aggregate_results(all_results)

    report = {
        "site": site,
        "total_articles": len(all_files),
        "timestamp": datetime.now().isoformat(),
        "results": summary,
    }

    # Calculate overall stats
    total_pass = sum(v["pass"] for v in summary.values())
    total_fail = sum(v["fail"] for v in summary.values())
    total_checks = total_pass + total_fail
    report["overall"] = {
        "total_pass": total_pass,
        "total_fail": total_fail,
        "pass_rate": f"{total_pass / total_checks * 100:.1f}%" if total_checks > 0 else "N/A",
    }

    return report


def print_summary(report: dict):
    """Print a concise summary table."""
    site = report["site"]
    total = report["total_articles"]
    results = report["results"]

    check_names = {
        "check_001": "frontmatter存在",
        "check_002": "frontmatter型",
        "check_003": "PR表記",
        "check_004": "CTA×3",
        "check_005": "CTA構造",
        "check_006": "H2×5",
        "check_007": "FAQ 5問",
        "check_008": "2500文字↑",
        "check_009": "禁止語なし",
        "check_010": "費用テーブル",
        "check_011": "md構文",
        "check_012": "です・ます",
        "check_013": "地域名出現",
        "check_014": "画像存在",
    }

    print(f"\n{'='*60}")
    print(f"  {site} ({total} articles)  —  Overall: {report['overall']['pass_rate']}")
    print(f"{'='*60}")
    print(f"  {'Check':<20} {'Pass':>6} {'Fail':>6} {'Rate':>6}")
    print(f"  {'-'*40}")

    for cid in sorted(results.keys()):
        r = results[cid]
        name = check_names.get(cid, cid)
        marker = " !!" if r["fail"] > 0 and r["pass"] / max(r["pass"] + r["fail"], 1) < 0.5 else ""
        print(f"  {name:<20} {r['pass']:>6} {r['fail']:>6} {r['pass_rate']:>6}{marker}")

    print()


def main():
    parser = argparse.ArgumentParser(description="SEO Article Quality Check")
    parser.add_argument("site", help="Site name (e.g., gaichuu) or 'all' for all sites")
    parser.add_argument("--base-dir", default=DEFAULT_BASE_DIR, help="Base directory for sites")
    parser.add_argument("--output", choices=["yaml", "summary", "both"], default="both",
                        help="Output format")
    parser.add_argument("--report-dir", default=None,
                        help="Directory to write YAML reports (default: queue/reports/)")
    args = parser.parse_args()

    sites = ALL_SITES if args.site == "all" else [args.site]

    report_dir = args.report_dir
    if report_dir is None:
        # Default to queue/reports/ relative to this script
        script_dir = Path(__file__).resolve().parent.parent
        report_dir = str(script_dir / "queue" / "reports")

    all_reports = []

    for site in sites:
        report = run_site(site, args.base_dir, args.output)
        if not report:
            continue
        all_reports.append(report)

        if args.output in ("summary", "both"):
            print_summary(report)

        if args.output in ("yaml", "both"):
            outpath = os.path.join(report_dir, f"qc_result_{site}.yaml")
            os.makedirs(report_dir, exist_ok=True)
            with open(outpath, "w", encoding="utf-8") as f:
                yaml.dump(report, f, allow_unicode=True, default_flow_style=False, sort_keys=False)
            print(f"  -> {outpath}", file=sys.stderr)

    # Print grand total if multiple sites
    if len(all_reports) > 1 and args.output in ("summary", "both"):
        print(f"\n{'='*60}")
        print(f"  GRAND TOTAL ({sum(r['total_articles'] for r in all_reports)} articles)")
        print(f"{'='*60}")
        total_pass = sum(r["overall"]["total_pass"] for r in all_reports)
        total_fail = sum(r["overall"]["total_fail"] for r in all_reports)
        total = total_pass + total_fail
        print(f"  Overall pass rate: {total_pass / total * 100:.1f}%" if total > 0 else "  No data")
        print()


if __name__ == "__main__":
    main()
