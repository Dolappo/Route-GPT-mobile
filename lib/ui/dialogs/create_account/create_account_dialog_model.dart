import 'package:firebase_auth/firebase_auth.dart';
import 'package:route_gpt/app/app.locator.dart';
import 'package:route_gpt/services/auth_service.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class CreateAccountDialogModel extends BaseViewModel {
  final _auth = locator<AuthService>();
  final _dialogService = locator<DialogService>();

  void signUpWithGoogle() async {
    UserCredential? res = await _auth.signInWithGoogle();
    if (res != null) {
      _dialogService.completeDialog(DialogResponse(confirmed: true));
    }
  }
}
