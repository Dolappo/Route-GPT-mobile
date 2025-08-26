// ignore_for_file: constant_identifier_names

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String CCDETAILS = 'cardDetails';
  static const String _firstTimeLaunchStatusKey = "FirstTimeLaunchStatus";
  static const String _PHONEKEY = 'PhoneNumber';
  static const String _emailKEY = 'EmailAddress';
  static const String _nameKEY = 'UserName';
  static const String CCPIN = "WalletPin";
  static const String locPermission = "LocationPermission";
  static const String contactPermission = "ContactPermission";
  static const String rememberMe = "RememberMe";
  static const String _passwordKey = "PasswordKey";
  final secureStorage = const FlutterSecureStorage();

  LocalStorage() {}

  Future<void> storeValue(String key, dynamic value) async {
    await secureStorage.write(key: key, value: value);
  }

  Future<dynamic> readValue(String key, {dynamic defaultValue}) async {
    return (await secureStorage.read(key: key)) ?? defaultValue;
  }

  Future<void> persistUserPhoneNumber(String phoneNumber) async {
    await secureStorage.write(key: _PHONEKEY, value: phoneNumber);
  }

  Future<String?> getUserPhoneNumber() async {
    return await secureStorage.read(key: _PHONEKEY);
  }

  Future<void> persistUserEmail(String email) async {
    await secureStorage.write(key: _emailKEY, value: email);
  }

  Future<void> persistUserPassword(String password) async {
    await secureStorage.write(key: _passwordKey, value: password);
  }

  Future<String?> getUserEmail() async {
    return await secureStorage.read(key: _emailKEY);
  }

  Future<String?> getCachedPassword() async {
    return await secureStorage.read(key: _passwordKey);
  }

  void persistUserName(String firstName) async {
    await secureStorage.write(key: _nameKEY, value: firstName);
  }

  Future<String?> getUserName() async {
    return await secureStorage.read(key: _nameKEY);
  }

  Future<void> persistLocPermStatus(bool accepted) async {
    await secureStorage.write(key: locPermission, value: accepted.toString());
  }

  Future<void> persistContactsPermStatus(bool accepted) async {
    await secureStorage.write(
        key: contactPermission, value: accepted.toString());
  }

  Future<bool> getContactPermStatus() async {
    final bool pin =
        (await secureStorage.read(key: contactPermission)) == true.toString();

    return pin;
  }

  Future<bool> getLocationPermStatus() async {
    final bool pin =
        (await secureStorage.read(key: locPermission)) == true.toString();

    return pin;
  }

  Future<bool> getFirstTimeLaunchStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_firstTimeLaunchStatusKey) ?? true) {
      await secureStorage.deleteAll();

      prefs.setBool(_firstTimeLaunchStatusKey, false);
      return true;
    }

    return false;
  }

  Future<void> saveRememberMe(bool value) async {
    await secureStorage.write(key: rememberMe, value: value.toString());
  }

  Future<bool> getRememberMe() async {
    final bool remember =
        (await secureStorage.read(key: rememberMe)) == true.toString();

    return remember;
  }
}
