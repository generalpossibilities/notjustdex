import 'dart:convert';
import 'package:flutter/services.dart';
import 'passkey_exception.dart';

/// Cross-platform WebAuthn (passkey) implementation.
///
/// Platform channels:
/// - Android: `com.dexchats.passkey/create` and `/assert`
///   Uses CredentialManager API (Android 14+) or FIDO2
/// - iOS: `com.dexchats.passkey/create` and `/assert`
///   Uses ASAuthorizationController (iOS 15+)
/// - Web: direct `navigator.credentials` via js_interop
class PasskeyService {
  static const _channel = MethodChannel('com.dexchats.passkey');

  /// Check whether the device/platform supports passkeys.
  Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      // Web fallback: check for credentials API
      return _isWebCredentialsSupported();
    }
  }

  /// Create a new passkey credential (WebAuthn registration).
  ///
  /// [userId] - unique user identifier
  /// [userName] - display name for the passkey
  /// [rpId] - relying party ID (e.g. "dexchats.io")
  ///
  /// Returns `PasskeyCredential` with:
  /// - `id` - base64url-encoded credential ID
  /// - `publicKey` - base64url-encoded COSE public key
  /// - `attestation` - base64url-encoded attestation object
  Future<PasskeyCredential> createCredential({
    required String userId,
    required String userName,
    String rpId = 'dexchats.io',
  }) async {
    final challenge = _generateChallenge();

    try {
      final result = await _channel.invokeMethod<Map<String, dynamic>>(
        'createCredential',
        {
          'userId': userId,
          'userName': userName,
          'rpId': rpId,
          'challenge': challenge,
          'timeout': 60000,
        },
      );

      if (result == null) throw PasskeyException.cancelled();

      return PasskeyCredential(
        id: result['id'] as String,
        publicKey: result['publicKey'] as String,
        attestation: result['attestation'] as String?,
      );
    } on MissingPluginException {
      return _webCreateCredential(userId, userName, rpId, challenge);
    }
  }

  /// Authenticate with an existing passkey (WebAuthn assertion).
  ///
  /// [rpId] - relying party ID
  /// [credentialIds] - optional list of allowed credential IDs
  ///
  /// Returns `PasskeyAssertion` with:
  /// - `id` - base64url-encoded credential ID
  /// - `signature` - base64url-encoded signature
  /// - `authenticatorData` - base64url-encoded authenticator data
  /// - `clientDataJSON` - base64url-encoded client data JSON
  /// - `userHandle` - base64url-encoded user handle (optional)
  Future<PasskeyAssertion> getAssertion({
    String rpId = 'dexchats.io',
    List<String>? credentialIds,
  }) async {
    final challenge = _generateChallenge();

    try {
      final result = await _channel.invokeMethod<Map<String, dynamic>>(
        'getAssertion',
        {
          'rpId': rpId,
          'challenge': challenge,
          'allowCredentials': credentialIds ?? [],
          'timeout': 60000,
        },
      );

      if (result == null) throw PasskeyException.cancelled();

      return PasskeyAssertion(
        id: result['id'] as String,
        signature: result['signature'] as String,
        authenticatorData: result['authenticatorData'] as String,
        clientDataJSON: result['clientDataJSON'] as String,
        userHandle: result['userHandle'] as String?,
        signCount: result['signCount'] as int? ?? 0,
      );
    } on MissingPluginException {
      return _webGetAssertion(rpId, challenge, credentialIds);
    }
  }

  // ─── Native Implementation Templates ──────────────────────────

  // Android (Kotlin) — CredentialManager API:
  //
  // class PasskeyPlugin : MethodCallHandler {
  //   override fun onMethodCall(call: MethodCall, result: Result) {
  //     when (call.method) {
  //       "isSupported" -> {
  //         result.success(CredentialManager.isAvailable(context))
  //       }
  //       "createCredential" -> {
  //         val request = createPasskeyRequest(call.arguments)
  //         val credentialManager = CredentialManager.create(context)
  //         lifecycleScope.launch {
  //           val response = credentialManager.createCredential(request)
  //           result.success(mapOf(
  //             "id" to response.credentialId,
  //             "publicKey" to response.publicKey,
  //             "attestation" to response.attestation
  //           ))
  //         }
  //       }
  //       "getAssertion" -> {
  //         val request = createPasskeyAssertionRequest(call.arguments)
  //         lifecycleScope.launch {
  //           val response = credentialManager.getCredential(request)
  //           result.success(mapOf(
  //             "id" to response.credentialId,
  //             "signature" to response.signature,
  //             "authenticatorData" to response.authenticatorData,
  //             "clientDataJSON" to response.clientDataJSON,
  //             "userHandle" to response.userHandle,
  //             "signCount" to response.signCount
  //           ))
  //         }
  //       }
  //     }
  //   }
  //
  //   private fun createPasskeyRequest(args: Map): CreateCredentialRequest {
  //     return CreateCredentialRequest().apply {
  //       // Build WebAuthn creation JSON
  //       // See: developer.android.com/digital-assets/guides/passkeys
  //     }
  //   }
  // }

  // iOS (Swift) — ASAuthorizationController:
  //
  // @objc(PasskeyPlugin) class PasskeyPlugin: NSObject, FlutterPlugin {
  //   func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
  //     switch call.method {
  //     case "isSupported":
  //       result(ASAuthorizationController.authorizationControllerAvailable())
  //     case "createCredential":
  //       let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
  //         relyingPartyIdentifier: args["rpId"])
  //       let request = provider.createCredentialRegistrationRequest(
  //         challenge: challenge,
  //         name: userName,
  //         userID: userId
  //       )
  //       let controller = ASAuthorizationController(authorizationRequests: [request])
  //       controller.delegate = self
  //       controller.performRequests()
  //     case "getAssertion":
  //       let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
  //         relyingPartyIdentifier: args["rpId"])
  //       let request = provider.createCredentialAssertionRequest(
  //         challenge: challenge
  //       )
  //       if let ids = args["allowCredentials"] as? [String] {
  //         request.allowedCredentials = ids.map { Data(base64url: $0) }
  //       }
  //       let controller = ASAuthorizationController(authorizationRequests: [request])
  //       controller.delegate = self
  //       controller.performRequests()
  //     }
  //   }
  // }

  // ─── Web Fallback ─────────────────────────────────────────────

  bool _isWebCredentialsSupported() {
    // In real web implementation, checked via:
    //   js_interop: `navigator.credentials != null`
    //   AND `PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable()`
    return false;
  }

  Future<PasskeyCredential> _webCreateCredential(
    String userId,
    String userName,
    String rpId,
    String challenge,
  ) {
    // Web implementation using dart:js_interop:
    //
    //   final cred = await navigator.credentials.create(CredentialCreationOptions(
    //     publicKey: PublicKeyCredentialCreationOptions(
    //       challenge: challenge,
    //       rp: { name: 'DexChats', id: rpId },
    //       user: { id: userId, name: userName, displayName: userName },
    //       pubKeyCredParams: [
    //         { type: 'public-key', alg: -7 },   // ES256
    //         { type: 'public-key', alg: -257 }, // RS256
    //       ],
    //       authenticatorSelection: {
    //         residentKey: 'required',
    //         userVerification: 'required',
    //       },
    //       timeout: 60000,
    //     ),
    //   ));
    //
    throw PasskeyException.notSupported();
  }

  Future<PasskeyAssertion> _webGetAssertion(
    String rpId,
    String challenge,
    List<String>? credentialIds,
  ) {
    throw PasskeyException.notSupported();
  }

  String _generateChallenge() {
    final bytes = List<int>.generate(32, (_) => DateTime.now().microsecondsSinceEpoch % 256);
    return base64Url.encode(bytes);
  }
}

/// Result of WebAuthn credential creation (passkey registration).
class PasskeyCredential {
  final String id;
  final String publicKey;
  final String? attestation;

  const PasskeyCredential({
    required this.id,
    required this.publicKey,
    this.attestation,
  });
}

/// Result of WebAuthn assertion (passkey authentication).
class PasskeyAssertion {
  final String id;
  final String signature;
  final String authenticatorData;
  final String clientDataJSON;
  final String? userHandle;
  final int signCount;

  const PasskeyAssertion({
    required this.id,
    required this.signature,
    required this.authenticatorData,
    required this.clientDataJSON,
    this.userHandle,
    this.signCount = 0,
  });
}
