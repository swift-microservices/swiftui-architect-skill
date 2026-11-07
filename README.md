# SwiftUI Architect

An agent skill for structuring modular SwiftUI apps. It tells Claude, Codex and any agent that reads [Agent Skills](https://agentskills.io) where each piece of an app lives, who owns it and what shape it takes: one Swift package per feature, a small shared package, and an app target that builds services, composes screens and owns native SwiftUI navigation.

Ask for a feature, a screen, a link between two features or a move into packages, and the agent answers with the same structure every time.

## What you get

- **Boundaries the compiler enforces.** Each capability is one Swift package with `Core`, `UI` and `Live` targets. Features never import each other; they meet only in the app.
- **A domain shaped for screens.** Models describe what the app shows, not what the API sends. Generated OpenAPI types stop at the `Live` targets.
- **Predictable view models.** Data, loading and error per resource, plus paging, keyed loads, search and nested models, with the tests worth writing.
- **Native navigation across modules.** Features list where their views go; the app maps each place to a screen and registers every place at each stack root. No routers inside features and no navigation libraries.
- **Swift 6 throughout.** Strict concurrency, `@MainActor` view models, `Sendable` services, and loads that start from SwiftUI's own tasks.
- **Consistent names.** Packages, targets, types, views and files follow the Swift API Design Guidelines and one naming table.

The cost is more `Package.swift` files, some deliberate duplication instead of early sharing, and an app target that does the wiring. The skill keeps that cost predictable with templates and clear rules about where code goes.

## The architecture at a glance

```
MoviesApp/              app target: builds services, composes screens, owns navigation
Packages/
├── Discover/           DiscoverCore · DiscoverUI · DiscoverLive · DiscoverTests
├── Catalog/            CatalogCore · CatalogUI · CatalogLive · CatalogTests
├── …                   one package per capability
├── Shared/             Shared · SharedUI · SharedLive: only what several features share
├── DesignSystem/       tokens, styles and domain-free components
└── Networking/         the API's types and client, generated from an OpenAPI document
```

Dependencies point one way. A feature's `UI` and `Live` targets build on its `Core`, every feature stands on the shared package, `DesignSystem` and `Networking`, and only the app sees every feature.

Every example in the skill comes from one small movie browser on the TMDB API, so each rule is shown on a screen that's easy to picture: Discover, a movie's details and cast, Search with a filter, a Watchlist, and signing in.

## Install

**Claude Code plugin**

```
/plugin marketplace add the-braveknight/swiftui-architect-skill
/plugin install swiftui-architect@swiftui-architect-skill
```

**Codex plugin**

```bash
codex plugin marketplace add the-braveknight/swiftui-architect-skill
codex plugin add swiftui-architect@swiftui-architect-skill
```

**skills CLI**

```bash
npx skills add https://github.com/the-braveknight/swiftui-architect-skill --skill swiftui-architect
```

**Manually**

Copy `skills/swiftui-architect/` to `~/.claude/skills/` for Claude Code or `~/.agents/skills/` for Codex, for all your projects. To share it with your team, copy it to a repository's `.claude/skills/` or `.agents/skills/` instead.

## Use

The skill loads by itself when a task matches, even when the request doesn't mention architecture, or on request: `/swiftui-architect` in Claude Code, `$swiftui-architect` in Codex. Things to ask:

- "Add a screen that shows a movie's reviews, a page at a time, from the movie's details."
- "Split this app into Swift packages."
- "Where should `MovieSummary` live, and what should the card that shows it be called?"
- "Let the search results open sign-in."
- "Review this app's architecture."

An app built another way keeps its structure until you ask to change it; the skill then moves it into packages one buildable step at a time.

The shapes use Swift 6 language mode and the SDK in Xcode 27 or later (Swift tools 6.4). The package template targets iOS 26; set it to your app's deployment target.

## Works with

The skill decides structure and shape, and leaves the code inside those shapes to skills that specialize in it. Install them alongside:

- **SwiftUI:** Apple's `swiftui-specialist` in Xcode's coding assistant, [SwiftUI Expert](https://github.com/AvdLee/SwiftUI-Agent-Skill) or [SwiftUI Pro](https://github.com/twostraws/swiftui-agent-skill)
- **Swift Concurrency:** [Swift Concurrency](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill) or [Swift Concurrency Pro](https://github.com/twostraws/Swift-Concurrency-Agent-Skill)
- **Swift Testing:** [Swift Testing Expert](https://github.com/AvdLee/Swift-Testing-Agent-Skill)

Visual design and accessibility are out of scope.

## Repository layout

```
.claude-plugin/              Claude Code plugin and marketplace manifests
.codex-plugin/               Codex plugin manifest
.agents/plugins/             Codex marketplace
.github/                     checks, pull request labels and releases
skills/swiftui-architect/
├── SKILL.md                 entry point: the shape, rules, gotchas, references, workflows
├── agents/openai.yaml       the skill's name in Codex
└── references/
    ├── modules.md           features and their boundaries, packages, the shared package, tests, reviews
    ├── domain.md            models, errors, services, mocks, ports between features
    ├── networking.md        the API package, its client and errors
    ├── view-models.md       loading, paging, keyed loads, search, nested models
    ├── views.md             the views a screen is made of, and its states
    ├── composition.md       the app target: services, environment keys, screens
    ├── navigation.md        destinations, the router, linking features, sheets and alerts
    └── conventions.md       names and folders
CLAUDE.md                    how to change the skill
```

## Contributing

Issues and pull requests are welcome. Changes follow [CLAUDE.md](CLAUDE.md), which says what belongs in the skill, how its files are organized, the checks a change must pass, and the label its pull request carries.

## License

MIT. See [LICENSE](LICENSE).
