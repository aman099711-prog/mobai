# Writing scenarios

A scenario is one YAML file describing the world outside the app: where the
device is, what it may do, what the camera returns, what the network answers,
who is signed in. The same file works for every engine; an engine that does not
hold a section reports it under `unsupported` instead of failing.

Load one at start (`preview run --scenario <file>`) or swap live
(`POST` semantics: loading replaces the whole world; sections absent from the
new file go back to defaults). A `mobai-dev mock` call patches one capability
and keeps everything else, including the app's own state.

## The sections

```yaml
location:
  lat: 52.2297
  lng: 21.0122
  label: Warsaw            # optional; what location.current().label returns

permissions:               # granted | denied | prompt; unlisted names are prompt
  camera: granted
  notifications: prompt

camera:
  nextImage: fixtures/receipt.png     # what the next capture returns
photos:
  nextImage: fixtures/avatar.png      # what the next library pick returns

network:
  default: passthrough     # or notFound: 404 without leaving the machine
  routes:
    GET /api/profile: fixtures/profile.json      # fixture file as the body
    GET /api/items/*:                            # trailing * matches any suffix
      status: 200
      body: { items: [] }                        # inline body, serialized as JSON
    POST /api/orders:
      status: 500
      body: { error: "upstream is down" }

auth:
  currentUser:             # opaque; whatever the app's code expects
    id: u_42
    name: Ada Lovelace
  # signed out is: currentUser: null   (a bare `auth: null` means "no section")

push:
  next: { title: "Order confirmed", data: { orderId: ord_991 } }

clipboard:
  text: MOBAI-2026

deepLink:
  initial: demo://orders/991     # the URL the app launched with
  next: demo://profile           # the next one to deliver

appearance:
  mode: dark                     # light | dark; the default is light
```

Rules that matter:

- **Fixture paths resolve against the scenario file's directory.** Keep a
  scenario and its fixtures as one movable folder. A missing fixture fails the
  load with `PREVIEW_SCENARIO_INVALID` naming the file.
- **Route keys are `<METHOD> <path>`, matched on the URL path only**, so the
  scenario does not care which host the app calls. Content type of a fixture
  comes from its extension.
- **Every section is optional.** Absent or `null` means the engine default,
  which is permissive or empty, never a failure.
- **Unknown sections are carried, not fatal.** The load response lists them
  under `unsupported`; check it when a mock seems to have no effect.
- **`appearance` is the colour scheme the app renders in**, `{mode: light}` or
  `{mode: dark}`, and the default is light. `preview run --appearance dark`
  applies after the scenario, so the flag wins over the file; `mobai-dev mock
  appearance dark` flips it live, which is how one screen is captured in both
  themes without restarting or driving back to it.

## Two shapes of use

**A deterministic starting world**, for driving a flow the same way every time:

```bash
mobai-dev preview run --detach --scenario scenarios/checkout-success.yaml --json
```

**Failure injection mid-flow**, without losing where you are in the app:

```bash
# drive to the payment screen first, then:
mobai-dev mock network '{"routes":{"POST /api/orders":{"status":500,"body":{"error":"upstream is down"}}}}' --json
mobai-dev preview tap --label "Place order" --json
mobai-dev preview inspect --json     # assert the error state rendered
```

A `network` mutation that carries only `routes` merges them and keeps the
current `default`. `null` as a capability's whole value clears it back to the
default.

## Reading the world back

```bash
mobai-dev preview mock-state --json
```

This reflects consumption: a permission the app resolved from `prompt`, a
notification it consumed, a deep link it took, all show up here. Use it to
assert the app actually exercised the capability, not just rendered.
