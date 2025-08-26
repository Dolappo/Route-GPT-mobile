import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:lottie/lottie.dart';
import 'package:route_gpt/ui/common/buttons/base_button.dart';
import 'package:route_gpt/ui/common/extensions_functions.dart';
import 'package:route_gpt/ui/styles/color.dart';
import 'package:route_gpt/ui/styles/dimension.dart';
import 'package:stacked/stacked.dart';

import 'onboarding_viewmodel.dart';

class OnboardingView extends StackedView<OnboardingViewModel> {
  const OnboardingView({Key? key}) : super(key: key);

  @override
  Widget builder(
    BuildContext context,
    OnboardingViewModel viewModel,
    Widget? child,
  ) {
    return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: Padding(
          padding: Dimen.bodyPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  SvgPicture.asset("man".svg),
                  Lottie.asset(
                    "assets/lottie/travel.json",
                    delegates: LottieDelegates(
                      values: [
                        ValueDelegate.color(
                          const ['Dash Lines', 'Shape 1', 'Stroke 1'],
                          value: Colors.white, // new color for the path
                        ),

                        // (Optional) also change the location pins if you want
                        ValueDelegate.color(
                          const ['Location', 'Group 1', 'Fill 1'],
                          value: Colors.white,
                        ),
                        ValueDelegate.color(
                          const ['Location 2', 'Group 1', 'Fill 1'],
                          value: appColor.primaryColor,
                        ),
                      ],
                    ),
                  )
                ],
              ),
              const Gap(10),
              Text(
                "Your AI Travel Companion",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 40, fontWeight: FontWeight.w900, height: 1),
              ),
              const Gap(10),
              const Text(
                "Get smarter routes, real-time travel insights, and personalized navigation — all in one app",
                textAlign: TextAlign.center,
              ),
              const Expanded(child: Gap(10)),
              BaseButton(
                label: "Get Started",
                onPressed: () => viewModel.navToHome(),
              ),
              const Gap(20)
            ],
          ),
        ));
  }

  @override
  OnboardingViewModel viewModelBuilder(
    BuildContext context,
  ) =>
      OnboardingViewModel();
}
