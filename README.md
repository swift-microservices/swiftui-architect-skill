# SwiftUI Architect

[![Validate](https://github.com/swift-microservices/swiftui-architect-skill/actions/workflows/validate.yml/badge.svg)](https://github.com/swift-microservices/swiftui-architect-skill/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

An [agent skill](https://agentskills.io) that teaches Claude and Codex to design, build and review modular SwiftUI apps: one Swift package per feature, clear module boundaries, modern Swift, and native SwiftUI navigation that works across modules.

Ask for a feature, a screen, a link between two features, a move into packages or a review, and the agent answers with the same structure, names and shapes every time.

## The architecture

- **A package per capability.** Each feature owns every screen of its capability and the data behind them. Features never import each other; they meet only in the app, which links their screens and connects their data through small ports.
- **Boundaries the compiler enforces.** A feature splits into `Core` for its domain, `UI` for view models and views, and an adapter target for each source it reads, such as the API or a store on the device; each tested target has a test target of its own. `Core` imports neither SwiftUI nor the networking client, and each source's types stay in its adapter target, so a crossing fails the build or the skill's boundary script.
- **A domain shaped for screens.** Models describe what the app shows, not what the API sends, and each feature has errors cased by what its screens tell apart.
- **Predictable view models.** Data, loading and error for each resource, with the same shapes for paging, keyed loads, search and nested models, and the tests a bug would break.
- **Native navigation across modules.** Features say where their views go, and the app decides which screen each place shows. By default it's `NavigationStack`, `NavigationLink(value:)` and sheets, with no routers inside features, coordinators or navigation libraries unless you ask for one.
- **Modern Swift.** Swift 6 language mode with the upcoming features Swift is moving to, strict concurrency and strict memory safety, `@Observable` view models on the main actor, `Sendable` services, and loads that start from SwiftUI's own `.task`.
- **Code that reads like the requirement.** Straight-line code with Apple's sample code as the bar, values built before the calls that take them, one path per error, the toolchain's formatter, and scripts that check what they can.
- **Names you can predict.** Packages, targets, types, views and files follow the Swift API Design Guidelines and one naming table.

The trade-off is more `Package.swift` files, some deliberate duplication before anything is shared, and an app target that does the wiring. The skill keeps that cost low with templates and clear rules about where code goes.

The skill's examples follow a small movie browser on the TMDB API. Its Catalog feature, a movie's details and cast and a person's details and credits, is one package:

```
Packages/Catalog
├── CatalogCore         movies, people, credits, errors; a service protocol and mock per screen
├── CatalogUI           view models, views, destinations and strings for each screen
├── CatalogTMDB         live services that map TMDB's responses into the domain
├── CatalogUITests      view model tests
└── CatalogTMDBTests    mapping tests
```

## Installation

**Claude Code**

```
/plugin marketplace add swift-microservices/swiftui-architect-skill
/plugin install swiftui-architect@swiftui-architect-skill
```

**Codex**

```bash
codex plugin marketplace add swift-microservices/swiftui-architect-skill
codex plugin add swiftui-architect@swiftui-architect-skill
```

**skills CLI**

```bash
npx skills@1.9.0 add https://github.com/swift-microservices/swiftui-architect-skill --skill swiftui-architect
```

**Manually**

Copy `skills/swiftui-architect/` into `~/.claude/skills/` for Claude Code or `~/.agents/skills/` for Codex, for all your projects. To share it with a team, copy it into a repository's `.claude/skills/` or `.agents/skills/` instead.

## Usage

The agent loads the skill when a task matches it, even when the request doesn't mention architecture, or when asked: `/swiftui-architect` in Claude Code, `$swiftui-architect` in Codex. For example:

- "Add a screen that shows a movie's reviews, a page at a time, from the movie's details."
- "Split this app into Swift packages."
- "Where should `MovieSummary` live, and what should the card that shows it be called?"
- "Let the search results open sign-in."
- "Review this app's architecture."

To add a feature or a screen, link two features, move an app into packages or review one, the agent follows the skill's checklist. Before designing anything new it searches online for how it's usually done, and a checklist that changes code ends with a build, a test run and the skill's checks, repeated until all pass.

An app built another way keeps its structure until you ask to change it; then the skill moves it into packages one buildable step at a time.

The shapes use Swift 6 language mode and the SDK in Xcode 27 or later (Swift tools 6.4). The package template targets iOS 26; set it to your app's deployment target.

## What it covers

| Area | Covers |
|---|---|
| Modules | What a feature is, its targets and where its boundary goes, what its domain may link, `Package.swift`, the shared package and DesignSystem, strings and assets, building and testing, boundary checks, moving an app into packages |
| Domain | Models, errors, service protocols, live services, mocks, ports between features, data stored on the device, and work no screen starts |
| Networking | The API package, its client, and how its errors reach a screen |
| View models | Loading, several resources, paging, keyed loads, filtering and search, nested models, tests |
| Views | The views a screen is made of, its error and empty states, paging footers, previews |
| Composition | The app target: services, environment keys, tabs, and the screens it composes |
| Navigation | Destinations, the router, links between features, deep links, sheets, covers and alerts |
| Style | How the code reads: building values, errors, concurrency, access and imports, types and values, formatting |
| Naming | Packages, targets, types, files and folders |

It builds on SwiftUI, Observation and Swift Package Manager. Which API client, store or sign-in an app uses isn't the skill's call: the agent searches for the established approach, asks you about persistence and authentication, and records each pick where your app keeps its decisions.

Not covered: visual design, accessibility, and the technique inside each shape, such as a view's body, an actor's design or a test, which the skills below handle.

### Works well with

The skill decides the shapes and how the code reads; these skills cover the design before them, a review's security pass and the technique inside them. The agent invokes each where a checklist calls for it, such as the system design skill before a new feature and the testing skill before writing tests, and stops at the start of a task until you install any that are missing. Where one's advice differs, the skill's shapes win.

- [System Design, Architecture and Code Review](https://github.com/anthropics/knowledge-work-plugins), from Anthropic's Engineering plugin: a feature's requirements and trade-offs, decision records for the choices the skill leaves open, and a review's security, performance and correctness pass
- [Swift API Design Guidelines](https://github.com/Erikote04/Swift-API-Design-Guidelines-Agent-Skill): names, argument labels and documentation comments for each module's API
- [SwiftUI Pro](https://github.com/twostraws/SwiftUI-Agent-Skill): view bodies, modifiers, layout, data flow, localization, performance
- [Swift Concurrency Pro](https://github.com/twostraws/Swift-Concurrency-Agent-Skill): loads, cancellation, actors, `Sendable` and strict-concurrency diagnostics
- [Swift Testing Pro](https://github.com/twostraws/Swift-Testing-Agent-Skill): view model and mapping tests
- [SwiftData Pro](https://github.com/twostraws/SwiftData-Agent-Skill): models, predicates and fetches, when you pick SwiftData for data kept on the device

## Repository layout

```
.claude-plugin/              Claude Code plugin and marketplace manifests
.codex-plugin/               Codex plugin manifest
.agents/plugins/             Codex marketplace
skills/swiftui-architect/
├── SKILL.md                 what every task needs: the shape, rules, code style, gotchas, checklists
├── agents/openai.yaml       the skill's name in Codex
├── references/              read when a task reaches their topic
│   ├── modules.md           features and their boundaries, packages, what Core links, tests, reviews
│   ├── domain.md            models, errors, services, mocks, ports, stored data, lifetime services
│   ├── networking.md        the API package, its client and errors
│   ├── view-models.md       loading, paging, keyed loads, search, nested models
│   ├── views.md             the views a screen is made of, and its states
│   ├── composition.md       the app target: services, environment keys, screens
│   ├── navigation.md        destinations, the router, linking features, sheets and alerts
│   ├── style.md             how the code reads: values, errors, concurrency, imports, formatting
│   ├── conventions.md       names, folders and files
│   ├── decisions.md         the search before a design, what's always asked, recording picks
│   └── related-skills.md    the skills for design and technique, and installing them
└── scripts/                 run, not read
    ├── xcode_ci.sh          builds or tests a scheme on a simulator, failing on an owned warning
    ├── check_boundaries.sh  the boundaries the compiler can't check
    ├── check_style.sh       the style rules a script can see
    └── common.sh            what the two check scripts share
.github/                     validation, the semver label check, releases
CLAUDE.md                    authoring rules for changing the skill
```

## Contributing

Issues and pull requests are welcome. [CLAUDE.md](CLAUDE.md) holds the rules every change follows, whether an agent or a person writes it. Before pushing, run:

```bash
python3 .github/scripts/check_skill.py
```

Each pull request carries one semver label, which sets the next release's version.

## License

MIT. See [LICENSE](LICENSE).
