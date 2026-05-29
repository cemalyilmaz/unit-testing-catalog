class UnreadCounter {
  int _count = 0;

  int get count => _count;

  void increment() {
    _count++;
  }

  void markAllRead() {
    _count = 0;
  }
}
