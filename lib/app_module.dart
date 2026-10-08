import 'package:app_hiker/src/pages/app/app_shell.dart';
import 'package:app_hiker/src/pages/app/edit_profile_screen.dart';
import 'package:app_hiker/src/pages/app/local_screen.dart';
import 'package:app_hiker/src/pages/app/trilhas/trilha_detail_screen.dart';
import 'package:app_hiker/src/pages/app/user_profile_screen.dart';
import 'package:app_hiker/src/pages/auth/auth_gate_screen.dart';
import 'package:app_hiker/src/pages/auth/forgot_password_screen.dart';
import 'package:app_hiker/src/pages/auth/login_screen.dart';
import 'package:app_hiker/src/pages/auth/register_screen.dart';
import 'package:flutter_modular/flutter_modular.dart';

class AppModule extends Module {
  @override
  void register(ModularContext c) {
    c.route('/', child: (context, state) => const AuthGateScreen());
    c.route('/login', child: (context, state) => const LoginScreen());
    c.route('/forgot-password', child: (context, state) => ForgotPasswordScreen(initialEmail: state.arguments as String?));
    c.route('/register', child: (context, state) => const RegisterScreen());
    c.route('/app', child: (context, state) => const AppShell());
    c.route('/edit-profile', child: (context, state) => const EditProfileScreen());
    // nick without the leading "@", which the API stores as part of the nick.
    c.route('/local/:placeId', child: (context, state) => LocalScreen(placeId: state.params['placeId']!));
    c.route('/trilha/:id', child: (context, state) => TrilhaDetailScreen(id: int.parse(state.params['id']!)));
    c.route('/user/:nick', child: (context, state) => UserProfileScreen(nick: '@${state.params['nick']}'));
  }
}
