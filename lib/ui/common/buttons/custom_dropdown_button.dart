// import 'package:flutter/material.dart';
// import 'package:tope_dare_at_50/ui/styles/color.dart';
// import 'package:tope_dare_at_50/ui/styles/dimension.dart';
//
// class AppCustomDropdown extends StatelessWidget {
//   final String title;
//   final void Function()? onTap;
//   const AppCustomDropdown({super.key, required this.title, this.onTap});
//
//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(Dimen.roundButtonRadius),
//             border: Border.all(color: Colors.grey, width: 0.7)),
//         padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Expanded(
//               child: Text(title,
//                   style: Theme.of(context)
//                       .textTheme
//                       .bodyMedium
//                       ?.copyWith(color: appColor.secondaryTextColor)),
//             ),
//             Icon(
//               Icons.keyboard_arrow_down_outlined,
//               color: appColor.secondaryTextColor,
//             )
//           ],
//         ),
//       ),
//     );
//   }
// }
