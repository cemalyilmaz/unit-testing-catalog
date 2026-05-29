# Chapter 11: Third-Party Integration

> In the chat app, this is the seam between the backend SDK and the rest of the code. The HTTP client (whatever brand it happens to be this quarter) lives behind a `NetworkService` interface so the business logic never imports it directly — and the tests never need a real server.

---

## Intent

Verify that your business logic handles every outcome a third-party library can produce, without the library being present in tests.

---

## The Problem

`ChatService` sends messages over HTTP using `dio`. It works in production. But when you try to write a unit test, you discover that `dio` makes real network requests, requires a running server, and cannot be configured to return a 503 without standing up infrastructure. The test suite becomes slow, fragile, and dependent on external systems.

A developer upgrades `dio` from v4 to v5. The API changes slightly. Now every test that imports `dio` directly breaks — not because your code is wrong, but because you were testing the library's API instead of your own.

Third-party code is a black box you do not own. Testing against it directly couples your tests to its version history, its network requirements, and its failure modes — all of which are outside your control.

---

## Forces

You want to test your business logic's response to every outcome a library can produce — success, 404, timeout, auth failure — but calling the real library makes tests slow, unreliable, and unable to produce these edge cases on demand.

You want tests that survive library upgrades — but if you mock the library's own types directly, every test breaks when the library changes its API. The tension resolves when you introduce your own abstract interface between your code and the library. Your tests only know about your interface. The library can be swapped or upgraded without touching a single test.

---

## Solution

Introduce a `NetworkService` abstract class that your business logic depends on. In production, provide a concrete adapter that wraps the real library. In tests, use a stub or mock of your own interface.

Production code:

```dart
// See code/chat_service.dart
abstract class NetworkService {
  Future<Map<String, dynamic>> get(String path);
  Future<void> post(String path, Map<String, dynamic> body);
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
}

class Message {
  final String id;
  final String text;
  final String senderId;

  const Message({required this.id, required this.text, required this.senderId});

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      text: json['text'] as String,
      senderId: json['senderId'] as String,
    );
  }
}

class ChatService {
  final NetworkService _network;

  ChatService({required NetworkService network}) : _network = network;

  Future<List<Message>> fetchMessages() async {
    final response = await _network.get('/messages');
    final items = response['messages'] as List<dynamic>;
    return items
        .map((item) => Message.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> sendMessage(String text) async {
    await _network.post('/messages', {'text': text});
  }
}
```

Test code:

```dart
// See code/chat_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'chat_service.dart';

// Stub: returns predefined data — nothing is asserted on this double.
class StubNetworkService implements NetworkService {
  Map<String, dynamic>? _response;
  Exception? _error;

  void willReturn(Map<String, dynamic> response) => _response = response;
  void willThrow(Exception error) => _error = error;

  @override
  Future<Map<String, dynamic>> get(String path) async {
    if (_error != null) throw _error!;
    return _response ?? {};
  }

  @override
  Future<void> post(String path, Map<String, dynamic> body) async {}
}

// Mock: records what it was called with — the test asserts on this double.
class MockNetworkService implements NetworkService {
  String? lastPostPath;
  Map<String, dynamic>? lastPostBody;

  @override
  Future<Map<String, dynamic>> get(String path) async => {};

  @override
  Future<void> post(String path, Map<String, dynamic> body) async {
    lastPostPath = path;
    lastPostBody = body;
  }
}

void main() {
  group('ChatService.fetchMessages', () {
    late StubNetworkService stubNetwork;
    late ChatService service;

    setUp(() {
      stubNetwork = StubNetworkService();
      service = ChatService(network: stubNetwork);
    });

    test('returns a parsed list of messages when network succeeds', () async {
      stubNetwork.willReturn({
        'messages': [
          {'id': '1', 'text': 'Hello', 'senderId': 'user1'},
          {'id': '2', 'text': 'World', 'senderId': 'user2'},
        ]
      });

      final messages = await service.fetchMessages();

      expect(messages.length, equals(2));
      expect(messages.first.text, equals('Hello'));
      expect(messages.last.senderId, equals('user2'));
    });

    test('returns an empty list when the network returns no messages', () async {
      stubNetwork.willReturn({'messages': []});

      final messages = await service.fetchMessages();

      expect(messages, isEmpty);
    });

    test('propagates NetworkException when network fails', () async {
      stubNetwork.willThrow(NetworkException('503 Service Unavailable'));

      expect(
        () => service.fetchMessages(),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('ChatService.sendMessage', () {
    late MockNetworkService mockNetwork;
    late ChatService service;

    setUp(() {
      mockNetwork = MockNetworkService();
      service = ChatService(network: mockNetwork);
    });

    test('posts to the correct path', () async {
      await service.sendMessage('Hello');

      expect(mockNetwork.lastPostPath, equals('/messages'));
    });

    test('includes the message text in the request body', () async {
      await service.sendMessage('Hello');

      expect(mockNetwork.lastPostBody?['text'], equals('Hello'));
    });
  });
}
```

The production code never imports `dio`, `http`, or any other library. The real `DioAdapter implements NetworkService` is a thin wrapper written once. All business logic tests use the stub and mock above.

---

## Consequences

**Gains**
- Tests are fast, deterministic, and run offline. No server required.
- Upgrading the third-party library only affects the adapter class — zero test changes needed.
- Every error response the library can produce (404, 503, timeout) is testable by configuring the stub.

**Trade-offs**
- Writing the adapter is an extra step. For simple, stable libraries, the overhead may not be justified.
- The adapter must be tested too, but at the integration level — not unit level. Integration tests verify that the adapter correctly wraps the library.

---

## Implementation Notes

- Name the interface after what it does in your domain (`NetworkService`, `AnalyticsService`, `StorageService`), not after the library it wraps. `DioService` is a naming trap — it exposes the implementation in the contract.
- Keep the interface narrow. If `ChatService` only ever calls `get` and `post`, the interface only needs those two methods. A large interface is harder to stub and reveals more of the library's shape than necessary.
- The stub uses two separate doubles (`StubNetworkService` for `fetchMessages`, `MockNetworkService` for `sendMessage`) because their assertions are different in nature. See the [Glossary](../glossary/README.md) for the stub/mock distinction.

---

## Related Patterns

- [Chapter 3 — Sending Out More Messages](../chapter03_sending_out_more_messages/README.md): The foundational mock pattern this chapter builds on.
- [Chapter 4 — Side Effects](../chapter04_side_effects/README.md): When `sendMessage` has multiple outgoing calls, test each independently.
- [E6 — Fallback Mechanisms](../chapter05_exceptions/e06_fallback_mechanisms/README.md): What `ChatService` should do when the network fails.

---

## Navigation

- Previous: [Chapter 10 — Memory and Resource Management](../chapter10_memory_and_resources/README.md)
- Next: [Chapter 12 — Fallbacks and Redundancies](../chapter12_fallbacks_and_redundancies/README.md)
- Back: [Catalog Index](../README.md)
