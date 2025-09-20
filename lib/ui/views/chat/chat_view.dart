import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:route_gpt/ui/styles/color.dart';
import 'package:route_gpt/ui/styles/dimension.dart';
import 'package:stacked/stacked.dart';

import '../../../models/chat_message.dart';
import '../../views/map/map_view.dart';
import 'chat_viewmodel.dart';

class ChatView extends StackedView<ChatViewModel> {
  const ChatView({Key? key}) : super(key: key);

  @override
  Widget builder(BuildContext context, ChatViewModel viewModel, Widget? child) {
    return Scaffold(
      key: viewModel.scaffoldKey,
      // backgroundColor: appColor.backgroundColor,
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
                    // surfaceTintColor: appColor.backgroundColor,
                    automaticallyImplyLeading: false,
                    expandedHeight: 50.0,
                    floating: true,
                    // pinned: true,
                    centerTitle: false,
                    snap: true,
                    // backgroundColor: appColor.backgroundColor,
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
                      if (viewModel.isAuthenticated &&
                          viewModel.pendingMessagesCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${viewModel.pendingMessagesCount}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ),
                      if (viewModel.isAuthenticated && !viewModel.isOnline)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.wifi_off,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          viewModel.scaffoldKey.currentState?.openEndDrawer();
                        },
                        child: _ProfileCircle(viewModel: viewModel),
                      ),
                    ],
                  ),
                  if (viewModel.messages.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const Gap(16),
                            Text(
                              "Hello, how can I help you today?",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final message = viewModel.messages[index];
                        return _MessageBubble(
                          message: message,
                          onRetry: message.status == MessageStatus.error
                              ? () => viewModel.retryMessage(index)
                              : null,
                        );
                      },
                      childCount: viewModel.messages.length,
                    ),
                  ),
                ],
              ),
            ),
            _InputField(
              onSubmitted: viewModel.sendMessage,
              enabled:
                  viewModel.remainingFreePrompts > 0 && !viewModel.isProcessing,
              isOffline: viewModel.isAuthenticated && !viewModel.isOnline,
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
    viewModel.initialize();
    viewModel.showCreateAccountDialogIfNeeded();
  }
}

class _ProfileCircle extends StatelessWidget {
  final ChatViewModel viewModel;

  const _ProfileCircle({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final photo = viewModel.currentUserPhotoUrl;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: photo != null
              ? Colors.transparent
              : Colors.grey.withValues(alpha: 0.3),
          backgroundImage: photo != null ? NetworkImage(photo) : null,
          child: photo == null
              ? const Icon(Icons.person, size: 16, color: Colors.white)
              : null,
        ),
        if (!viewModel.isAuthenticated)
          Text(
            'Sign in',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 10,
                ),
          ),
      ],
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
            if (!viewModel.isAuthenticated)
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Sign in with Google'),
                onTap: () async {
                  final navigator = Navigator.of(context);
                  final ok = await viewModel.signInWithGoogle();
                  if (ok) navigator.maybePop();
                },
              ),
            if (!viewModel.isAuthenticated)
              ListTile(
                leading: const Icon(Icons.email),
                title: const Text('Sign in with Email'),
                onTap: () async {
                  final navigator = Navigator.of(context);
                  // Minimal inline email sign-in prompt
                  final emailController = TextEditingController();
                  final pwController = TextEditingController();
                  final ctx = navigator.context;
                  await showDialog(
                    context: ctx,
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
                            final dialogNavigator = Navigator.of(ctx);
                            final ok = await viewModel.signInWithEmail(
                                emailController.text.trim(), pwController.text);
                            if (ok) dialogNavigator.pop();
                          },
                          child: const Text('Sign in'),
                        ),
                      ],
                    ),
                  );
                  navigator.maybePop();
                },
              ),
            if (viewModel.isAuthenticated)
              ListTile(
                leading: const Icon(Icons.clear_all),
                title: const Text('Clear Today\'s Chat'),
                onTap: () async {
                  final navigator = Navigator.of(context);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      title: const Text('Clear Chat'),
                      content: const Text(
                          'Are you sure you want to clear today\'s chat history?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogCtx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(dialogCtx).pop(true),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await viewModel.clearTodayChat();
                    navigator.maybePop();
                  }
                },
              ),
            if (viewModel.isAuthenticated && viewModel.pendingMessagesCount > 0)
              ListTile(
                leading: const Icon(Icons.sync),
                title: Text(
                    'Sync Pending Messages (${viewModel.pendingMessagesCount})'),
                onTap: () async {
                  final navigator = Navigator.of(context);
                  await viewModel.forceSync();
                  navigator.maybePop();
                },
              ),
            if (viewModel.isAuthenticated && !viewModel.isOnline)
              const ListTile(
                leading: Icon(Icons.wifi_off),
                title: Text('Offline Mode'),
                subtitle: Text('Messages will sync when online'),
                onTap: null,
              ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                // TODO: Navigate to settings view when implemented
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Light mode'),
              trailing: Switch.adaptive(
                  value: viewModel.isLightTheme,
                  onChanged: (val) => viewModel.toggleTheme(val)),
            ),
            if (viewModel.isAuthenticated)
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () async {
                  final navigator = Navigator.of(context);
                  await viewModel.logout();
                  navigator.maybePop();
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
    final hasMapData = message.metadata?['hasMapData'] == true;
    final originCoordinates = message.metadata?['originCoordinates'] as String?;
    final destinationCoordinates =
        message.metadata?['destinationCoordinates'] as String?;
    final travelMode = message.metadata?['travelMode'] as String? ?? 'DRIVE';

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
            if (hasMapData &&
                originCoordinates != null &&
                destinationCoordinates != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevatedButton.icon(
                  onPressed: () {
                    try {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => MapView(
                            originCoordinates: originCoordinates,
                            destinationCoordinates: destinationCoordinates,
                            travelMode: travelMode,
                          ),
                        ),
                      );
                    } catch (e) {
                      print('Error navigating to map: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error opening map: $e'),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.map, size: 16),
                  label: const Text('View on Map'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.withValues(alpha: 0.8),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
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
  final bool isOffline;

  const _InputField({
    required this.onSubmitted,
    required this.enabled,
    required this.isOffline,
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
                hintText: widget.isOffline
                    ? 'You\'re offline. Connect to send messages.'
                    : widget.enabled
                        ? 'Ask for directions or traffic info...'
                        : 'Create an account to continue',
                hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
              ),
              enabled: widget.enabled && !widget.isOffline,
              onSubmitted: _handleSubmit,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: (widget.enabled && !widget.isOffline)
                ? () => _handleSubmit(_controller.text)
                : null,
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
