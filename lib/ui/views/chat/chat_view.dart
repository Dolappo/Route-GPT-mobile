import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:route_gpt/ui/styles/color.dart';
import 'package:route_gpt/ui/styles/dimension.dart';
import 'package:stacked/stacked.dart';

import 'chat_viewmodel.dart';

class ChatView extends StackedView<ChatViewModel> {
  const ChatView({Key? key}) : super(key: key);

  @override
  Widget builder(BuildContext context, ChatViewModel viewModel, Widget? child) {
    return Scaffold(
      key: viewModel.scaffoldKey,
      endDrawer: _EndDrawer(viewModel: viewModel),
      body: Padding(
        padding: Dimen.bodyPadding,
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                controller: viewModel.scrollController,
                slivers: [
                  SliverAppBar(
                    surfaceTintColor: appColor.secondaryColor,
                    automaticallyImplyLeading: false,
                    expandedHeight: 50.0,
                    floating: true,
                    pinned: true,
                    centerTitle: false,
                    snap: true,
                    title: Row(
                      children: [
                        Text(
                          "RouteGPT",
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(fontSize: 30),
                        ),
                      ],
                    ),
                    actions: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: viewModel.remainingFreePrompts > 0
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.orange.withValues(alpha: 0.2),
                          border: Border.all(
                            color: viewModel.remainingFreePrompts > 0
                                ? Colors.green.withValues(alpha: 0.5)
                                : Colors.orange.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          '${viewModel.remainingFreePrompts}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: viewModel.remainingFreePrompts > 0
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                      const Gap(10),
                      GestureDetector(
                        onTap: () {
                          print("Open drawer");
                          viewModel.scaffoldKey.currentState!.openEndDrawer();
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ProfileCircle(viewModel: viewModel),
                            const SizedBox(height: 4),
                            Text(
                              viewModel.isAuthenticated
                                  ? (viewModel.currentUserFirstName ?? '')
                                  : 'Sign in',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (viewModel.messages.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text(
                            'Hello, how can I help you today?',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final message = viewModel.messages[index];
                          return _MessageBubble(
                            message: message,
                            onRetry: () => viewModel.retryMessage(index),
                          );
                        },
                        childCount: viewModel.messages.length,
                      ),
                    ),
                ],
              ),
            ),
            const Gap(10),
            if (viewModel.isBusy) const LinearProgressIndicator(),
            _InputField(
              onSubmitted: viewModel.sendMessage,
              enabled:
                  !viewModel.isProcessing && viewModel.remainingFreePrompts > 0,
            ),
          ],
        ),
      ),
    );
  }

  @override
  ChatViewModel viewModelBuilder(BuildContext context) => ChatViewModel();

  @override
  void onViewModelReady(ChatViewModel viewModel) {
    super.onViewModelReady(viewModel);
    viewModel.initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!viewModel.hasShownCreateAccountDialog &&
          !viewModel.isAuthenticated) {
        viewModel.showCreateAccountDialogIfNeeded();
      }
    });
  }
}

class _ProfileCircle extends StatelessWidget {
  final ChatViewModel viewModel;
  const _ProfileCircle({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final photo = viewModel.currentUserPhotoUrl;
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.white.withValues(alpha: 0.2),
      backgroundImage: photo != null ? NetworkImage(photo) : null,
      child: photo == null
          ? const Icon(Icons.person, size: 16, color: Colors.white)
          : null,
    );
  }
}

class _EndDrawer extends StatelessWidget {
  final ChatViewModel viewModel;
  const _EndDrawer({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  _ProfileCircle(viewModel: viewModel),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          viewModel.isAuthenticated
                              ? (viewModel.currentUserName ?? '')
                              : 'Guest',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (viewModel.currentUserEmail != null)
                          Text(
                            viewModel.currentUserEmail!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: appColor.dividerColor),
            if (viewModel.isAuthenticated)
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () async {
                  await viewModel.logout();
                  Navigator.of(context).maybePop();
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Sign in with Google'),
                onTap: () async {
                  final ok = await viewModel.signInWithGoogle();
                  if (ok) Navigator.of(context).maybePop();
                },
              ),
            if (!viewModel.isAuthenticated)
              ListTile(
                leading: const Icon(Icons.email),
                title: const Text('Sign in with Email'),
                onTap: () async {
                  // Minimal inline email sign-in prompt
                  final emailController = TextEditingController();
                  final pwController = TextEditingController();
                  await showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Sign in'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: emailController,
                            decoration:
                                const InputDecoration(labelText: 'Email'),
                          ),
                          TextField(
                            controller: pwController,
                            decoration:
                                const InputDecoration(labelText: 'Password'),
                            obscureText: true,
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () async {
                            final ok = await viewModel.signInWithEmail(
                                emailController.text.trim(), pwController.text);
                            if (ok) Navigator.of(ctx).pop();
                          },
                          child: const Text('Sign in'),
                        ),
                      ],
                    ),
                  );
                  Navigator.of(context).maybePop();
                },
              ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                // TODO: Navigate to settings view when implemented
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;

  const _MessageBubble({
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(
          vertical: 4,
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: message.isUser ? appColor.dividerColor : appColor.cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: message.isUser
                ? const Radius.circular(0)
                : const Radius.circular(20),
            bottomLeft: message.isUser
                ? const Radius.circular(20)
                : const Radius.circular(0),
            bottomRight: const Radius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  message.formattedTime,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                ),
                const SizedBox(width: 8),
                if (!message.isUser) ...[
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: message.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Copied to clipboard',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.copy,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (message.status == MessageStatus.error && onRetry != null)
                    GestureDetector(
                      onTap: onRetry,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.refresh,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatefulWidget {
  final Function(String) onSubmitted;
  final bool enabled;

  const _InputField({
    required this.onSubmitted,
    required this.enabled,
  });

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: widget.enabled
                    ? 'Ask for directions or traffic info...'
                    : 'Create an account to continue',
                hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
              ),
              enabled: widget.enabled,
              onSubmitted: _handleSubmit,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed:
                widget.enabled ? () => _handleSubmit(_controller.text) : null,
          ),
        ],
      ),
    );
  }

  void _handleSubmit(String text) {
    if (text.trim().isNotEmpty) {
      widget.onSubmitted(text);
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
