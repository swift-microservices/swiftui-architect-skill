# swiftui-architect

This repository is the `swiftui-architect` agent skill. Agents read `skills/swiftui-architect/SKILL.md` and its `references/`; people read `README.md`. It ships as a Claude Code plugin (`.claude-plugin/`), a Codex plugin (`.codex-plugin/` and `.agents/plugins/`) and through the skills CLI, and it is public.

Every change reaches `main` through a pull request and ends with [the checks](#after-every-change), repeated until they pass.

## What the skill is for

- It decides where code lives, who owns it, and the shape of the pieces that hold a modular SwiftUI app together: modules and their dependency direction, domain models and errors, services and the networking client, view models, the views a screen is made of, app composition, navigation and naming.
- It states shapes, rules and the process an agent follows to fill them. The design before a shape belongs to `system-design` and `architecture`, and how to write the code inside one (view bodies, modifiers and the view each attaches to, layout, API availability, redraw performance, isolation, task groups, how a load guards against stale results, test code and its stubs, SwiftData models and fetches) to `swiftui-pro`, `swift-concurrency-pro`, `swift-testing-pro` and `swiftdata-pro`, all listed in `references/related-skills.md`.
- Which API, library, protocol, endpoint, store or provider fills a shape belongs to the related skills, or to what the agent's online search finds for that app at that time. A sentence that's true only for some apps, or names a technology as the answer, becomes a question the agent asks the user or a search it runs, as `references/decisions.md` sets out.
- Out of scope: visual design, accessibility, and anything that belongs to one app built with the skill.

## Skill best practices

These come from Anthropic's [skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices), [skills in Claude Code](https://code.claude.com/docs/en/skills), [what survives compaction](https://code.claude.com/docs/en/context-window), the [Agent Skills overview](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview) and the [Agent Skills specification](https://agentskills.io/specification) and its [authoring guides](https://agentskills.io/skill-creation/best-practices), as this skill applies them, with Claude Code's [plugins](https://code.claude.com/docs/en/plugins), [plugin manifest reference](https://code.claude.com/docs/en/plugins/manifest-reference) and [plugin loading reference](https://code.claude.com/docs/en/plugins/loading) for how it ships, [Codex's skills](https://learn.chatgpt.com/docs/build-skills) and [plugins](https://developers.openai.com/codex/plugins/build) for what Codex reads, and NVIDIA's [SkillEvaluator](https://docs.nvidia.com/skills/skillevaluator/) for the Tier 1 and Tier 2 checks a skill passes before it's published. The guidance changes, so recheck the sources before changing the skill's structure or frontmatter.

**How Claude loads a skill**, in three stages, each with its own limit:

1. **The listing.** Every session lists each installed skill's `name` and `description` on every turn, and Claude decides from them alone whether to invoke the skill. Claude Code cuts an entry at 1,536 characters, and when the listing outgrows its budget, 1% of the context window, it drops the descriptions of the skills invoked least, which keep only their names. Codex fits its listing in 2% of the context window, or 8,000 characters when the window is unknown, by shortening descriptions first, so a description's opening carries its triggers.
2. **Invocation.** The `SKILL.md` body enters the conversation as one message and stays on every later turn, so each line is a recurring cost; Claude Code doesn't re-read it, so its guidance reads as standing instructions. The specification recommends under 500 lines and 5,000 tokens. After compaction Claude Code re-attaches the first 5,000 tokens of each invoked skill, within 25,000 tokens shared by every skill invoked, the most recent first.
3. **References.** A file in `references/` loads only when `SKILL.md` sends Claude to it. Claude may preview a file reached only through another reference, such as its first 100 lines.

**Frontmatter**

- Only `name`, `description`, `license` and `metadata`, in YAML that parses: a skill whose frontmatter doesn't parse loads without its description and never triggers, and Claude Code ignores a misspelled key without a warning. claude.ai and the API accept only the specification's keys (`name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools`) and reject an upload with any other, such as Claude Code's `when_to_use` or `paths`.
- `metadata` holds two strings, since the specification allows no other kind of value: `author`, the name in `plugin.json`, and `tags`, one to five lowercase tags separated by commas. SkillEvaluator's quality check looks for both.
- `name` is the folder's name: at most 64 characters of lowercase letters, digits and single hyphens, neither first nor last, without `anthropic` or `claude`.
- `description` is at most 200 characters, SkillEvaluator's limit and far under the specification's 1,024, since the listing carries it on every turn of every session. It's in the third person, with no angle brackets or XML tags. It says in a short clause what the skill does, then when to use it, with "Use when" inside the first 60 characters, since some harnesses list only those; the key use case comes first and in the words users type. It names the tasks, not the shape, which `SKILL.md`'s Purpose and The shape state, and it ends by claiming the tasks where the user doesn't name the architecture, since Claude tends to leave skills unused.
- `license` matches `plugin.json`'s.

**Structure**

- The skill folder holds only what agents read and run: `SKILL.md`, `references/`, `scripts/` for deterministic checks, and `agents/openai.yaml`, Codex's display name for the skill. Everything for people, such as `README.md`, this file, `.github/` and the license, stays outside it.
- `SKILL.md` is the entry point and holds only what every task needs, the most important first, since compaction keeps the start. It stays under 500 lines and 5,000 tokens, with its References table inside the first 5,000, and a change that adds to it cuts as much elsewhere. Its sections are: purpose, prerequisites (the toolchain and tools the shapes need), examples (the example app), the shape, dependency direction, who owns what, principles, the shapes in brief, common issues, references, available scripts (a table of `| Script | Purpose | Arguments |`), instructions (the workflows and Verify), limitations (what the skill leaves out) and related skills (a pointer to `references/related-skills.md`). A section that fits a heading SkillEvaluator's quality check looks for takes that heading.
- Its common issues are mistakes any task can make, in modules, naming, composition or navigation, each one an agent actually makes. A mistake only one shape invites, such as in paging or a keyed load, is stated once, in that shape's reference.
- A workflow is a checklist the agent copies into its response, ending in a build or test it repeats until it passes. A checklist for a task an app needs once, such as moving it into packages or a review, lives in the reference it follows, with a one-line pointer under Instructions in `SKILL.md`.
- A script in `scripts/` is run, never read: `SKILL.md`'s Available Scripts gives its arguments and where it runs, and only its output enters the context. It runs on macOS's bash 3.2 and on Linux, BusyBox's tools included, takes no interactive input, prints each failure under the rule it breaks and exits non-zero on any. It checks what a rule's home states, and states no rule of its own.
- Detail lives in `references/`, one topic per file. Every reference is in `SKILL.md`'s References table, saying when to read it, so none is reachable only through another: references stay one level deep. A reference never links to another; it points to one in plain text, as a code span such as `view-models.md#keyed-resources`, which keeps it one level deep for SkillEvaluator too.
- A one-off command the skill gives an agent pins a released version, such as `npx skills@1.9.0 add`, as the specification's [guide to scripts](https://agentskills.io/skill-creation/using-scripts) asks; SkillSpector reports an unpinned one as a rug-pull risk.
- A reference over 100 lines starts with a `## Contents` list of its `##` sections.
- Links are relative, with forward slashes and GitHub heading anchors; renaming a heading means updating every link and pointer to it.
- `README.md` is for people deciding whether to use the skill: what it does, the architecture at a glance, how to install and use it, and what it leaves to other skills. It stays short, restates no rule and shows no shape.

**Content**

- Only what an agent would get wrong without it: a placement, an ownership rule, a shape, a common issue, or a reason that guides judgment. Cut explanations of what Claude already knows about Swift, SwiftUI or Xcode.
- A rule earns its place by how often agents get it wrong. A rare case gets at most a sentence in its reference.
- One home per rule. A rule lives in one reference; `SKILL.md` carries at most one line for it (a principle, a brief, a common issue or a workflow step); other references point to it instead of restating it, and `conventions.md` holds only the names it uses. A rule stated twice drifts apart and costs tokens twice.
- One home per example, too: code shown in one reference is linked from the others, not repeated.
- Concrete examples, and one default rather than a menu of options.
- `references/related-skills.md` lists each related skill, one line each: what it covers, the `name` in that skill's frontmatter, and a link to its source; `SKILL.md`'s Related skills is a pointer to it, and a checklist that covers a skill's task names it at the line that invokes it. Prerequisites names the same skills, and `README.md`'s Works well with links the same sources. `SKILL.md`'s Instructions stop the task before the first checklist until every missing one is installed with the reference's commands, have the agent invoke each with the Skill tool at the line that names it, and Verify checks that it did. The design skills are Anthropic's System Design and Architecture, stack-agnostic and from an established maintainer; the code skills are Paul Hudson's SwiftUI Pro, Swift Concurrency Pro, Swift Testing Pro and SwiftData Pro, one author's skills that agree with each other, chosen for current APIs and a small `SKILL.md`. Where one differs from this skill, this skill's shapes and rules win, and the overlap is never restated here.

## What a change must respect

- State the rule, then a short reason when the reason guides judgment in cases the rule doesn't cover, never one that narrates how SwiftUI or a tool works.
- Examples come from the one small app in `SKILL.md`'s table, a movie browser on the TMDB API, and each idea is shown on the screen that shows it best:
  - a feature's boundary: Catalog, which owns a movie's details and cast and a person's details and credits
  - one resource: the cast screen
  - several resources and paging: Discover
  - a thing and its paged list, and a mode: a genre's movies
  - a keyed resource: a person's credits by department
  - a nested model and a port: the movie's watchlist button
  - a presentation and a draft: Search's filter
  - a filter over loaded values, and a presentation about one value: the Watchlist tab
  - a screen shown over another, from another feature: signing in from the Watchlist tab
  - data stored on the device: the Search tab's recent searches

  Reuse these screens, and add one only when none of them can show a new idea. Never bring in names, endpoints, components or screens from the apps the skill is used on; write the rule they illustrate instead.
- Code shows a shape the skill prescribes, such as a view model's state and the signatures of its loads, `XView`'s modifiers or a destination enum. It isn't an implementation to copy: no helper functions, error classifiers, test stubs or component internals, and a method body appears only where the body is the shape, such as the canonical `load()` in `view-models.md`, a paged screen's guarded `load()` or a key's reset. A rule about how a method works inside is a sentence, not code. Elide the rest with `…`.
- Examples stay simple and pleasant to read, for people as much as agents. A rare edge case never makes an example heavier; prefer cutting a rule to adding code for it.
- Example code is Swift 6 against the SDK the `Package.swift` template names, and reads at a glance:
  - Structured concurrency: loads start from SwiftUI's `.task`, `.task(id:)` and `.refreshable`, and an unstructured `Task` appears only where SwiftUI gives none, such as a button's action.
  - The SDK's own API wherever one exists (`@Observable`, `@Entry`, `@ContentBuilder`, `ContentUnavailableView.search`), never a hand-made stand-in or the API it replaced.
  - `///` documents the declaration below it; a label over a group of properties is `//`.
  - A public type that another module builds shows its public init, elided.
  - Lines stay within 100 columns: a long signature or call takes one argument per line, and a closure that doesn't fit names its parameter and takes its own lines.
- Native SwiftUI and Apple's frameworks only: no navigation libraries, DI containers or invented infrastructure.
- No API, library, protocol, endpoint, store, provider or data format is named as the answer. Where an app needs one, the skill sends the agent to the related skills, the search or the user (`references/decisions.md`).
- No invented states: an empty answer is never an error, and a screen shows only the states its design has.
- Testing guidance names the tests a bug would break, never a test for what every instance of a shape repeats.
- Describe the current design only, with no dates, old names, renames, migrations or history.
- One term per concept, as `references/conventions.md` names it: feature, screen, a tab's root screen, tab XScreen, pushed XScreen, resource, keyed resource, mode, nested model, port, place, the shared package, the Live targets, stored model, `XDestination`, `SharedDestination`, `Destination`. Names follow the Swift API Design Guidelines and that file's naming table.
- A new rule mustn't contradict an existing one. When it replaces one, change every place the old rule appears.
- Voice: plain declarative sentences in the present tense, lists over paragraphs, no "you", no all-caps emphasis, no hedging.

## Making a change

1. Work on a branch, never on `main`. From `main`, start one from the latest: `git fetch origin && git switch -c <branch> origin/main`.
2. Decide whether it belongs: architecture, ownership, a shape or the process goes in; technique goes to the related skills; an implementation choice becomes a question or a search step; one app's detail stays out. When it isn't clear which, ask.
3. Find every place the rule or name appears: `grep -rn "<term>" README.md CLAUDE.md .claude-plugin .codex-plugin .agents .github skills`.
4. Edit the rule's home first, then its line in `SKILL.md`, then `conventions.md`, then `README.md` when what the skill covers changes. Keep the descriptions in `SKILL.md`, `.claude-plugin/plugin.json`, the plugin entry in `.claude-plugin/marketplace.json` and `.codex-plugin/plugin.json` identical.
5. Run [the checks](#after-every-change).

A new reference file gets a lowercase topic name, a Contents list once it passes 100 lines, a row in the References table in `SKILL.md`, and a line in the layout in `README.md`. A new script gets a row in the Available Scripts table and a line in the layout.

## After every change

1. `python3 .github/scripts/check_skill.py` passes. It checks:
   - the frontmatter's keys, `name`, `description`, `license` and `metadata`'s `author` and `tags`, against the limits above, and that the YAML parses when Ruby is installed
   - `SKILL.md`'s sections, lines and estimated tokens, at 2.9 characters a token, as Claude's tokenizer measures this skill, and that its References table ends inside the first 5,000
   - that every reference is in `SKILL.md`'s References table and `README.md`'s layout, with a Contents list past 100 lines
   - that every script is in `SKILL.md`'s Available Scripts table and `README.md`'s layout, and that every script the skill names exists
   - that Prerequisites names, and `README.md`'s Works well with links, exactly the skills `references/related-skills.md` lists, and that Related skills links it
   - that every `npx`, `bunx` or `uvx` command in the skill, `README.md` and this file pins a version
   - every relative link and heading anchor in `README.md`, this file and the skill, every pointer in the references and in `SKILL.md`'s checklists, and that no reference links to another
   - that the descriptions and the four versions in `SKILL.md` and the Claude Code and Codex manifests agree, and that the Codex marketplace lists the plugin
   - that every Swift example stays within 100 columns, documents a declaration with each `///`, and uses none of the APIs the SDK or structured concurrency replaced, such as `ObservableObject`, `NavigationView`, `.onAppear` or `DispatchQueue`
   - `claude plugin validate .` when Claude Code is installed; its warnings that `CLAUDE.md` at the plugin root isn't loaded as context and that there's no icon are expected
2. SkillEvaluator's Tier 1 passes. Run it on a clean checkout, such as one from `git worktree add --detach`, since an ignored file such as `.DS_Store` leaves its security scan incomplete, with its reports written outside the repository. With an API key from [build.nvidia.com](https://build.nvidia.com) in `NVIDIA_API_KEY` it adds an LLM rubric and security review; without one, pass `--no-llm`. The rubric moves several points between runs, so a change that alters `SKILL.md` compares two runs of `skillevaluator tier1 rubric-eval` against two on its base:

   ```
   uv tool install 'skillevaluator[all]==1.0.1'
   skillevaluator tier1 skills/swiftui-architect \
     --skillspector-baseline .github/skillspector-baseline.yaml -r cli,markdown -o <folder outside the repo>
   ```

   Its security scan matches keywords. A reviewed false positive is waived in `.github/skillspector-baseline.yaml`, one rule per phrase per file, each with a `reason`; anything else is fixed. What remains is advisory and has no fix in the skill: Hermes leaves `agents/openai.yaml` out of its file list, where Codex needs it, Copilot CLI and OpenCode reload skills only on restart, and the quality check asks a skill with scripts for the `run_script` call of a harness this skill doesn't ship for.
3. SkillEvaluator's Tier 2 passes, with no cluster judged `DUPLICATE`: a rule repeated within the skill moves to its one home. It embeds the skill through NVIDIA's API with `nvidia/nemotron-3.5-embed-1b`, so it needs the key. NVIDIA's content screen refuses some harmless text, such as any `metadata:`, so Tier 2 runs through `.github/scripts/skillevaluator_tier2.py`, which embeds a refused chunk piece by piece and prints each one it approximated. To compare the skill with the related skills, check each out, copy each skill's own folder into one directory without symlinks, which the tool refuses, build a catalog from it and pass it with `--catalog`; content the skill shares with one is technique, which stays in the related skill:

   ```
   export SKILL_EVAL_EMBEDDING_PROVIDER=nv_build SKILL_EVAL_EMBEDDING_MODEL=nvidia/nemotron-3.5-embed-1b NVIDIA_API_KEY=<key>
   tier2="$(uv tool dir)/skillevaluator/bin/python -I .github/scripts/skillevaluator_tier2.py tier2"
   $tier2 similarity-check <related skills folder> --type skill --full-body --save-catalog <folder outside the repo>/related-skills.json
   $tier2 skills/swiftui-architect --catalog <folder outside the repo>/related-skills.json --full-body -o <folder outside the repo>
   ```
4. A new or changed code shape type-checks in a scratch package with the `Package.swift` template's settings, built with `xcodebuild` for an iOS Simulator against the current SDK.
5. A new or changed script passes `shellcheck` and `/bin/bash -n`, and runs from the root of a sample app that passes and of one that breaks each rule it checks, built in a scratch folder, with the same output on macOS and in a Linux container.
6. Review the diff for what no script checks:

   ```
   - [ ] Each rule has one home: SKILL.md carries at most one line for it, and other files point to it
   - [ ] Nothing explains what Claude already knows
   - [ ] Examples are the movie browser's, show a shape rather than an implementation, and read at a glance
   - [ ] Terms are conventions.md's, and grep finds no stale name or rule, no history, and no name from an app the skill is used on
   - [ ] README.md still describes what the skill covers
   - [ ] Nothing states UI technique the related skills own, such as a modifier's placement or an API's availability
   - [ ] No sentence holds only for some apps or names a technology as the answer; each such choice is a question or a search step
   ```

7. When the change alters what an agent produces, compare it with the branch's base:
   - Check the base out as the baseline: `git fetch origin && git worktree add --detach ../swiftui-architect-baseline "$(git merge-base HEAD origin/main)"`.
   - Give two fresh sessions the same two or three realistic tasks (add a feature, add a paged screen, link two features, place a shared type, move an app into packages), one with each skill. Start both from an empty folder, so neither reads this file, and load each skill with `claude --plugin-dir <path>`, which replaces a marketplace install of the plugin for that session. A copy in `~/.claude/skills/`, such as the skills CLI installs, isn't a plugin and still loads, so move it aside for the comparison, and confirm each session lists one swiftui-architect skill.
   - Run them on the models the skill runs on, Haiku, Sonnet and Opus, since a smaller model shows the gaps a larger one fills on its own.
   - Read both answers, and fix whatever the edited skill still leaves them to guess. A change to the description is checked for triggering on its own: on those tasks worded without naming the architecture, and on a task the skill leaves to others, such as a view's animation.
   - Remove the baseline: `git worktree remove ../swiftui-architect-baseline`.

## Pull requests and releases

- Every change reaches `main` through a pull request from its own branch, carrying exactly one semver label; the PR label workflow refuses one without. The label says what the change does to agents following the skill:

  | Label | When |
  |---|---|
  | `⚠️ semver/major` | A rule or shape changes so that code following the skill no longer conforms, such as a renamed target or a reversed ownership rule |
  | `🆕 semver/minor` | New guidance that contradicts none: a shape, a rule, a common issue, a reference, a script |
  | `🔨 semver/patch` | A correction, clearer wording or a better example, with no rule changed |
  | `semver/none` | Nothing the skill says changes: the README, this file, CI, `.github/scripts` |

- The Validate workflow runs `.github/scripts/check_skill.py` on every pull request and push to `main`, with Claude Code installed so `claude plugin validate` runs too.
- Dependabot checks the workflows' pinned actions weekly and opens a pull request labeled `semver/none` for each update. The Claude Code version Validate installs is a shell command Dependabot doesn't read, so it's raised by hand.
- A release is the Release workflow, run by hand on `main`. It takes the next version from the labels merged since the last release, writes it to the four version fields (`.claude-plugin/plugin.json`, the marketplace and its plugin entry in `.claude-plugin/marketplace.json`, and `.codex-plugin/plugin.json`), commits, tags the bare version, such as `2.2.0`, and publishes the notes, grouped by label as `.github/release.yml` sets out. Installed copies update only when `plugin.json`'s version changes, so every release changes it. A major release is cut by hand: its pull request sets the four version fields, and once it merges, `gh release create <version> --target main --generate-notes --latest` tags and publishes it. Nothing else changes a version.
- Commit, push or open a pull request only when asked. A subject line names the guidance in the imperative, such as "Keep a paged list's pages when its screen comes back", not the files touched.
