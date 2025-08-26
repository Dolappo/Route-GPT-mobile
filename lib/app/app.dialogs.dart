// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// StackedDialogGenerator
// **************************************************************************

import 'package:stacked_services/stacked_services.dart';

import '../ui/dialogs/create_account/create_account_dialog.dart';
import '../ui/dialogs/info_alert/info_alert_dialog.dart';
import 'app.locator.dart';

enum DialogType {
  infoAlert,
  createAccount,
}

void setupDialogUi() {
  final dialogService = locator<DialogService>();

  final Map<DialogType, DialogBuilder> builders = {
    DialogType.infoAlert: (context, request, completer) =>
        InfoAlertDialog(request: request, completer: completer),
    DialogType.createAccount: (context, request, completer) =>
        CreateAccountDialog(request: request, completer: completer),
  };

  dialogService.registerCustomDialogBuilders(builders);
}
