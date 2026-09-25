# Helper: Exception Types vs Error Messages

---

## They Look Similar

Both E2 and E3 assert on the exception a method throws. Both use `throwsA`. Why are they different entries — and why two tests instead of one `throwsA(isA<T>().having(...))`?

---

## Exception Types (E2)

The type is the **machine-readable** signal. It answers: "Which failure is this, so that code can branch on it?"

- A `catch (InvalidMessageError)` block shows an inline validation hint.
- A `catch (MessageLimitReachedError)` block disables the send button until the limit resets.
- A `switch` over a sealed error hierarchy is checked for exhaustiveness by the compiler.

The type is part of the contract between the method and every caller that handles its failures. It changes rarely, and when it does, callers must change with it.

---

## Error Messages (E3)

The message is the **human-readable** signal. It answers: "What does a person — user, support engineer, developer reading a log — see?"

- Product copy is revised ("Message cannot be empty." → "Type something first.").
- Localization replaces the string per locale.
- Logging formats add context ("… in conversation conv-1").

No caller branches on the message. It changes often, and when it does, no handling logic should need to change.

---

## Why Two Tests

| Concern | E2 Exception Types | E3 Error Messages |
|---|---|---|
| Who consumes it | Code (`catch`, `switch`) | People (UI, logs) |
| Rate of change | Rare | Frequent |
| Typical regression | Two cases collapse into one type | Wrong or stale copy |
| Failure should tell you | "Callers can no longer distinguish these failures" | "The user will read the wrong thing" |

A single combined assertion — `isA<InvalidMessageError>().having((e) => e.message, 'message', equals('…'))` — fails for either reason and reports both as one. When a copy change breaks it, the failure looks like a type regression; when a type collapse breaks it, the failure looks like a copy problem. Splitting them keeps each failure honest about its cause, and lets the E3 test be swapped for a message-key assertion under localization without touching the E2 contract.

---

## The Takeaway

Test the type because code depends on it. Test the message because people depend on it. Keep them separate because they change for different reasons, at different rates, and their failures mean different things.
