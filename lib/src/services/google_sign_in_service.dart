import 'package:google_sign_in/google_sign_in.dart';

// OAuth web client of the Google Cloud project, the audience of the ID token checked by the
// API (GOOGLE_WEB_CLIENT_ID there). Public: it goes inside the app anyway. The iOS client
// is in ios/Runner/Info.plist (GIDClientID), together with this one (GIDServerClientID).
const googleWebClientId = '74850462964-3l2p0t2v5328nrhq65vao4135eripkms.apps.googleusercontent.com';

// Google account picker. Only the ID token goes to the API, which checks it with Google.
class GoogleSignInService {
  GoogleSignInService._();
  static final instance = GoogleSignInService._();

  Future<void>? _initialized;

  Future<void> _init() =>
      _initialized ??= GoogleSignIn.instance.initialize(serverClientId: googleWebClientId);

  // Opens Google's account picker. Null when the user closes it.
  Future<String?> getIdToken() async {
    await _init();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  // Ends the Google session on the device, so the next sign-in asks for an account again.
  // Used on logout and when the account picked can't be used here (not linked, sign-up
  // not finished).
  Future<void> signOut() async {
    try {
      await _init();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Not signed in with Google, or the plugin is unavailable: nothing to clear.
    }
  }
}
