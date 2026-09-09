import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiKeyService {
  ApiKeyService({
    FlutterSecureStorage? storage,
    http.Client? client,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _client = client ?? http.Client();

  static const _storageKey = 'openai_api_key';

  final FlutterSecureStorage _storage;
  final http.Client _client;

  String sanitize(String value) {
    return value.replaceAll(RegExp(r'\s+'), '');
  }

  Future<String?> read() async {
    final stored = sanitize(await _storage.read(key: _storageKey) ?? '');
    if (stored.isNotEmpty) return stored;

    final environment = sanitize(Platform.environment['OPENAI_API_KEY'] ?? '');
    if (environment.isNotEmpty) return environment;

    return null;
  }

  Future<bool> hasStoredKey() async {
    final stored = sanitize(await _storage.read(key: _storageKey) ?? '');
    return stored.isNotEmpty;
  }

  Future<void> save(String value) async {
    final key = sanitize(value);
    if (key.isEmpty) {
      throw const FormatException('Bitte einen API-Key eingeben.');
    }
    if (!key.startsWith('sk-')) {
      throw const FormatException(
        'Der API-Key sieht nicht gültig aus. OpenAI-Keys beginnen normalerweise mit sk-.',
      );
    }
    await _storage.write(key: _storageKey, value: key);
  }

  Future<void> delete() async {
    await _storage.delete(key: _storageKey);
  }

  Future<ApiKeyTestResult> test([String? candidate]) async {
    final key = candidate == null ? await read() : sanitize(candidate);
    if (key == null || key.isEmpty) {
      return const ApiKeyTestResult(
        ok: false,
        message: 'Kein API-Key gespeichert.',
      );
    }

    if (!key.startsWith('sk-')) {
      return const ApiKeyTestResult(
        ok: false,
        message: 'Der API-Key sieht nicht gültig aus.',
      );
    }

    try {
      final response = await _client.get(
        Uri.parse('https://api.openai.com/v1/models/gpt-5.6-terra'),
        headers: {'Authorization': 'Bearer $key'},
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const ApiKeyTestResult(
          ok: true,
          message: 'API-Key ist gültig und OpenAI ist erreichbar.',
        );
      }

      switch (response.statusCode) {
        case 401:
          return const ApiKeyTestResult(
            ok: false,
            message: 'API-Key ungültig oder widerrufen.',
          );
        case 403:
          return const ApiKeyTestResult(
            ok: false,
            message: 'API-Zugriff wurde für diesen Key nicht erlaubt.',
          );
        case 429:
          return const ApiKeyTestResult(
            ok: false,
            message: 'OpenAI meldet ein Limit- oder Guthabenproblem.',
          );
        default:
          return ApiKeyTestResult(
            ok: false,
            message: 'OpenAI antwortet mit HTTP ${response.statusCode}.',
          );
      }
    } on SocketException {
      return const ApiKeyTestResult(
        ok: false,
        message: 'Keine Internetverbindung zu OpenAI.',
      );
    } catch (error) {
      return ApiKeyTestResult(
        ok: false,
        message: 'Verbindungstest fehlgeschlagen: $error',
      );
    }
  }
}

class ApiKeyTestResult {
  const ApiKeyTestResult({required this.ok, required this.message});

  final bool ok;
  final String message;
}
