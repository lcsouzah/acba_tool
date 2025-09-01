import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class InMemorySecureStorage extends FlutterSecureStorage {
  final Map<String, String> _store = {};

  InMemorySecureStorage() : super();

  @override
  Future<void> write({
    required String key,
    String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? wOptions,
    MacOsOptions? mOptions,
    WindowsOptions? windowsOptions,
  }) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? wOptions,
    MacOsOptions? mOptions,
    WindowsOptions? windowsOptions,
  }) async {
    return _store[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? wOptions,
    MacOsOptions? mOptions,
    WindowsOptions? windowsOptions,
  }) async {
    _store.remove(key);
  }
}
