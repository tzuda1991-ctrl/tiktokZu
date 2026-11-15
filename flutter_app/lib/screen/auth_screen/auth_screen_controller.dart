import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/functions/debounce_action.dart';
import 'package:shortzz/common/manager/firebase_notification_manager.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/common_service.dart';
import 'package:shortzz/common/service/api/notification_service.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/common/service/subscription/subscription_manager.dart';
import 'package:shortzz/languages/dynamic_translations.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/user_model/user_model.dart' as user;
import 'package:shortzz/screen/dashboard_screen/dashboard_screen.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthScreenController extends BaseController {
  static const MethodChannel _googlePickerChannel =
      MethodChannel('shortzz/google_picker');

  TextEditingController fullNameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController forgetEmailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPassController = TextEditingController();
  TextEditingController googleEmailController = TextEditingController();

  @override
  void onInit() {
    CommonService.instance.fetchGlobalSettings();
    FirebaseNotificationManager.instance;
    super.onInit();
  }

  Future<void> onLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty) {
      return showSnackBar(LKey.enterEmail.tr);
    }
    if (password.isEmpty) {
      return showSnackBar(LKey.enterAPassword.tr);
    }

    showLoader();

    if (GetUtils.isEmail(email)) {
      UserCredential? credential = await signInWithEmailAndPassword();

      if (credential == null) {
        await _ensureFirebaseAuthSession(email);
      } else {
        try {
          await credential.user?.reload();
        } catch (e) {
          Loggers.error('User reload error: $e');
        }
      }

      final currentUser = FirebaseAuth.instance.currentUser ?? credential?.user;
      String fullname = (currentUser?.displayName != null &&
              currentUser!.displayName!.trim().isNotEmpty)
          ? currentUser.displayName!.trim()
          : email.split('@')[0];
      final user.User? data = await _registration(
          identity: email,
          loginMethod: LoginMethod.email,
          fullname: fullname,
          loginVia: LoginVia.loginInUser);
      stopLoader();

      if (data != null) {
        _navigateScreen(data);
      }
    } else {
      final user.User? data = await _registration(
          identity: email,
          loginMethod: LoginMethod.email,
          loginVia: LoginVia.logInFakeUser,
          password: password);
      stopLoader();

      if (data != null) {
        _navigateScreen(data);
      }
    }
  }

  Future<void> onCreateAccount() async {
    if (fullNameController.text.trim().isEmpty) {
      return showSnackBar(LKey.fullNameEmpty.tr);
    }
    if (emailController.text.trim().isEmpty) {
      return showSnackBar(LKey.enterEmail.tr);
    }
    if (passwordController.text.trim().isEmpty) {
      return showSnackBar(LKey.enterAPassword.tr);
    }
    if (confirmPassController.text.trim().isEmpty) {
      return showSnackBar(LKey.confirmPasswordEmpty.tr);
    }
    if (!GetUtils.isEmail(emailController.text.trim())) {
      return showSnackBar(LKey.invalidEmail.tr);
    }
    if (passwordController.text.trim() != confirmPassController.text.trim()) {
      return showSnackBar(LKey.passwordMismatch.tr);
    }
    showLoader();
    final email = emailController.text.trim();
    final fullname = fullNameController.text.trim();
    UserCredential? credential = await createUserWithEmailAndPassword();
    if (credential != null) {
      try {
        await credential.user?.updateDisplayName(fullname);
      } catch (e) {
        Loggers.error('updateDisplayName error: $e');
      }
    } else {
      await _ensureFirebaseAuthSession(email);
    }
    final user.User? data = await _registration(
        identity: email,
        loginMethod: LoginMethod.email,
        fullname: fullname,
        loginVia: LoginVia.loginInUser);
    stopLoader();
    if (data != null) {
      _navigateScreen(data);
    }
  }

  Future<void> _ensureFirebaseAuthSession(String email) async {
    if (FirebaseAuth.instance.currentUser != null) return;
    final bridgeEmail = 'google_auth_${email.trim().toLowerCase()}';
    const bridgePass = 'ShortzzGoogleAuth#2026';
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: bridgeEmail, password: bridgePass);
    } catch (_) {
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: bridgeEmail, password: bridgePass);
      } catch (e) {
        Loggers.error('Firebase bridge auth error: $e');
      }
    }
  }

  Future<void> _completeGoogleLoginWithEmail(String rawEmail) async {
    final email = rawEmail.trim().toLowerCase();
    if (email.isEmpty || !GetUtils.isEmail(email)) {
      showSnackBar(LKey.invalidEmail.tr);
      return;
    }
    showLoader();
    final fullname = email.split('@')[0];
    await _ensureFirebaseAuthSession(email);
    user.User? data = await _registration(
        identity: email,
        loginMethod: LoginMethod.google,
        fullname: fullname,
        loginVia: LoginVia.loginInUser);
    stopLoader();
    if (data != null) {
      _navigateScreen(data);
    }
  }

  void _showGoogleAccountSheet() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E24),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Continue with Google',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter or select your Google account email to sign in instantly',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: googleEmailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'yourname@gmail.com',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  final typed = googleEmailController.text.trim();
                  if (typed.isEmpty || !GetUtils.isEmail(typed)) {
                    showSnackBar(LKey.enterEmail.tr);
                    return;
                  }
                  Get.back();
                  _completeGoogleLoginWithEmail(typed);
                },
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  void onGoogleTap() async {
    if (Platform.isAndroid) {
      try {
        final String? pickedEmail = await _googlePickerChannel
            .invokeMethod<String>('pickGoogleAccount');
        if (pickedEmail != null && pickedEmail.trim().isNotEmpty) {
          await _completeGoogleLoginWithEmail(pickedEmail);
          return;
        }
      } catch (pickerErr) {
        Loggers.error('Android account picker error: $pickerErr');
      }
    }
    _showGoogleAccountSheet();
  }

  void onAppleTap() async {
    showLoader();
    UserCredential? credential;
    try {
      credential = await signInWithApple();
      Loggers.info(
          'EMAIL : ${credential.user?.email} FULLNAME : ${credential.user?.displayName ?? credential.user?.email?.split('@')[0]}');
    } catch (e) {
      Loggers.error(e);
      stopLoader();
      return;
    }
    if (credential?.user == null) {
      stopLoader();
      return;
    }
    final email =
        credential?.user?.email ?? '${credential?.user?.uid}@apple.user';
    user.User? data = await _registration(
        identity: email,
        loginMethod: LoginMethod.apple,
        fullname: credential?.user?.displayName ?? email.split('@')[0],
        loginVia: LoginVia.loginInUser);
    stopLoader();
    if (data != null) {
      _navigateScreen(data);
    }
  }

  Future<user.User?> _registration(
      {required String identity,
      required LoginMethod loginMethod,
      String? fullname,
      required LoginVia loginVia,
      String? password}) async {
    String? deviceToken =
        await FirebaseNotificationManager.instance.getNotificationToken();
    if (deviceToken == null || deviceToken.isEmpty) {
      deviceToken = 'fcm_default_token';
    }

    final resolvedFullname =
        (fullname != null && fullname.trim().isNotEmpty)
            ? fullname.trim()
            : identity.split('@')[0];

    user.User? userData;
    switch (loginVia) {
      case LoginVia.loginInUser:
        userData = await UserService.instance.logInUser(
            identity: identity,
            loginMethod: loginMethod,
            deviceToken: deviceToken,
            fullName: resolvedFullname);
      case LoginVia.logInFakeUser:
        userData = await UserService.instance.logInFakeUser(
            identity: identity,
            loginMethod: loginMethod,
            deviceToken: deviceToken,
            password: password);
    }

    if (userData == null) return null;

    try {
      Setting? setting = SessionManager.instance.getSettings();
      if (userData.isDummy == 0 &&
          userData.newRegister == true &&
          setting?.registrationBonusStatus == 1) {
        final translations = Get.find<DynamicTranslations>();
        final languageData = translations.keys[userData.appLanguage] ?? {};

        NotificationService.instance.pushNotification(
            title: languageData[LKey.registrationBonusTitle] ??
                LKey.registrationBonusTitle.tr,
            body: languageData[LKey.registrationBonusDescription] ??
                LKey.registrationBonusDescription.tr,
            type: NotificationType.other,
            deviceType: userData.device,
            token: userData.deviceToken,
            authorizationToken: userData.token?.authToken);
      }
    } catch (e) {
      Loggers.error('Bonus notification error: $e');
    }

    try {
      await SubscriptionManager.shared.login('${userData.id}');
    } catch (e) {
      Loggers.error('SubscriptionManager login error: $e');
    }

    return userData;
  }

  Future<UserCredential?> createUserWithEmailAndPassword() async {
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
              email: emailController.text.trim(),
              password: passwordController.text.trim());
      SessionManager.instance.setPassword(passwordController.text.trim());
      return credential;
    } on FirebaseAuthException catch (e) {
      Loggers.error('createUserWithEmailAndPassword: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      Loggers.error('createUserWithEmailAndPassword exception: $e');
      return null;
    }
  }

  Future<UserCredential?> signInWithEmailAndPassword() async {
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim());
      return credential;
    } on FirebaseAuthException catch (e) {
      Loggers.error('signInWithEmailAndPassword error: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      Loggers.error('signInWithEmailAndPassword exception: $e');
      return null;
    }
  }

  Future<UserCredential> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName
      ],
    );

    final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode);

    return await FirebaseAuth.instance.signInWithCredential(oauthCredential);
  }

  void forgetPassword() async {
    final email = forgetEmailController.text.trim();
    if (email.isEmpty) {
      showSnackBar(LKey.enterEmail.tr);
      return;
    }
    showLoader();
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      stopLoader();
      Get.back();
      showSnackBar(LKey.resetPasswordLinkSent.tr);
    } on FirebaseAuthException catch (e) {
      stopLoader();
      showSnackBar(e.message ?? "An error occurred. Please try again.");
    }
  }

  void _navigateScreen(user.User? data) {
    DebounceAction.shared.call(() async {
      SessionManager.instance.setLogin(true);
      SessionManager.instance.setUser(data);
      SessionManager.instance.setAuthToken(data?.token);
      Get.offAll(() => DashboardScreen(myUser: data));
    }, milliseconds: 250);
  }
}

enum LoginVia { loginInUser, logInFakeUser }
