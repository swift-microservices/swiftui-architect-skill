# Decisions

This skill decides where code lives, who owns it and the shapes that hold it. What fills a shape, such as the API, library, store, provider, endpoint or format a feature uses, is decided outside it:
- by the related skill that owns the technique (`related-skills.md`)
- by an online search for the established approach, for a technique no related skill covers, when a task needs it; this skill never lists them
- by the user, for what is always asked, for a choice the search leaves open, and for anything outside this skill's scope

Each pick is recorded where the app keeps its decisions.

## The established approach first

Before designing a feature, a screen, a service, the networking client or a navigation flow, the agent searches online for how it's already solved, in this order, and never skips the search:
1. The standard: the platform vendor's documentation and guidelines, the language's evolution proposals, and the relevant RFC or OWASP guidance, such as the Human Interface Guidelines for a search screen or OWASP's MASVS for credentials kept on the device.
2. Where no standard covers it, how established apps and the community solve it.

Then:
- What the search finds is adopted inside this skill's shapes and principles. A scheme is never invented where a standard or a proven implementation exists.
- Code taken from an implementation lands in the shape it belongs in and leaves its source's architecture behind.
- When the search finds more than one established option, or leaves open a choice the user would notice, the user is asked. The agent never picks one for them.
- Without web access, the design stops, and the user is asked to enable it or to supply the sources.

## Always asked

- **Persistence**: whether the app keeps data, where, and whether it syncs.
- **Authentication**: how users sign in, through what, and where their credentials are kept.

Each is asked before the design that needs it, and this skill names no answer for either. The search for either gathers the established options to put to the user and adopts none: nothing is defaulted, picked or recommended unless the user asks for a recommendation. Once the user answers, the search finds how that answer is built, and the shapes hold it: stored data behind a service protocol (`domain.md#data-stored-on-the-device`), a signed-in account owned by one feature and reached through ports (`domain.md#cross-feature-services-consumer-owned-ports`).

A requirement outside this skill's scope, such as visual design, accessibility or a target beyond the app, is a question for the user, never an invented shape.

## Recording a decision

- Each pick, from the search or the user, is recorded with its reason and its sources where the app keeps its decisions. When the app keeps none, the user is asked where before anything is recorded.
- Nothing about one app goes in this skill.

## Warnings from dependencies

- A warning in code the app can't change, such as one inside a dependency's macro expansion, is a departure recorded with the app's decisions, naming the dependency, its version and the warning. It leaves in the change that raises the dependency to a release without it.
- No target turns off warnings or warnings as errors to hide one, in `Package.swift`, a build setting or a flag.
