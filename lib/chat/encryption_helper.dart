import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as encrypt;

/// ⚠️ In production, move this secret to secure storage / keystore.
const String _APP_PEPPER = 'freelenia-prod-chat-pepper-CHANGE-ME';

class EncryptionHelper {
  late final encrypt.Encrypter _encrypter;

  EncryptionHelper(String chatId) {
    // Derive a per-chat AES key from chatId + pepper
    final keyBytes =
        crypto.sha256.convert(utf8.encode('$_APP_PEPPER|$chatId')).bytes;
    final key = encrypt.Key(Uint8List.fromList(keyBytes));
    _encrypter = encrypt.Encrypter(encrypt.AES(key));
  }

  /// Encrypts a plaintext string using AES with random IV
  String encryptText(String plain) {
    final iv = encrypt.IV.fromSecureRandom(16);
    final enc = _encrypter.encrypt(plain, iv: iv);
    return jsonEncode({'iv': iv.base64, 'data': enc.base64});
  }

  /// Decrypts ciphertext JSON back into plaintext
  String decryptText(String cipherJson) {
    try {
      final decoded = jsonDecode(cipherJson);
      final iv = encrypt.IV.fromBase64(decoded['iv']);
      return _encrypter.decrypt64(decoded['data'], iv: iv);
    } catch (_) {
      return "⚠️ [Unable to decrypt]";
    }
  }
}
