---
name: previewing-mobile-apps
description: Use when working on this mobile app and needing to see, drive, or verify its UI without a device or simulator. The mobai-dev CLI previews the app in a phone sized viewport, returns the screen as a semantic tree, taps, types and scrolls by label, screenshots, hot reloads after edits, mocks location, permissions, camera, network and auth, and repairs native only dependencies with preview adapters. Covers Flutter, React Native and SwiftUI. Needs a free MobAI account (MOBAI_API_KEY or `mobai-dev login`). Triggers on "preview", "run the app", "show me the screen", "tap", "type into", "screenshot", "mock", "scenario", "test the flow", "build the app", "mobai-dev", "AUTH_REQUIRED".
---

# Previewing mobile apps

`mobai-dev` gives this sandbox a phone shaped screen. It runs the app's real
code in a phone sized viewport, no device or simulator involved, and the same
verbs work whether the app is Flutter, React Native or SwiftUI.

The mental model, in order of importance:

1. **Read the tree, not pixels.** `preview inspect` returns every element with
   its type, label, value, flags and exact rectangle. "The button is disabled"
   is one JSON field. Screenshots are for layout judgement and for showing a
   human, never the primary read. The SwiftUI tree is FLAT (every node a
   child of `root`; a button belongs to a row only by rectangle) and a
   button whose label is an image alone has an empty label, so on a dense
   screen read texts and rects together, and use one screenshot to place
   them. On a dense list every string folds into the `Button` or `Menu`
   that owns it and there may be no `Text` node at all; simpler screens
   carry ordinary `Text` nodes. The first `inspect` after ANY state change
   (a dismissed sheet, a tap, a scroll) can be a partial tree: missing
   text, empty labels, missing `Row` wrappers. Read until two consecutive
   trees agree before concluding that something is missing (after a
   `type` that fires a request, or an appearance mock, that can be three
   reads). On a dense list a few rows still come back with an empty label
   (an image-only row): target those by `--id` from a fresh `inspect`.
   Rows (`r3`) keep their id across a frame's actions; controls (`c12`)
   do not once the view that owns them is rebuilt (a menu opening and
   closing is enough), and plain `Text` nodes (`n40`) are renumbered
   every frame, so `inspect` right before targeting anything by id. An SF
   Symbol inside a text reads as its name in brackets (`[globe] ⸱ 2h`,
   `[exclamationmark.triangle.fill]`): an icon, not words the app shows.
   One thing the tree cannot say is that a node painted nothing: pair
   every screenshot with an `inspect` of the same frame, and take that
   pair BEFORE `preview stop`, because a stopped preview cannot give the
   frame back without another build.
2. **One preview, many commands.** Start it once with `--detach`; every later
   command is a fast round trip against the running app, which keeps its state.
   `--detach` describes the engine, not the command: `preview run` itself
   returns only when the build is done and the first frame is up, minutes
   on a real app, with nothing on stdout meanwhile. Give it a long timeout
   or run it in the background, and tail `.mobai/preview.log` for progress
   (`compiling`, `pulled`, `adopted` lines arrive as the build goes; the
   log then goes quiet for minutes while the screen compiles, the longest
   phase, and a `still compiling (Nm elapsed)` line about once a minute
   of compiling says it is still going; `MOBAI_PREVIEW_BRIDGE port=` is
   the line that ends the build). A built app can still die on its first frame (an environment
   object nothing installed), so the first thing after `run` is one
   `inspect`: `PREVIEW_CRASHED` there is the real result of the run. The
   second thing is the run's `notes`, and
   `grep "placeholder\|environment audit\|could not compile\|approximated\|is a boundary\|skipped " .mobai/preview.log`:
   the record of what the frame is NOT showing (a whole composer skipped,
   a sheet that is a boundary), read before judging the screen.
3. **Failures are instructions.** Every failure is one JSON envelope with a
   `code`, a `message` and usually a `suggestion` naming the exact next
   command. Read `code` first, never parse prose.

Pass `--json` to every call.

A line on stderr before a preview verb's output saying a newer mobai-dev is
available means the published build differs from this binary (a refreshed
release keeps its version, so the commit is what is compared). Run
`mobai-dev update`: it replaces the binary in place in seconds. `setup
--json` carries the same fact as `update`. A sandbox image that bakes the
binary is stale by design; the install script refreshes it against the
published checksum, so run it at session start.

## First contact with a project

```bash
mobai-dev setup --framework flutter --json   # flutter | react-native (rn) | swiftui (ios)
```

`--framework` is required: you know what this project is, and setup prescribes
the environment for it rather than guessing from a checkout. Detection runs as a
cross check, so a `warnings` entry saying the tree looks like something else
means one of you is wrong; read it before going on.

The answer is a plan. `toolchains` lists every prerequisite for this framework
on this machine as `{name, present, version, install, note}`, starting with
`account` (the engine download needs it) and including `engine:<name>`, the
preview engine itself. `ready` is true when all of them are present.
**Install everything that is not present, in the order given, running the
commands in its `install` field verbatim**, then run setup again to confirm
`ready`. Disk: the SwiftUI engine is about 550 MB installed, 800 MB with the
paint host's fonts; the Apple images those fonts come from (about 700 MB)
are downloaded once and deleted after unpacking. Run setup again after installing anything, since some rows (the
renderer's) only appear once the engine is there; on a machine with
everything preinstalled the first plan is already complete. Nothing previews
before that. setup succeeds either way: a plan is guidance, not a failure.

## The account

Previews run against a MobAI account. Free, but not optional: the engine is
handed its permission to run by `mobai-dev`, which gets it from the MobAI
service, so a machine with no credential previews nothing. `AUTH_REQUIRED` is
what that looks like.

Nobody needs the desktop app or a prior sign-up for this: signing in with an
email MobAI has not seen creates the account, free, with the same emailed
code. So when there is no credential, ask the person for their email and sign
in, and say that this also registers them if they are new.

Two ways to hold one, and either is enough:

```bash
export MOBAI_API_KEY=mobai_...        # a key from the app; best for CI
```

or sign in, which is two ordinary commands and no prompt:

```bash
mobai-dev login                                            # who am I, if anyone
mobai-dev login --email you@example.com                    # sends a 6 digit code
mobai-dev login --email you@example.com --code 123456      # verifies it
```

The code arrives by email, so ask the person you are working with for it and
run the second command. Nothing here needs a terminal or a browser. A stored
login is refreshed automatically afterwards; you do not sign in again per
preview.

The engine is installed like anything else in the list. It lands in
`~/.mobai/engines/<name>` and every later run finds it with no configuration:

```bash
mobai-dev engines install rn --json                   # download and set up
mobai-dev engines install rn --from <dir|.tar.gz>     # from a local copy
mobai-dev engines list --json                         # what is installed
```

A missing engine also shows up later as `PREVIEW_ENGINE_MISSING` on any preview,
with the install command in its `suggestion`. A `bootstrap` of `stale` in the
listing means dependencies changed; run the install again.

### Two renderers, and why the paint host is the one to install

Skip this section when the first `setup` already lists `paint-host` and
`apple-design-resources` as present and says `renderer: "paint host (full
fidelity)"`: the machine was provisioned before, one run was the whole
setup, and nothing below applies.

The swiftui engine draws a frame in one of two ways. The **paint host** is a
Flutter application shipped inside the engine: it takes the engine's paint
tree and redraws it the way a phone would, with the iOS status bar and
navigation chrome, SF Pro text, real SF Symbols, emoji and CJK. **Cairo** is
the offline fallback the engine uses when the host cannot run: no status
bar, a substitute Latin font, no emoji, no CJK, and symbols as sketched
stand-ins. Both produce a screenshot; only one produces a screenshot that
looks like the app. A person judging a Cairo screenshot sees a broken app,
not a preview, so the paint host is not a nice-to-have. Treat installing it
as part of setup, in this order:

1. `tool/install-host-deps.sh` in the engine directory (`~/.mobai/engines/swiftui`)
   installs what the host needs from the machine: GTK, a virtual display
   (Xvfb), software GL, the Noto fonts, and the tools that unpack Apple's
   font image. It uses apt and needs root or sudo; on a sandbox that has
   them, run it. `--check` reports without installing.
2. The fonts, from Apple's own site (below). Without SF Pro the host
   does not start at all and every frame is Cairo.
3. Check `renderer` again. Cairo is only for a machine where none of the
   above can be done, and then say so in what you report.

Read the `renderer` field of the install, setup and `preview run` output,
not just `ready`. `ready: yes` means a preview can run; only
`renderer: paint host (full fidelity)` means it renders faithfully. The word
`DEGRADED` anywhere in that line means it does not, whatever the line starts
with: `cairo (DEGRADED: ...)` ships substitute fonts, no emoji and no CJK;
`paint host (DEGRADED: SF Symbols is not fetched ...)` ships every
`Image(systemName:)` as a placeholder box. Each line names its fix, and the
fix is to run it. The fonts are downloaded from Apple's own site and used
for iOS app development on this machine, never redistributed, which is what
Apple's terms allow; the variable on the install line says so to the fetch
script. There is nothing to ask about: run it, and do not settle for the
degraded default.

The setup plan lists this as `apple-design-resources`, required:
SF Pro for the text (Text, Display and Rounded cuts, plus New York for
`.serif` and SF Mono for `.monospaced`, so `.fontDesign` and large titles
measure and draw with the face a phone uses) and SF Symbols for every
`Image(systemName:)`. **It appears in the plan only once the engine is
installed**, the same as `paint-host`: the first `setup` on a fresh machine
lists `swift`, `libcairo`, `engine:swiftui`, `adapters-catalog` and
`account`, and the renderer rows join on the second run. So on a fresh machine `setup`
is run twice: once for the toolchain, once after `engines install` for what
the engine itself needs. When the first run already lists `paint-host` and
`apple-design-resources` present, the engine was installed before, and one
run is the whole setup.
`ready` is `no` until they are there, because without them every screenshot
has substitute text and placeholder boxes where the app's symbols are, which a
reviewer reads as a broken app. When the plan lists the row as missing, run
the `install` commands it gives, verbatim, then check `renderer` again. Do
this before the first screenshot you show anyone.
The fetch honours `MOBAI_SF_PRO_DIR` when it is set, and so does the
`renderer` check, so the two always agree on where "fetched" is.

## Choosing what to preview

`--entry` says WHAT to bring up. Without it each engine starts the app at its
own entry point, which is right for a small app and wrong for a real
repository. For "bring up the app", `setup`'s `project.evidence` names the
file it detected the app's root screen in (a tab shell, a root view), and
that file is usually the right `--entry`.

```bash
mobai-dev preview run --detach --json                              # the app's own entry
mobai-dev preview run --detach --entry Sources/Screens/GalleryView.swift --json
mobai-dev preview run --detach --entry GalleryView --json          # SwiftUI: by view name
mobai-dev preview run --detach --entry Sources/Screens/GalleryView.swift#PacksRail --json
```

**SwiftUI previews ONE screen and the files it reaches from there**, not the
whole project. That is what makes a large app previewable at all: everything
the screen does not need is left out, including files that import things the
engine has no answer for. Point it at the file holding the screen. What
"reaches" means, exactly: a local package the screen imports is compiled
from its real sources, trimmed to what the screen uses; the app target's own
files are pulled by name from the whole app folder (the tree beside the
`.xcodeproj`, or the project's top-level folder holding the screen when there
is no project file), so a tab reaching a helper two directories over gets
it. The notes say `pulled N project file(s) into the build` and name every
pulled file with the symbol that pulled it (`pulled Tabs.swift (for Tab)`);
a screen whose helpers went missing while the notes pulled nothing is a bug
to report, not something to work around by moving the entry. Xcode also lets a file use the extensions of any
module imported anywhere in its target, and apps lean on that without
knowing (`Label(_:systemSymbol:)` with no `import SFSafeSymbols` in the
file); the engine mirrors it for catalogue adapters, adopting and importing
them into the screen's module when another file of the app target imports
them, and says so in a note. An import a file never uses is left out of
the file's staged copy rather than costing the file. A sibling left out
because of an import it cannot resolve is named in the errors with the
member or type it declares (`'.withReceiptExport' is declared in
ReceiptExport.swift, which this preview left out because it imports
ReceiptDeviceKit`), and the chain of files that followed it out is listed
after the errors. The file joins once that import is answered: a stand-in
for the module under `mocks/`, or a preview version of the member under
`sources/`. Never redeclare a type the note says the app already has.

**The entry view is built with no arguments.** The generated entry is
`Screen()`, and most screens below the root take bindings or models
(`ParcelListView(filter:pinned:)`). The failure is
`missing arguments for parameters` in a generated `main.swift` the header
says not to edit. Give the view a preview initialiser in a supplement, which
compiles into the same module as the screen:

```swift
// .mobai/preview/swiftui/sources/ParcelListView/ParcelListPreviewEntry.swift
extension ParcelListView {
    init() {
        self.init(filter: .constant(.inTransit), pinned: .constant([]),
                  canFilter: true)
    }
}
```

No `public`: an app's screens are internal types, and a `public init` on
an internal type is an access-level error that costs a build. A supplement
is an app-target file: it has the app target's implicit imports and
nothing else, so `import` the package that declares each type you name
(`ParcelFilter` from `import ParcelModels`), the way the entry's own file
does; a type of the entry's own arguments usually lives in a local
package, and `cannot find type` after the build is that missing import.
An entry whose arguments are all `@Binding`s (a tab shell's
`selectedTab:`, a router path) needs no supplement: the engine supplies
them from a generated store and says so in the notes (`AppView takes
selectedTab:appRouterPath:; the preview supplies them from a generated
store (...)`). It refuses before building only for an argument it cannot
give a preview value (a model, a closure): `PREVIEW_ENTRY_ARGS_REQUIRED`
names that argument and the file to write. The environment objects the
screen reads (next section) are a separate wall, and a root helper that
stores a `@Namespace` id on one of them is handled by the engine too
(the plan lists it under `namespaceHelpers`, the notes say the assignment
was made). Run first. Reach for the environment plan when a run ends in
`PREVIEW_CRASHED` with `environmentMissing`, or when you want the whole
picture before deciding on a wrapper; it stages and parses the screen's
complete environment without compiling:

```bash
mobai-dev preview environment --entry Sources/Screens/HomeScreen.swift --json
```

(A path is resolved against the project directory and must exist; use the
screen's real path, whatever the app's layout is.)

The plan stages the screen's sources to read them (tens of seconds on a
real app), it does not compile. A type named `*PreviewRoot` under
`sources/` is claimed by the engine as the root when it can be built with
no arguments; give a private wrapper another name. For `preview
environment`, `--json` is the document on stdout and the engine's
`preview-swiftui:` notes go to stderr. Merging the two (`2>&1`) puts a
hundred note lines in front of the JSON, so keep them apart, or read the
notes from `.mobai/preview.log` (`preview run` writes nothing to stderr:
its notes are in the envelope and in the log)
(the staging writes them there too; the next `preview run` rotates that
file to `.mobai/preview.log.1`, so the record survives the run).

`types` is the list to install: one row per distinct type with its
`construct` expression (or provider signature) when found, the `files`
that read it and their `count`, most-read first. `reads` is the same per
file (`readsCount` rows; a real app has hundreds for a dozen types), for
finding a read site. `namespaceHelpers` names the root helpers that take
a `Namespace.ID`; the engine makes their assignment with its own
namespace, so a wrapper need not call them for that. `installedByApp`
lists root helper `.environment(...)` calls. The plan does not compile or
prove reachability. Keep the app's root helper in your wrapper. At runtime,
missing singletons and classes with a public parameterless init are conjured
with a run note (`environment: installed T.shared ...`). Provider-made
objects are yours to install when the screen reaches them. A remaining
trap reports `PREVIEW_CRASHED` with `details.environmentMissing`; the full
`details.environmentReads` list is context, not a required install list.

Pass the same values the app's own parent passes on a fresh launch, and say
so in the file. This is the ordinary way to preview a non-root screen, not a
workaround.

`.constant` is right for a value the parent computes and wrong for state the
screen WRITES through: a tab shell's `selectedTab: $selectedTab`, a wizard's
step, a filter bar's selection. With a constant binding the screen renders,
`tap` answers `ok: true`, and nothing moves, with no diagnostic anywhere.
The engine's generated store already does this for an all-binding entry.
When you write the supplement yourself (a mixed argument list), back the
binding with a store and construct the screen inside a wrapper view whose
body reads the store; a read inside the binding's `get` closure alone
does not register, and the tap moves nothing. Do not add `.id()`: a body
re-run keeps the screen's identity, `.id()` replaces it and re-runs the
root's `onAppear` on every change.

```swift
@Observable final class ParcelListPreviewState {
    static let shared = ParcelListPreviewState()
    var filter: ParcelFilter = .inTransit
}
extension ParcelListView {
    init() {
        let state = ParcelListPreviewState.shared
        self.init(filter: Binding(get: { state.filter }, set: { state.filter = $0 }),
                  pinned: .constant([]), canFilter: true)
    }
}
/// Named `*PreviewRoot` so the engine builds it instead of the screen.
struct ParcelListPreviewRoot: View {
    var body: some View {
        _ = ParcelListPreviewState.shared.filter
        return ParcelListView()
    }
}
```

A path is resolved against the project directory and has to exist; anything
else is taken as a view name, and a view name is looked up in every `.swift`
file under the project (`Sources/`, packages, wherever it lives). So
`--entry Sources/Screens/GalleryView.swift` and `--entry GalleryView` are both
fine, and a typo in a path falls back to being treated as a name rather than
silently previewing something else.

A screen file usually declares its helpers beside the screen (GalleryView
plus LevelBadge, DailyBanner, PacksRail). The engine previews the view that
nothing else in the file builds, or the one named like the file, and says
which in its notes. To preview a helper on its own, or when the file really is
ambiguous (`PREVIEW_VIEW_AMBIGUOUS`), name both: `--entry <path>#<View>`.
Never work around this by picking a different screen than the one asked for,
and never write a showcase screen of your own and present it as the app.

On a SwiftUI project with no screen at its root, running without `--entry` is
refused outright with `PREVIEW_ENTRY_REQUIRED`, and `details.screens` carries
the files it found, sorted by path. Pick one from that list, or any other
file that declares a `View`: the list is a menu, not a whitelist, and the
screen you want (a tab, say) is often the one deeper in the tree. It refuses
rather than guessing
because the alternative, compiling outward from the project root, meets an
unsupported dependency, then the next one behind it, and never converges.

If a preview fails with `PREVIEW_UNSUPPORTED_MODULE` or a compile error in a
file you did not expect, the target is usually too broad: name the screen's
file rather than the project.

## The loop

The expected first run on a real app is: an empty `.mobai/`, one
`preview run`, the screen. The catalogue adopts the third-party modules
the app imports, the engine writes stand-ins for the SDK frameworks it
cannot run, bodies the platform cannot compile are demoted with the
compiler's own line quoted, an all-binding entry gets its bindings from a
generated store, and the app's own scene stages the environment: its
root helpers, and the modifiers it writes inline above the root (a tint,
a preferred colour scheme, environment objects and values, a model
container), with a note naming any it could not give a value.
A 13-package app with hundreds of files has come up this way with
nothing written by hand. Write a supplement, a wrapper, an adapter or a
rewrite only after a failure names it; nothing in the sections below is
a checklist to work through before the first run.

```bash
mobai-dev preview run --detach --json                 # once
mobai-dev preview inspect --json                      # what is on screen
mobai-dev preview tap --label Continue --json
mobai-dev preview type --label Email --text a@b.com --json
mobai-dev preview scroll --direction down --amount 400 --json
# ...edit source...
mobai-dev preview reload --json                       # pick the edit up
mobai-dev preview inspect --json                      # confirm the change
mobai-dev preview screenshot --out /tmp/shot.png --json
mobai-dev preview inspect --json                      # the tree that goes with that screenshot
mobai-dev preview stop --json                         # when done
```

`scroll` answers with `requested` and `movedPoints`, both in points (the
tree's `ScrollView` `value` is the offset after the move). The engine
scrolls in passes so a lazy list can realise rows on the way; a move that
still comes up short reached the end of what the list holds. A `tap` that
matched a label loosely (whole words, case aside: "Save" reaches "Save
post") says so with `matched`; an exact label never carries it.

The first `inspect` of a real app is often a wall of unlabelled `covered`
buttons under a sheet the app presented on launch. Take one screenshot to
see what is presented, dismiss it (its close control is usually in the
tree by label even when it draws as an icon: look for `Cancel`, `Close`,
`Done` or `Dismiss` before falling back to `--point`), then inspect again. Chrome such as a
tab bar can carry a label in one frame and none in the next (selection,
list virtualisation): for chrome, target by `id` from a fresh `inspect`.

Targets resolve by `--id`, then `--label`, then `--text-match`, then
`--point x,y` (logical points in the viewport, not pixels). Prefer labels:
coordinates break on every layout change. `TARGET_AMBIGUOUS` lists candidates
rather than guessing; make the target more specific. Node ids are per
frame: they are reassigned on every run and after most actions, so
`inspect` right before each target rather than reusing an id from an
earlier tree. Labels and types move too: the same post body can be a
labelled `Button` in one tree and a bare `Text` beside an unlabelled
`Button` in the next, once its text stops fitting inside the control's
rect, so a `--label` that matched a frame ago is checked against the
fresh tree the same way. An icon-only button (`Image(systemName:)` with no text) has
an empty label; target it by id from a fresh `inspect`, or by
`--text-match` on a neighbour.

`ok: true` on a gesture means the command was accepted, not that the app
moved: a frozen binding or a container the engine cannot scroll answers
`ok` and changes nothing. After a gesture, compare `inspect` before and
after (a `ScrollView` node's `value`, the visible texts); when the tree is
the same, the app did not move, whatever the envelope said.

Do NOT restart the preview after each edit; reload exists for that. Do NOT
screenshot to check logic; inspect the tree. Do NOT start a second preview for
the same project.

Two things about the loop that are easy to get wrong:

- **A crashed preview still holds its port.** After `PREVIEW_CRASHED` the
  engine keeps answering with that envelope so nothing races in behind it;
  `reload` cannot revive a dead process, and `run` answers
  `PREVIEW_ALREADY_RUNNING`. Run `preview stop`, then `preview run` again.
- **A signed-in state you cannot mock is not a gap to chase.** An app whose
  sign-in is a keychain token or a native SDK (OAuth in a web view, Sign in
  with Apple) renders signed out in the preview, shows what it shows a
  new user (a public timeline, a sign-in sheet), and no scenario section
  changes that. Preview that state; it is the app's own.
- **Network is real by default.** Unless a scenario's `network` section
  answers a route, the app's requests go out to the internet, and a
  data-driven screen's first frame is its loading state (a skeleton, a
  spinner), then whatever the app shows a signed-out user, often its own
  error state with a Retry. That is the app being honest, not the preview
  failing. To show content, mock the routes and then verify they were
  hit: the engine writes one line per request to `.mobai/preview.log`
  (`preview-swiftui: net GET /api/v1/timelines/home -> route 200 (4712
  bytes, inline)` or `-> passthrough (no route)`), a second line when a
  passthrough request comes back (`-> passthrough 200 (23108 bytes,
  0.6s)`, or `passthrough failed after 30.0s: ...`), one line per remote
  image the paint host loads (`preview-swiftui: img load https://... ->
  ok` or `-> failed (HTTP request failed, statusCode: 403 ...)`: a banner
  that stays a placeholder has its reason there), and `preview
  mock-state` reports the `unmatched` requests (the app's real paths,
  which is the list to mock), the `inFlight` count, and `hits` per route
  once a scenario has routes, so a route that never matched is one read
  away. A read (`inspect`, `screenshot`)
  waits up to 3 seconds for requests still in flight, so what it returns
  is what the app did with the answer, not the loading state it showed
  before it. What the app tells its own `os.Logger` lands in the same log
  as `preview-swiftui: app log [category] error: ...` (debug and trace
  stay quiet), which is where a caught decode error is read. Only
  `URLSession.shared` is seen; a session the app builds from its own
  configuration goes straight out, unlogged, until an adapter calls
  `PreviewURLProtocol.enable(in: configuration)` on it. The previous two
  runs' logs are kept as `preview.log.1` and `.2`.
- **A real app's build is minutes, not seconds.** A screen that pulls its
  packages compiles in 3 to 5 minutes, and `reload` is a full rebuild. So
  a failed build is read once, in full: `details.errors` first, then the
  notes in `.mobai/preview.log` (what was pulled, what was left out and
  why, which bodies were demoted and why), then the staged copy under
  `.mobai/preview/swiftui/generated/` when an error names a line there.
  Fix everything those name in one edit and run once, rather than one
  fix per build. The preview engine's notes (`preview-swiftui:` lines) are
  the log; nothing else in it is about the app.
- **The CLI runs where the project is.** `.mobai/` lives in the project
  directory and the engine reads it from there, so on a remote machine or
  in a container every `mobai-dev` command and every supplement file is
  written there (`docker exec ... bash -lc 'cd /proj && mobai-dev ...'`),
  and a supplement is copied in as a file rather than typed through a
  quoted heredoc, which mangles `$` and backslashes on the way.
- **`preview info` needs a running preview.** Capabilities and mock
  sections are readable only after the first successful `preview run`; on
  the first run, write the scenario from the schema in
  [writing-scenarios.md](./writing-scenarios.md) and read `info` after.
- **After a crash, `preview stop` may answer `PREVIEW_NOT_RUNNING`** when
  the process has already gone; that is fine, run again.

## Failure codes worth knowing

| code | it means | do |
|---|---|---|
| `PREVIEW_NOT_RUNNING` | no preview up | `preview run --detach` |
| `PREVIEW_ALREADY_RUNNING` | a preview (or the crash envelope of one) holds the port | `preview stop`, then `preview run` |
| `PREVIEW_VIEW_AMBIGUOUS` | SwiftUI: the entry file declares several views | name the view: `--entry <path>#<View>` |
| `PREVIEW_BUILD_FAILED` | SwiftUI: a `reload` did not compile; the old build keeps running | fix what `details.errors` names, reload again |
| `PREVIEW_REWRITE_MISMATCH` | SwiftUI: a `rewrites.json` rule matched a different number of call sites than its `expectedMatches` | `details.rules` names the rule; fix its `target` or count |
| `ENGINE_ERROR` | the engine answered something the CLI could not use, or the connection dropped | read `message`; if the preview died on this action the next call says `PREVIEW_CRASHED` |
| `TARGET_NOT_FOUND` / `TARGET_AMBIGUOUS` | bad target | fix the target; candidates are listed |
| `ACTION_UNSUPPORTED` | this engine cannot do that | check `preview info` (`capabilities.actions` lists what `preview` verbs the engine takes), do it another way |
| `PREVIEW_ENGINE_MISSING` | engine not installed | run the `suggestion` |
| `PREVIEW_ENTRY_REQUIRED` | SwiftUI, and no screen was named | pick one from `details.screens` and pass it as `--entry` |
| `PREVIEW_ENTRY_ARGS_REQUIRED` | SwiftUI: an entry argument the engine cannot give a preview value (bindings it supplies itself), refused before building | write the `extension Screen { init() }` supplement the `suggestion` names, with the values the app's parent passes |
| `AUTH_REQUIRED` | no MobAI account on this machine, or the stored login was rejected | set `MOBAI_API_KEY`, or `mobai-dev login`, which also creates the account (see [The account](#the-account)) |
| `PLAN_REQUIRED` | the account is signed in but its plan does not include this (published devices, simulators shared from CI) | `mobai-dev upgrade --plan monthly` prints a payment link; give it to the person, the upgrade applies on the next command |
| `ENGINE_NOT_PERMITTED` | the engine was started without its permission, which normally means it was run directly | start previews with `mobai-dev preview`, never by calling the engine binary |
| `PREVIEW_UNSUPPORTED_MODULE` | dependencies that cannot run in the preview. `modules` lists every one found at once | first check the target is the screen's file and not the project (see [Choosing what to preview](#choosing-what-to-preview)); if the screen really needs them, write the adapters in one go: [writing-preview-adapters.md](./writing-preview-adapters.md) |
| `PREVIEW_COMPILE_FAILED` | the source does not compile | `details.errors` carries the compiler's lines; fix what they name |
| `PREVIEW_COMPILE_FAILED` with `unable to type-check this expression in reasonable time` | SwiftUI: a member used LATER in that expression does not exist in the preview (a modifier, a `.token`), and the solver tried every overload before giving up; the line named is fine and the real error is never printed | find the missing member by type-checking a copy with the trailing modifiers removed one at a time, then declare it under `sources/` (an `extension View` absorber, a `PreviewModifierToken` member). Never split or replace the app's expression |
| `PREVIEW_COMPILE_FAILED` with `type 'PreviewModifierToken' has no member 'x'` | SwiftUI: `.x` is a style or option value (a list style, a tab view style) the preview has no token for | `extension PreviewModifierToken { public static let x = PreviewModifierToken() }` in `sources/`; the modifier accepts it and draws its default. No rewrite |
| `PREVIEW_UNIMPLEMENTED` | SwiftUI: the screen reached an API the preview engine has not implemented (`details.api`, `details.site`, `details.appFrame`) | yours to implement: see [When the engine has not implemented something](#when-the-engine-has-not-implemented-something) |
| `PREVIEW_CRASHED` | SwiftUI: the preview process died. `details.fatal` carries the runtime's own message when there was one (`No Observable of type X found`); `details.environmentMissing` then names the objects still missing (the one that trapped first), and `details.environmentReads` lists every `@Environment(T.self)` the staged sources read, for context only | install the remaining objects `environmentMissing` names (shared/public-init defaults were already attempted), in one supplement (see [Stage the app's root environment](#when-the-engine-has-not-implemented-something)); with no `fatal`, the log's backtrace names the API or the app line; a death that printed nothing is an engine defect to report |
| `PREVIEW_APP_ERROR` | React Native: the app threw before rendering | `details.pageError` names the file and line; `details.bundlerError` the module that failed to transform |
| `PREVIEW_RESTART_REQUIRED` | Flutter: an adapter was added or removed after the engine started | `preview stop`, then `preview run` again |
| `PREVIEW_MOCK_UNSUPPORTED` | capability not held by this engine | `details` lists what it does hold |

## Mocking the world

The app's environment, location, permissions, what the camera returns, what
the network answers, who is signed in, is data, not devices. Set it at start
with a scenario file, or change one capability live with no reload:

```bash
mobai-dev preview run --detach --scenario scenarios/checkout.yaml --json
mobai-dev mock location '{"lat":52.52,"lng":13.405,"label":"Berlin"}' --json
mobai-dev mock permissions '{"camera":"denied"}' --json
mobai-dev mock appearance dark --json
mobai-dev preview mock-state --json                   # the world as it stands
```

A live mock keeps the app's state, which is the point: drive to a screen, then
flip the condition it should react to. `preview run --appearance dark` starts
in dark mode, and because appearance is a live mock you can screenshot a screen
in both themes without restarting the engine or driving back to it. Values are
the same shapes scenario sections use; pass objects, not bare words. Check
`capabilities.mocks` in `preview info` before writing a scenario. Full schema
and worked examples: [writing-scenarios.md](./writing-scenarios.md).

## When a dependency cannot run

A package that talks to real hardware cannot execute in a preview. The engine
refuses with `PREVIEW_UNSUPPORTED_MODULE` naming the module, the importing
file, and the exact path where an adapter goes.

The engine tries the adapters catalogue first, by itself: dozens of common
packages already have a drop-in adapter, and `mobai-dev engines install`
keeps a local copy of the catalogue under `~/.mobai/adapters`. When an
import cannot resolve and the copy has an adapter for it, the engine puts
that file into the mocks directory (first line `// mobai-adapter: ...`
naming the catalogue commit) and starts again; you see a note, not a
diagnostic. The copy is the project's now: it is never copied over again.
**While that first line is there the engine still edits the copy**: when the
app reaches a name the adapter lacks, the declaration is appended from the
SDK IR at the end of the file, and when the compiler reports a name the
adapter declares as ambiguous with one something real provides, the repair
loop removes the adapter's copy of it. So an edit of yours can be undone
by the next run for as long as the marker is present. To fix a bug in an
adapter, **delete the `// mobai-adapter:` line first** (or the `Generated
from MobAI normalized Apple SDK IR` line of a generated stand-in), then
edit; a file with no engine marker is left alone entirely, by adoption,
growth and the repair loop alike.

To keep a whole app file out of the build instead (the one importer of a
framework the screen never runs), list its file name, one per line, in
`.mobai/preview/swiftui/excluded.txt`. That is the data-only answer when an
extension or helper file drags in a subsystem the screen does not need.

When the diagnostic still comes, read its last sentence. "No local adapters
catalogue was found" means the copy was never fetched, so:

```bash
mobai-dev adapters update     # fetch or refresh the local catalogue
mobai-dev adapters status     # where it is and which commit
```

then run the preview again. `adapters update` fetches an archive and, when
a sandbox proxy refuses that, clones the repository itself; you do not run
git. One refused GitHub endpoint says nothing about the others: sandboxes
commonly kill `codeload.github.com` and `api.github.com` while release
downloads from `github.com` and `git clone` go through, so test the URL you
actually need before concluding that GitHub is blocked. "has no adapter of that name" means the
catalogue does not cover the module; check the index anyway, since a
freshly merged adapter may be newer than the copy, at
https://github.com/MobAI-App/mobai-dev/blob/main/adapters/INDEX.md, and fetch
it raw into the path the diagnostic named:

```bash
# SwiftUI: adapters/swiftui/<Module>.swift, RN: adapters/rn/<package>.ts(x),
# Flutter: adapters/flutter/<package>.dart. Fetch raw, into the named path.
curl -fsSL https://raw.githubusercontent.com/MobAI-App/mobai-dev/main/adapters/swiftui/AVKit.swift \
  -o .mobai/preview/swiftui/mocks/AVKit.swift
```

Only when the catalogue has nothing for it, write a small adapter in the
app's own language mapping the package's used surface onto the preview's
primitives, and the preview resumes. Never edit the app's production source
for this. Mechanics per framework: [writing-preview-adapters.md](./writing-preview-adapters.md).

**A missing name rather than a missing module** (`PREVIEW_COMPILE_FAILED`
with `cannot find 'X' in scope`, and the errors list says nobody declares X):
an adapter is scoped to files that import its module, so it cannot help a
file that imports only SwiftUI. Two places can, both outside the app's
source:

- `.mobai/preview/swiftui/sources/<X>.swift` compiles into the app's own
  module. Every file sees what you declare there, no import needed. This is
  the universal fix: any type, function or extension the preview lacks, in
  ten lines, with real behaviour if the screen needs it.
- SDK names the engine does not carry (a UIKit type, say) are filled in by
  the engine itself from its SDK catalogue, into
  `.mobai/preview/swiftui/mocks/UIKit.swift`, which every file sees as it
  would on a phone. Those stubs compile but hold no behaviour; when a stub
  makes a screen render empty, give it a body in that file (your edits are
  kept) or declare a real one under `sources/`.

Both are `.mobai/`-only. If the engine's own message tells you where the
name should go, that path wins.

## When the engine has not implemented something

The SwiftUI preview engine is a reimplementation, and parts of SwiftUI are
still missing from it. When a screen reaches one, the preview stops with
`PREVIEW_UNIMPLEMENTED`: `details.api` names the API (`GraphicsContext.fill(_:with:)`,
`Path.contains(_:eoFill:)`), `details.site` the engine file, `details.appFrame` the
app line that reached it when known.

Most of these are announced before the first run: the engine's notes carry
`PREVIEW_UNIMPLEMENTED_API` lines naming the file, the API and the override
whenever a staged source calls into something the engine lacks. Treat a
note as the same work, done earlier.

**This is yours to implement.** Nobody at MobAI is going to do it for this
run, the app's source is not to be touched, and there is no flag that makes
it go away. Everything you need is project-side:

- **Shadow the type.** Declare your own `struct Canvas<Symbols: View>: View`,
  `struct AsyncImage`, `class UIBezierPath` in
  `.mobai/preview/swiftui/sources/<Type>.swift`. App code binds to the
  project's declaration over any imported one, engine types included, with no
  import changes. Express the drawing with what the preview already paints:
  shapes and `Path`, fills, gradients, images, text. A shadowed `Canvas` that
  records the closure's fills into `Path`s and shows them as `Shape`s renders.
  Limits: a qualified name (`SwiftUI.Canvas`) and a value handed to an API
  that wants the engine's own type are not shadowed; those go through a
  rewrite. A contextual member the preview lacks is added, not shadowed:
  when the error says `type 'PreviewModifierToken' has no member 'x'`,
  extend that token type in `sources/` (see the failure table); when it
  says `type 'Font?' has no member` or names another engine type, extend
  that type the same way.
- **Rewrite the call.** For a modifier or method on a type you cannot replace,
  add a rule to `.mobai/preview/swiftui/rewrites.json` mapping the member to
  one you declare in `sources/` as an extension. The engine applies it to the
  staged copy of every app file; the app's files are untouched.

  ```json
  {"rules": [
    {"kind": "memberCall", "name": "contentTransition", "to": "_previewContentTransition",
     "on": "View", "target": "Sources/UI/*.swift", "expectedMatches": 1}
  ]}
  ```

  `kind` is one of `memberCall` (`.name(...)`, `.name { }`), `memberProperty`
  (`.name`), `keyPathMember` (`\.name`), `initializer` (`Name(...)`),
  `qualifiedName` (`SwiftUI.Name`). `target` is a glob on the file's path
  under the project (default: every file). `expectedMatches` fails the build
  as `PREVIEW_REWRITE_MISMATCH` when a build that staged the targeted file
  saw another count, so a rule that stopped matching is noticed. The engine
  notes every rule's count per file.

  A call inside a **local package** is rewritten too, but that module cannot
  see `sources/`: put its replacement in
  `.mobai/preview/swiftui/targets/<Module>/<Name>.swift`, which compiles into
  that module's preview copy.
- **Give the app's own method a preview body.** When a body in the app's
  code cannot compile for the preview (a call into a hardware framework the
  preview has no stand-in for, say), the build does not fail: that one body
  becomes a trap and the rest of the file stays real. Bitmap drawing is not
  such a case: `CGContext`, `CGImage`, `UIGraphicsImageRenderer`,
  `UIImage(cgImage:)`, `pngData()` and `Image(uiImage:)` are real on Linux
  (Cairo behind CoreGraphics), a `UIView` that overrides `draw(_:)` draws
  into its frame, and `[CGColor] as CFArray` is accepted. What is not there:
  text drawing through NSString, CoreImage filters, shadow blur (shadows
  draw offset, unblurred). The engine notes each demoted body with the
  compiler's reason, the tree and `/info` carry `"compileFallback": N`, and
  a detached `preview run` returns the build's `notes`: demoted bodies,
  placeholders, the root's environment audit and sheet boundaries first,
  then the files pulled and left out (a long pull list is cut with a
  "... and N more pulled files" note). Read them after a SUCCESSFUL run
  too: they are the record of what the frame is not showing, and a missing
  toolbar or an empty section is usually one of those lines.
  `.mobai/preview.log` holds the same lines plus everything the engine said
  in between (the full pull list, adapter adoption, network lines), so
  after a successful run also read
  `grep "placeholder\|environment audit\|could not compile\|approximated\|is a boundary\|skipped " .mobai/preview.log`:
  one placeholder line can take a whole layer with it (a sheet registry
  whose one unbuildable case makes every sheet a placeholder). If the screen
  actually reaches a trapped body, the preview stops with
  `PREVIEW_UNIMPLEMENTED` whose `origin` is `app` and whose `api` names the
  method. The fix is a `declarationBody` rule: the statements you write are
  spliced into the original declaration when the file is staged, so call
  sites, protocol dispatch, generics and private members all keep working.
  The engine's demotion note carries the compiler's line (`ToolbarTab.body
  could not compile for this platform (line 31: value of type 'some View'
  has no member 'sharedBackgroundVisibility')`); when the reason is a name
  the preview lacks, declaring that name under `sources/` keeps the real
  body, which beats replacing it. A type-check timeout is never a
  `declarationBody` case (see the failure table).

  ```json
  {"kind": "declarationBody", "name": "SoundBank.preload(_:)",
   "target": "Sources/Engine/SoundBank.swift",
   "body": "bodies/SoundBank.preload.swift", "expectedMatches": 1}
  ```

  `name` is the enclosing types dotted, then the member with its argument
  labels (`Store.init(path:)`, `Theme.accent` for a computed property).
  `body` is a file under `.mobai/preview/swiftui/` holding plain statements,
  no braces. Return what the preview can show: a placeholder image, a
  description, a fixed value. Files with `@objc`, `#selector` or
  `CADisplayLink` compile as they are; the interop is removed from the
  staged copy and the display link never fires.
- **Stage the app's root environment.** A screen previewed on its own has
  no app root, so nothing ran `.environment(_:)` above it, and reading
  `@Environment(SomeObject.self)` that nothing set traps exactly as it does
  in SwiftUI (`No Observable of type ParcelNavigator found`). Scenarios do not
  fix this: they mock the world's data (location, permissions, network,
  auth), not the app's own objects. The crash envelope's
  `details.environmentMissing` names what is still missing; supply all of
  it in one go rather than one per rebuild (`details.environmentReads` is
  the full list of reads, most of them already installed). Two ways, both
  under `.mobai/preview/swiftui/`:
  - a supplement in `sources/` declaring
    `@MainActor public func mobaiPreviewEnvironment<V: View>(_ root: @autoclosure () -> V) -> AnyView`
    (`@MainActor` because the app's objects almost always are, and reading
    `Palette.shared` from a nonisolated function does not compile)
    that returns `AnyView(root().environment(ParcelNavigator()).environment(ParcelPalette.shared))`,
    with whatever the app's own root installs (a `withPreviewEnvironment()`
    helper the app keeps for its own previews is fair game). The generated
    entry wraps the screen in it when it exists. The root is an autoclosure
    so setup runs before the screen's struct is built.
  - `extension ParcelNavigator: PreviewEnvironmentDefault {}` in a supplement,
    for a class with a public `init()`: the engine then conjures one shared
    instance per type instead of trapping. Cheaper, but the object is the
    empty default; the wrapper is where a configured one comes from.
  - A type with neither (its only initialiser takes a model and a client,
    or is internal to its package) is built the way the app builds it:
    search the app for `TypeName(` or a `.shared`/provider that hands one
    out, and install that value in the wrapper.

  Where supplements go: `sources/*.swift` compiles into every screen of the
  project; `sources/<EntryFileStem>/*.swift` (the entry file's name without
  `.swift`) only into previews of that entry. Use the flat form unless two
  screens need different environments. `mobaiPreviewEnvironment` and the
  entry's `init()` are found by name in either place, so both files may sit
  in the entry's directory together.
- **Compose the primitives.** Beside every fill, shape, `Path`, gradient,
  image, text and symbol the preview paints, `import SwiftUI` brings four
  views made for overrides:
  `PreviewRaster(png:)` draws bytes you produced (a software rasteriser, or
  pixels computed outright);
  `PreviewBackdropBlur(sigma:)` blurs what is already painted under its
  frame, which is what a Material is (put a translucent fill over it);
  `PreviewGroup(opacity:clip:) { }` composites its content as one layer with
  that opacity, clipped to a `Path` in its own coordinates;
  and a `StrokeStyle`'s dash, cap and join are honoured on any stroke.
  A tappable control in an override is an ordinary `Button` or gesture;
  they register with the control tree like the app's own.
- Keep it honest: a stand-in that draws nothing where the app draws
  something is a wrong preview, not a fixed one. Draw the closest thing the
  primitives allow, and say what is approximated in your report.

**Then contribute it.** An override written for one project fixes the same
API for every project. Open a PR to https://github.com/MobAI-App/mobai-dev
adding the file under `adapters/swiftui/overrides/`, with one line in
`adapters/INDEX.md` saying which API it covers. Do this every time; it is
how the catalogue got its adapters.

## Framework differences

Read `preview info --json` for the engine's actual capabilities instead of
guessing. The differences that matter:

- **Flutter**: hot reload via `preview reload`, state kept. First run builds a
  host app and takes minutes; later runs are fast. The host follows the app:
  its assets and fonts, its lock file, its macOS build settings, a `main`
  that takes arguments. The app believes it runs on a phone
  (`defaultTargetPlatform` is iOS, or Android under an android profile), but
  `Platform.isMacOS` from dart:io still says the desktop, so an app that
  branches on dart:io takes its desktop path. A channel the app opens to its
  own native code (not a plugin) is answered from a preview entry at
  `.mobai/preview/flutter/preview_main.dart` with `PreviewChannels.stub`; the
  same entry is where anything the app needs before its `main` goes. An
  adapter added after the engine started answers `PREVIEW_RESTART_REQUIRED`
  on reload: restart the preview.
- **React Native**: edits apply on their own through Fast Refresh; `reload` is
  a full page reload and loses component state, so it is rarely wanted.
  expo-router file based routing is supported. The engine handles what Metro
  would: tsconfig and babel import aliases, `require()` and CommonJS in the
  app's files, JSX in `.js`, `process.env` with the `EXPO_PUBLIC_*` values
  from the `.env` files, the app's own `babel.config.js` on the app's files
  (babel-preset-expo, NativeWind, Tamagui's compiler, decorators, with a
  Metro caller on iOS), the worklets plugin, `.ios` and `.native` files when
  no web or plain file exists. Do not write shims for any of that. The app's
  own code sees `Platform.OS` as the phone; dependencies see the web, so a
  library takes the fallback that renders in a browser. A Babel config that
  cannot load is reported on stderr and the built-in transforms carry on.
  What is not there: a named export the app imports from a module that never
  defines it, which Metro leaves undefined and ESM refuses, so shim that
  module under `mocks/` at its aliased path. A
  mock applies to the app's own imports; a library importing the same
  package keeps the real one unless the mock's first lines carry
  `@mobai-deep`.
- **SwiftUI**: previews one screen and what it reaches, so `--entry` names
  the file holding that screen (see [Choosing what to
  preview](#choosing-what-to-preview)). `preview info` reports
  `hotReload: false` and `reload: true` for this engine: `reload` is a
  rebuild and restart behind the same port, never a state-keeping hot
  reload, and it takes as long as a build. **Pushed destinations are not
  built.** In every file the screen reaches (a routing registry, a
  sibling), a `navigationDestination` closure is a boundary: the screen
  behind it is not compiled, and a push in the preview shows "Not built
  for this preview" with a `Back` button (a presented boundary has a
  `Dismiss` button instead). Sheets, full-screen covers,
  popovers and alerts are part of the screen that presents them and stay
  real, so a signed-out tab that opens its sign-in sheet on first launch
  shows that sheet. One exception: when a reached file's sheet closure is
  a `switch` over the presented item (a registry listing every sheet in
  the app), only the arms whose case the screen's own files name
  (`presentedSheet = .addAccount`) stay real; the other arms are
  boundaries. To see a pushed destination, preview it with its own
  `--entry`; the notes say which files had a closure bounded. **`#available(iOS 26.0, *)` is true
  in the preview**, on purpose: an availability check's `*` arm answers yes
  on the host, so the NEWEST branch of the app is the one compiled and run,
  and the older `else` has to compile too because it is in the same file.
  The engine carries the bar API those branches reach (`ToolbarSpacer`,
  `safeAreaBar`, `scrollEdgeEffectStyle`, `toolbarBackground(_:for:)`,
  `glassEffect`); a newer name it lacks is a plain `cannot find` in the
  errors, and goes in `sources/` like any other missing name. Do not try to
  make the older branch win. `reload` recompiles and restarts behind the same port; the
  response carries `stateReset: true`, so re-drive to the screen under work
  after a reload. A failed edit answers `PREVIEW_BUILD_FAILED` and the old
  build keeps running. Sheets, alerts, confirmation dialogs, menus and
  context menus present for real: the presenter's controls carry `covered`
  and refuse taps while one is up (a `covered` control reports no label
  either, though a covered `Text` keeps its words: to read what is behind
  a sheet, dismiss it first), a
  `Menu` node opens on tap (the tree
  gains `covered` flags and a `Dismiss menu` node; a menu whose content
  fetches on appear can miss the FIRST `inspect` after the tap, so read
  twice before concluding it did not open; the first `inspect` after a
  `scroll` can likewise miss the `Row` wrappers and the labels of rows
  realised by the scroll, so read twice before concluding a row has no
  swipe actions), and a `Menu` whose rect sits
  far outside the viewport after a tab switch is a stale node, not a
  target), a node under a context menu carries `longPress` and a
  `longPress` action opens it, and any button inside an alert, dialog or
  menu closes it after its action.
  Lists of any length lay out; there is no row ceiling. `import Charts` and
  `import MapKit` draw (marks from their data, a map with its markers and
  the scenario's location); do not write adapters for them. A row with
  `.swipeActions` is a `Row` node flagged `swipeActions` (when a dense
  list shows no `Row` node yet, the row is the largest `Button` whose
  rect encloses the row's other controls: swipe that one by id, the
  engine resolves the row under it, and the envelope's `drawer` field is
  the answer):
  `preview swipe --id <row> --direction left` opens the TRAILING drawer
  and `--direction right` the LEADING one (the row's label lists every
  action, both edges together); the drawer's buttons are `Button` nodes,
  the opposite swipe closes an open drawer, and a long swipe runs the
  first action. The envelope's `drawer` field is the answer (`opened`,
  `closed`, or `ran <title>`), no `inspect` needed to confirm it. A
  `swipe` on anything else is a drag: the content follows the finger, so
  swiping up moves down a list. The envelope's `action` says which path
  ran: `swipe` for a drawer, `drag` for a plain drag, and a `drag` answer
  on a row you meant to swipe carries a `reason` (the app built no actions
  for that edge, which a real app gates on its own settings). The tree is
  the final word either way: `inspect` after the swipe, and a Row flagged
  `expanded` with the drawer's `Button` nodes beside it means it opened.
  A drag with a reason has nothing to retry: another amount or the other
  edge gives the same answer; note it and move on.
  An open menu closes on a tap outside it: the wash behind the card is a
  control labelled `Dismiss menu`, so `tap --label "Dismiss menu"` (or a
  `tap --point` beside the card) closes it without running an item.
  `.searchable` puts a
  `TextField` flagged `search` in the navigation chrome; `type` into it
  runs the app's own filtering.

## What the preview cannot answer

Native rendering fidelity, real gestures and keyboards, camera hardware,
performance, and how the App Store build behaves. When the question changes to
one of those, say so and move to a simulator or device instead of trusting the
preview past its limits. For layout, state, flow, copy, and error states, the
preview is measured against real devices and is the fast path.
