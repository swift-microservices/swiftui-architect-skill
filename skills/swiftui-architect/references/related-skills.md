# Related skills

This skill decides the shapes, who owns them, their names and how the code reads. The design before a shape, a review's security pass and the technique inside a shape belong to maintained skills, each invoked when its task comes up; a checklist that covers the task names the skill at the line that invokes it.

## Which skill a task invokes

Design and review, whatever the platform:

- A feature's requirements, data, failure modes and trade-offs, before its shapes: `system-design` ([source](https://github.com/anthropics/knowledge-work-plugins))
- A choice this skill leaves open, weighed as an architecture decision record: `architecture` ([source](https://github.com/anthropics/knowledge-work-plugins))
- A review's security, performance and correctness pass: `code-review` ([source](https://github.com/anthropics/knowledge-work-plugins))

The code inside a shape:

- Names, argument labels and documentation comments of the API a module declares, by the Swift API Design Guidelines: `swift-api-design-guidelines-skill` ([source](https://github.com/Erikote04/Swift-API-Design-Guidelines-Agent-Skill))
- View bodies, modifiers, layout, data flow, localization, previews, API availability and performance: `swiftui-pro` ([source](https://github.com/twostraws/SwiftUI-Agent-Skill))
- Load bodies, stale-result guards, isolation, cancellation, actors, `Sendable` and strict-concurrency diagnostics: `swift-concurrency-pro` ([source](https://github.com/twostraws/Swift-Concurrency-Agent-Skill))
- Test code, its stubs and fixtures included: `swift-testing-pro` ([source](https://github.com/twostraws/Swift-Testing-Agent-Skill))
- SwiftData models, predicates and fetches, when the user picks SwiftData as the store: `swiftdata-pro` ([source](https://github.com/twostraws/SwiftData-Agent-Skill))

## Installing them

Every one of these eight skills is installed before any checklist starts. The skill list in the session is compared with their names; a skill installed with a plugin is present under its plugin's prefix, such as `engineering:system-design`. When any is missing, the user is asked, in one message, to install each with its source's command, and the task stops until every one is installed:

```
npx skills@1.9.0 add https://github.com/anthropics/knowledge-work-plugins --skill system-design architecture code-review
npx skills@1.9.0 add https://github.com/Erikote04/Swift-API-Design-Guidelines-Agent-Skill --skill swift-api-design-guidelines-skill
npx skills@1.9.0 add https://github.com/twostraws/SwiftUI-Agent-Skill --skill swiftui-pro
npx skills@1.9.0 add https://github.com/twostraws/Swift-Concurrency-Agent-Skill --skill swift-concurrency-pro
npx skills@1.9.0 add https://github.com/twostraws/Swift-Testing-Agent-Skill --skill swift-testing-pro
npx skills@1.9.0 add https://github.com/twostraws/SwiftData-Agent-Skill --skill swiftdata-pro
```

- A command lists only the missing skills from its source.
- A checklist line that names a skill invokes it with the Skill tool at that line, or, in a harness without one, reads its `SKILL.md` there. The agent never works from what it already knows of the skill's subject in its place.
- Verify checks that each skill the task's checklist names was invoked.

## Where this skill wins

- A related skill decides the technique inside a shape. This skill decides the shape, who owns it, its names and how the code reads (`style.md`).
- Where a related skill proposes another shape, name or style, such as a view model per view, a coordinator, a repository between a service and its view model, the store read straight from a view or a helper method in a live service, this skill's choice holds and the need it raised is met inside it.
- Their overlap with this skill is never restated here, and their examples are never copied in.

## Turning a design into shapes

- `system-design`'s answers become the checklist's lines, each landing in a shape this skill names: a capability is a feature, what a screen shows is its models, a failure is an error case, a long list is a page.
- `code-review`'s findings are ranked with this skill's own, on the review's scale (`modules.md#checking-the-boundaries`).
- An architecture decision record covers only a choice this skill leaves open, such as how the networking client is built, or the user's answer on what `decisions.md#always-asked` lists, whose options it lays out without recommending one. A choice this skill makes has none. The record is kept where the app keeps its decisions (`decisions.md#recording-a-decision`).
