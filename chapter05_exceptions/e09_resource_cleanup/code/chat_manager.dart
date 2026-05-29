abstract class FileHandle {
  List<int> readData();
  void close();
}

class FileSendFailedError implements Exception {}

class ChatManager {
  Future<void> sendFile(FileHandle fileHandle) async {
    try {
      final data = fileHandle.readData();
      if (data.isEmpty) {
        throw FileSendFailedError();
      }
      // send logic goes here
    } finally {
      fileHandle.close();
    }
  }
}
