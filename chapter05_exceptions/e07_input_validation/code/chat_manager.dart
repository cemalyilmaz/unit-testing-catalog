class InvalidFileError implements Exception {
  final String message;
  InvalidFileError(this.message);
}

class UnsupportedFileTypeError extends InvalidFileError {
  UnsupportedFileTypeError() : super('Unsupported file type.');
}

class FileTooLargeError extends InvalidFileError {
  FileTooLargeError() : super('File exceeds maximum size of 10 MB.');
}

class ChatManager {
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const List<String> allowedExtensions = ['jpg', 'png', 'pdf'];

  void uploadFile(String fileName, List<int> fileData) {
    final extension = fileName.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(extension)) {
      throw UnsupportedFileTypeError();
    }
    if (fileData.length > maxFileSizeBytes) {
      throw FileTooLargeError();
    }
    // upload logic goes here
  }
}
