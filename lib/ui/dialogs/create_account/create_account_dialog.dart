import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:route_gpt/ui/common/buttons/base_button.dart';
import 'package:route_gpt/ui/common/extensions_functions.dart';
import 'package:route_gpt/ui/styles/color.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'create_account_dialog_model.dart';

const double _graphicSize = 60;

class CreateAccountDialog extends StackedView<CreateAccountDialogModel> {
  final DialogRequest request;
  final Function(DialogResponse) completer;

  const CreateAccountDialog({
    Key? key,
    required this.request,
    required this.completer,
  }) : super(key: key);

  @override
  Widget builder(
    BuildContext context,
    CreateAccountDialogModel viewModel,
    Widget? child,
  ) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: appColor.cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                    onTap: () => completer(DialogResponse(confirmed: true)),
                    child: const Icon(Icons.close))
              ],
            ),
            Gap(20),
            Text(
              "Create an account to get more prompts",
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontSize: 20, height: 1),
              textAlign: TextAlign.center,
            ),
            const Gap(20),
            BaseButton(
              buttonIcon: "google".svg,
              label: "Sign up with Google",
              onPressed: () => viewModel.signUpWithGoogle(),
            ),
            const Gap(20),
            Row(
              children: [
                Expanded(
                    child: Divider(
                  color: appColor.dividerColor,
                )),
                const Text("Or"),
                Expanded(
                    child: Divider(
                  color: appColor.dividerColor,
                )),
              ],
            ),
            const Gap(20),
            BaseButton(
              label: "Sign up with Email",
              hasBorder: true,
              onPressed: () {},
            )
          ],
        ),
      ),
    );
  }

  @override
  CreateAccountDialogModel viewModelBuilder(BuildContext context) =>
      CreateAccountDialogModel();
}
