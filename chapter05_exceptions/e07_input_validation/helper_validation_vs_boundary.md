# Helper: Input Validation vs Boundary Conditions

---

## They Look Similar

Both E7 and E8 involve testing error conditions. Both involve inputs that should be rejected. Why are they different entries?

---

## Input Validation (E7)

Input validation is about the **nature** of the data. It answers: "Is this data the right *kind* of thing?"

- Does the file have an accepted extension?
- Is the username made of alphanumeric characters only?
- Is the date within a reasonable range (not 500 years in the future)?

The focus is on the *content and type* of a single piece of data. Validation fires early — at the point of data entry — and is about preventing bad data from entering the system at all.

**Examples:**
- Rejecting a `.exe` file (wrong type, regardless of size)
- Rejecting a username containing a space (wrong format)
- Rejecting a date in the year 2525 (logically implausible)

---

## Boundary Conditions (E8)

Boundary conditions are about the **limits** of the system. They answer: "Does the system behave correctly when pushed to the *edges* of what it allows?"

- What happens at exactly 100 messages (the rate limit)?
- What happens at exactly 10 MB (the file size limit)?
- What happens at 0, at -1, at `maxInt`?

The focus is on the *threshold values* where behavior changes. The data itself may be perfectly valid in type — a 10 MB + 1 byte file is a perfectly valid file, it is just too large for this system.

**Examples:**
- A file at exactly 10 MB is accepted; a file at 10 MB + 1 byte is rejected
- The 100th message is sent; the 101st is rejected
- A list with 0 elements is handled without a crash

---

## Why the Distinction Matters in Tests

| Concern | E7 Input Validation | E8 Boundary Conditions |
|---|---|---|
| What is tested | The category of the data | The size or quantity limit |
| Typical failure | Wrong type, wrong format | At exactly N, at N+1, at 0 |
| Test granularity | Per invalid category | Per threshold value (at, below, above) |
| Context | Data entry point | System limits throughout processing |

---

## The Takeaway

Validation stops bad data from getting in. Boundary testing ensures the system handles the edges of what it allows gracefully. A comprehensive test suite needs both.
