#!/usr/bin/env python3
"""Checks the swiftui-architect skill against the authoring rules in CLAUDE.md.

Run from anywhere after every change to the skill, and fix until it passes:

    python3 .github/scripts/check_skill.py

It checks what a script can: the frontmatter, SKILL.md's size and sections, the references
and their Contents lists, the scripts and where they're listed, the related skills in
references/related-skills.md, Prerequisites and README.md, links, pointers and anchors, pinned
package-runner commands, the plugin manifests, and the code style of every Swift example. It
exits non-zero when any check fails. The review that needs judgment is the checklist in CLAUDE.md.
"""

import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SKILL = ROOT / "skills" / "swiftui-architect"
REFERENCES = SKILL / "references"
SCRIPTS = SKILL / "scripts"

# Limits from the Agent Skills specification and Claude Code's skill loading.
MAX_NAME = 64
MAX_DESCRIPTION = 200  # SkillEvaluator's limit, far below the specification's 1,024: the listing is paid on every turn
MAX_SKILL_LINES = 500
MAX_SKILL_TOKENS = 5000  # recommended for the SKILL.md body; also what compaction keeps
CHARS_PER_TOKEN = 2.9  # Claude's tokenizer measures this skill's SKILL.md at about 2.95
CONTENTS_AFTER_LINES = 100
TRIGGER_WITHIN = 60  # some harnesses list only a description's first 60 characters
MAX_TAGS = 5
# The headings SkillEvaluator's quality check looks for that SKILL.md's sections fit.
SKILL_SECTIONS = [
    "## Purpose",
    "## Examples",
    "## Troubleshooting",
    "## Prerequisites",
    "## Available Scripts",
    "## Limitations",
    "## References",
    "## Instructions",
]

failures: list[str] = []


def fail(message: str) -> None:
    failures.append(message)


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def relative(path: Path) -> str:
    return str(path.relative_to(ROOT))


def outside_code(text: str):
    """Yields (line number, line) for lines outside fenced code blocks."""
    in_code = False
    for number, line in enumerate(text.splitlines(), 1):
        if line.startswith("```"):
            in_code = not in_code
            continue
        if not in_code:
            yield number, line


def swift_lines(text: str):
    """Yields (line number, line) for lines inside ```swift blocks, outside multi-line strings."""
    in_swift = in_string = False
    for number, line in enumerate(text.splitlines(), 1):
        if line.startswith("```"):
            in_swift = line.strip() == "```swift" if not in_swift else False
            continue
        if not in_swift:
            continue
        if line.count('"""') % 2 == 1:
            in_string = not in_string
            continue
        if not in_string:
            yield number, line


def slug(heading: str) -> str:
    text = re.sub(r"[`*_]", "", heading.strip().lower())
    text = re.sub(r"[^\w\- ]", "", text)
    return text.replace(" ", "-")


def headings(text: str, level: str = "#") -> list[str]:
    return [line.lstrip("#").strip() for _, line in outside_code(text) if re.match(rf"{level}{{1,6}} ", line)]


# MARK: - Frontmatter


def check_frontmatter(skill_text: str) -> str:
    match = re.match(r"---\n(.*?)\n---\n", skill_text, re.S)
    if not match:
        fail("SKILL.md: the frontmatter must open the file between --- lines")
        return ""

    fields: dict[str, str] = {}
    metadata: dict[str, str] = {}
    for line in match.group(1).splitlines():
        nested = line.startswith("  ") and "metadata" in fields
        key, separator, value = line.strip().partition(":") if nested else line.partition(":")
        if not separator or not re.fullmatch(r"[a-z][a-z0-9_-]*", key):
            fail(f"frontmatter: keep each field on one line: {line[:60]}")
        elif nested:
            metadata[key] = value.strip()
        else:
            fields[key] = value.strip()

    if set(fields) != {"name", "description", "license", "metadata"}:
        fail(f"frontmatter: holds only name, description, license and metadata, found {sorted(fields)}")
    if fields.get("metadata") or set(metadata) != {"author", "tags"}:
        fail(f"frontmatter: metadata holds only author and tags, found {sorted(metadata)}")

    name = fields.get("name", "")
    if len(name) > MAX_NAME or not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", name):
        fail(f"frontmatter: name {name!r} must be at most {MAX_NAME} lowercase letters, digits and single hyphens")
    if name != SKILL.name:
        fail(f"frontmatter: name {name!r} must match the folder {SKILL.name!r}")
    if "anthropic" in name or "claude" in name:
        fail("frontmatter: name may not contain anthropic or claude")

    description = fields.get("description", "")
    if not 0 < len(description) <= MAX_DESCRIPTION:
        fail(f"frontmatter: description is {len(description)} characters, at most {MAX_DESCRIPTION}")
    if re.search(r"[<>]", description):
        fail("frontmatter: description may not contain angle brackets or XML tags")
    if re.match(r"(I|You|We|This skill)\b", description):
        fail("frontmatter: description is written in the third person, starting with what the skill does")
    if "Use when" not in description[:TRIGGER_WITHIN]:
        fail(f"frontmatter: description says when to use the skill (Use when …) in its first {TRIGGER_WITHIN} characters")

    if shutil.which("ruby"):
        script = 'require "yaml"; YAML.safe_load(File.read(ARGV[0], encoding: "UTF-8")[/\\A---\\n(.*?)\\n---\\n/m, 1])'
        result = subprocess.run(["ruby", "-e", script, str(SKILL / "SKILL.md")], capture_output=True, text=True)
        if result.returncode != 0:
            fail(f"frontmatter: not valid YAML: {result.stderr.strip()[:200]}")

    plugin = json.loads(read(ROOT / ".claude-plugin" / "plugin.json"))
    if fields.get("license") != plugin.get("license"):
        fail(f"frontmatter: license {fields.get('license')!r} must match plugin.json's {plugin.get('license')!r}")
    author = plugin.get("author", {}).get("name")
    if metadata.get("author") != author:
        fail(f"frontmatter: metadata.author {metadata.get('author')!r} must match plugin.json's {author!r}")
    tags = [tag.strip() for tag in metadata.get("tags", "").split(",")]
    if not 0 < len(tags) <= MAX_TAGS or not all(re.fullmatch(r"[a-z0-9-]+", tag) for tag in tags):
        fail(f"frontmatter: metadata.tags is one string of 1 to {MAX_TAGS} comma-separated lowercase tags")

    return description


# MARK: - SKILL.md size


def check_skill_size(skill_text: str) -> None:
    lines = skill_text.count("\n")
    tokens = len(skill_text) / CHARS_PER_TOKEN
    if lines > MAX_SKILL_LINES:
        fail(f"SKILL.md: {lines} lines, under {MAX_SKILL_LINES}")
    if tokens > MAX_SKILL_TOKENS:
        fail(f"SKILL.md: about {tokens:.0f} tokens, under {MAX_SKILL_TOKENS}")

    sections = [line for _, line in outside_code(skill_text) if line.startswith("## ")]
    if [section for section in sections if section in SKILL_SECTIONS] != SKILL_SECTIONS:
        fail(f"SKILL.md: keeps these sections, in order: {', '.join(SKILL_SECTIONS)}")

    start = skill_text.find("\n## References")
    end = skill_text.find("\n## ", start + 1)
    if start < 0:
        fail("SKILL.md: no References section")
    elif (end if end > 0 else len(skill_text)) / CHARS_PER_TOKEN > MAX_SKILL_TOKENS:
        fail("SKILL.md: the References table ends past the first 5,000 tokens, which compaction keeps")
    print(f"SKILL.md: {lines} lines, about {tokens:.0f} tokens")


# MARK: - References


def check_references(skill_text: str, readme_text: str) -> None:
    references_section = skill_text[skill_text.find("\n## References") :]
    for path in sorted(REFERENCES.glob("*.md")):
        link = f"references/{path.name}"
        if f"]({link})" not in references_section:
            fail(f"{link}: not listed in SKILL.md's References table")
        if path.name not in readme_text:
            fail(f"{link}: not named in README.md's layout")

        text = read(path)
        if text.count("\n") <= CONTENTS_AFTER_LINES:
            continue
        listed = re.search(r"## Contents\n((?:- .*\n)+)", text)
        sections = [line[3:].strip() for _, line in outside_code(text) if line.startswith("## ") and line != "## Contents"]
        items = [line[2:].strip() for line in listed.group(1).splitlines()] if listed else []
        if items != sections:
            fail(f"{link}: its Contents list must match its ## headings, in order")


# MARK: - Scripts


def check_scripts(skill_text: str, readme_text: str) -> None:
    """Checks that SKILL.md's Available Scripts table and README.md's layout list every script, and
    that every script the skill names exists."""
    table = section(skill_text, "Available Scripts")
    for path in sorted(SCRIPTS.glob("[!.]*")):
        name = f"scripts/{path.name}"
        if f"| `{name}` |" not in table:
            fail(f"{name}: not listed in SKILL.md's Available Scripts table")
        if path.name not in readme_text:
            fail(f"{name}: not named in README.md's layout")

    for path in sorted(SKILL.rglob("*.md")):
        for number, line in enumerate(read(path).splitlines(), 1):
            for name in re.findall(r"\bscripts/[\w.-]*\w", line):
                if not (SKILL / name).is_file():
                    fail(f"{relative(path)}:{number}: no script at {name}")


# MARK: - Related skills


def section(text: str, heading: str) -> str:
    start = text.find(f"\n## {heading}\n")
    if start == -1:
        return ""
    end = text.find("\n## ", start + 1)
    return text[start:end] if end != -1 else text[start:]


def check_related_skills(skill_text: str, readme_text: str) -> None:
    """Checks that Prerequisites and README.md name exactly the skills related-skills.md lists, and that
    SKILL.md's Related skills links it."""
    related_skills = REFERENCES / "related-skills.md"
    listing = read(related_skills) if related_skills.exists() else ""
    related = re.findall(r"^- .*: `([\w-]+)` \(\[source\]\((https://github\.com/[^)]+)\)\)$", listing, re.M)
    if not related:
        fail("references/related-skills.md: lists no skill as `- <what it covers>: `<name>` ([source](<url>))`")
    if "](references/related-skills.md)" not in section(skill_text, "Related skills"):
        fail("SKILL.md: Related skills must link references/related-skills.md")
    lines = section(skill_text, "Prerequisites").splitlines()
    line = next((line for line in lines if "(#related-skills)" in line), "")
    named = set(re.findall(r"`([\w-]+)`", line))
    names = {name for name, _ in related}
    if named != names:
        fail(f"SKILL.md: Prerequisites must name the related skills {sorted(names)}, not {sorted(named)}")
    works_well_with = section(readme_text.replace("\n### ", "\n## "), "Works well with")
    readme_sources = set(re.findall(r"\]\((https://github\.com/[^)]+)\)", works_well_with))
    sources = {source for _, source in related}
    if readme_sources != sources:
        fail(f"README.md: Works well with must link the related skills' sources {sorted(sources)}, not {sorted(readme_sources)}")


def check_pinned_commands() -> None:
    """Checks that every package-runner command pins a released version, so it can't run a newer, compromised one."""
    command = re.compile(r"\b(npx|bunx|uvx)\s+(?:-\S+\s+)*([^\s`]+)")
    for path in [ROOT / "README.md", ROOT / "CLAUDE.md", *sorted(SKILL.rglob("*.md"))]:
        for number, line in enumerate(read(path).splitlines(), 1):
            for runner, package in command.findall(line):
                if "@" not in package[1:] and "==" not in package:
                    fail(f"{relative(path)}:{number}: {runner} {package} pins no version; name a released one ({package}@<version>)")


# MARK: - Links and anchors


def check_links() -> None:
    files = [ROOT / "README.md", ROOT / "CLAUDE.md", *sorted(SKILL.rglob("*.md"))]
    link = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
    for path in files:
        for number, line in outside_code(read(path)):
            for target in link.findall(line):
                if target.startswith(("http://", "https://", "mailto:")):
                    continue
                file_part, _, anchor = target.partition("#")
                destination = (path.parent / file_part).resolve() if file_part else path
                if not destination.exists():
                    fail(f"{relative(path)}:{number}: no file for {target}")
                elif anchor and destination.suffix == ".md":
                    anchors = {slug(heading) for heading in headings(read(destination))}
                    if anchor not in anchors:
                        fail(f"{relative(path)}:{number}: no heading for #{anchor}")


def check_pointers() -> None:
    """A reference points to another in plain text, `view-models.md#keyed-resources`, never by a link."""
    link = re.compile(r"\[[^\]]*\]\(([a-z-]+\.md)(?:#[^)]*)?\)")
    pointer = re.compile(r"`((?:references/)?[a-z-]+\.md)(?:#([\w-]+))?`")
    checklist_pointer = re.compile(r"\b(references/[a-z-]+\.md)(?:#([\w-]+))?")
    sources = [(path, pointer, outside_code(read(path))) for path in sorted(REFERENCES.glob("*.md"))]
    # SKILL.md's checklists, in code blocks, point to references; its prose links to them.
    skill_text = read(SKILL / "SKILL.md")
    prose = {number for number, _ in outside_code(skill_text)}
    checklists = [(number, line) for number, line in enumerate(skill_text.splitlines(), 1) if number not in prose]
    sources.append((SKILL / "SKILL.md", checklist_pointer, checklists))
    for path, pattern, lines in sources:
        for number, line in lines:
            where = f"{relative(path)}:{number}"
            if path.parent == REFERENCES:
                for target in link.findall(line):
                    fail(f"{where}: links to {target}; point to it in plain text, `{target}#anchor`")
            for target, anchor in pattern.findall(line):
                destination = (path.parent / target) if path.parent == REFERENCES else (SKILL / target)
                if path.parent == REFERENCES and target.startswith("references/"):
                    fail(f"{where}: a reference points to {target} without the references/ folder")
                elif not destination.exists():
                    fail(f"{where}: no file for {target}")
                elif anchor and anchor not in {slug(heading) for heading in headings(read(destination))}:
                    fail(f"{where}: no heading for {target}#{anchor}")


# MARK: - Manifests


def check_manifests(description: str) -> None:
    plugin = json.loads(read(ROOT / ".claude-plugin" / "plugin.json"))
    marketplace = json.loads(read(ROOT / ".claude-plugin" / "marketplace.json"))
    entry = next((item for item in marketplace.get("plugins", []) if item.get("name") == SKILL.name), None)
    if entry is None:
        fail(f"marketplace.json: no plugin entry named {SKILL.name}")
        return

    if plugin.get("description") != description:
        fail("plugin.json: its description must match SKILL.md's")
    if entry.get("description") != description:
        fail("marketplace.json: the plugin entry's description must match SKILL.md's")

    codex_plugin = json.loads(read(ROOT / ".codex-plugin" / "plugin.json"))
    codex_marketplace = json.loads(read(ROOT / ".agents" / "plugins" / "marketplace.json"))
    codex_entry = next((item for item in codex_marketplace.get("plugins", []) if item.get("name") == SKILL.name), None)
    if codex_plugin.get("name") != SKILL.name:
        fail(f".codex-plugin/plugin.json: its name must be {SKILL.name!r}")
    if codex_plugin.get("description") != description:
        fail(".codex-plugin/plugin.json: its description must match SKILL.md's")
    if codex_plugin.get("license") != plugin.get("license"):
        fail(".codex-plugin/plugin.json: its license must match .claude-plugin/plugin.json's")
    if codex_entry is None:
        fail(f".agents/plugins/marketplace.json: no plugin entry named {SKILL.name}")
    elif codex_entry.get("source") != {"source": "local", "path": "./"}:
        fail(".agents/plugins/marketplace.json: the plugin entry's source must be the repository root")

    versions = {plugin.get("version"), marketplace.get("version"), entry.get("version"), codex_plugin.get("version")}
    if len(versions) != 1:
        fail(f"manifests: the four versions must agree, found {sorted(map(str, versions))}")


# MARK: - Swift examples


MAX_SWIFT_COLUMNS = 100

# APIs an example never uses, each with the SDK's own API or the structured concurrency that replaces it.
REPLACED_APIS = {
    "ObservableObject": "@Observable",
    "@Published": "@Observable",
    "@StateObject": "@State",
    "@ObservedObject": "a plain property, or @Bindable for bindings",
    "@EnvironmentObject": "@Environment",
    "EnvironmentKey": "@Entry",
    "PreviewProvider": "#Preview",
    "NavigationView": "NavigationStack",
    ".onAppear": ".task",
    "DispatchQueue": "async and await",
    "Task.detached": "a @concurrent method",
}


def logical_lines(lines: list[tuple[int, str]]) -> list[tuple[int, str]]:
    """Joins a call's wrapped arguments, so each argument is checked where it sits."""
    joined: list[tuple[int, str]] = []
    last_number = 0
    for number, line in lines:
        code = re.sub(r"//.*", "", re.sub(r'"(?:[^"\\]|\\.)*"', '""', line)).strip()
        previous = joined[-1][1] if joined else ""
        wrapped = previous.endswith(("(", ",")) or code.startswith(")")
        if number == last_number + 1 and joined and wrapped:
            separator = "" if previous.endswith("(") or code.startswith(")") else " "
            joined[-1] = (joined[-1][0], previous + separator + code)
        else:
            joined.append((number, code))
        last_number = number
    return joined


def check_swift_examples() -> None:
    effect = re.compile(r"(\(|\w: |, )(try|await) ")
    declaration = re.compile(r"^\s*(var \w+\b.*|let \w+: [^=]+)$")
    # A modifier matches after any receiver; a type or attribute matches with or without its module.
    replaced = {
        api: re.compile(("" if api.startswith(".") else r"(?<![\w@])") + re.escape(api) + r"\b")
        for api in REPLACED_APIS
    }

    for path in sorted(SKILL.rglob("*.md")):
        lines = list(swift_lines(read(path)))
        for position, (number, line) in enumerate(lines):
            where = f"{relative(path)}:{number}"
            if len(line) > MAX_SWIFT_COLUMNS:
                fail(f"{where}: {len(line)} columns, at most {MAX_SWIFT_COLUMNS}; take one argument per line")
            code = re.sub(r"//.*", "", re.sub(r'"(?:[^"\\]|\\.)*"', '""', line))
            for api, pattern in replaced.items():
                if pattern.search(code):
                    fail(f"{where}: {api} in an example; use {REPLACED_APIS[api]}")
            if line.lstrip().startswith("///"):
                following_number, following = lines[position + 1] if position + 1 < len(lines) else (0, "")
                following = following.strip() if following_number == number + 1 else ""
                if not following or following.startswith("}") or re.match(r"//(?!/)", following):
                    fail(f"{where}: a /// comment documents the declaration below it; label a group with //")
            if declaration.match(line):
                following = [text.strip() for _, text in lines[position + 1 : position + 4]]
                if any(text.startswith("do {") for text in following):
                    fail(f"{where}: declared before a do for its catches to fill; end each path in its own catch")
        for number, code in logical_lines(lines):
            if effect.search(code):
                fail(f"{relative(path)}:{number}: a try or await inside an argument; build the value in a let first")


# MARK: - Plugin


def check_plugin() -> None:
    if not shutil.which("claude"):
        print("plugin: skipped, no claude command; run claude plugin validate . yourself")
        return

    result = subprocess.run(["claude", "plugin", "validate", str(ROOT)], capture_output=True, text=True)
    output = result.stdout + result.stderr
    if result.returncode != 0 or "Validation passed" not in output:
        fail(f"claude plugin validate failed:\n{output.strip()[-800:]}")


def main() -> int:
    skill_text = read(SKILL / "SKILL.md")
    readme_text = read(ROOT / "README.md")

    description = check_frontmatter(skill_text)
    check_skill_size(skill_text)
    check_references(skill_text, readme_text)
    check_scripts(skill_text, readme_text)
    check_related_skills(skill_text, readme_text)
    check_pinned_commands()
    check_links()
    check_pointers()
    check_manifests(description)
    check_swift_examples()
    check_plugin()

    for message in failures:
        print(f"FAIL {message}")
    print("All checks passed." if not failures else f"{len(failures)} checks failed.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
