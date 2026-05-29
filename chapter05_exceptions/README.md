# Chapter 5: Exceptions & Error Handling

---

## Overview

Error handling is not an afterthought — it is half the contract. A method promises to do something when inputs are valid; it also promises to behave predictably when they are not. The nine entries in this chapter catalog every distinct aspect of that second promise.

---

## What Needs to Be Tested

Each entry in this chapter targets one specific concern:


| Entry                                                             | Tests that…                                                   |
| ----------------------------------------------------------------- | ------------------------------------------------------------- |
| [E1 — Exception Throwing](e01_exception_throwing/README.md)       | The method throws an exception under invalid conditions       |
| [E2 — Exception Types](e02_exception_types/README.md)             | The correct *type* of exception is thrown                     |
| [E3 — Error Messages](e03_error_messages/README.md)               | The exception carries a meaningful, accurate message          |
| [E4 — Exception Handling](e04_exception_handling/README.md)       | The calling code catches the exception and responds correctly |
| [E5 — State After Exception](e05_state_after_exception/README.md) | The object is in a consistent state after an exception        |
| [E6 — Fallback Mechanisms](e06_fallback_mechanisms/README.md)     | A fallback path is taken when the primary path fails          |
| [E7 — Input Validation](e07_input_validation/README.md)           | Invalid inputs are rejected before reaching business logic    |
| [E8 — Boundary Conditions](e08_boundary_conditions/README.md)     | The system behaves correctly at the edges of allowed values   |
| [E9 — Resource Cleanup](e09_resource_cleanup/README.md)           | Resources are released even when an exception occurs          |


---

## Purpose

Robust error handling is what separates a stable application from one that crashes or silently corrupts data. In Flutter, errors can come from user input, network failures, file system limits, and device constraints. Each of the nine test categories above addresses a distinct failure mode.

---

## Relevance

Mobile applications run in uncontrolled environments. Network connectivity is unreliable. Users provide unexpected inputs. Storage fills up. Without tested error handling, any of these common conditions can cause a crash or a corrupted state that the user experiences but the developer never anticipated.

---

## The Running Example

All nine entries use a `ChatManager` class as their example. Across the sub-chapters the `ChatManager` rejects empty messages (E1), enforces rate limits (E2), produces structured error messages (E3), is wrapped by callers that handle its exceptions (E4), preserves consistent state when it throws (E5), falls back to local delivery when the network fails (E6), validates inputs (E7), enforces boundary conditions on attachments (E8), and releases resources after an exception (E9). One class surface, nine error-handling scenarios.

---

## Navigation

- Previous: [Chapter 4 — Side Effects](../chapter04_side_effects/README.md)
- Next: [E1 — Exception Throwing](e01_exception_throwing/README.md)
- Back: [Catalog Index](../README.md)

