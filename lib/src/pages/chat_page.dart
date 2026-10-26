import 'package:flutter/material.dart';

import '../models.dart';
import '../repository.dart';
import '../widgets.dart';
import 'grant_detail_page.dart';

const _suggestions = [
  'Which funders gave the most in Fort Mill?',
  'Who funds food pantries or hunger relief?',
  'How much was granted in each tax year?',
  'What grants went to schools in Rock Hill?',
];

/// Ask tab: questions about the grant data, answered by the grant-chat
/// Edge Function from the same public views the rest of the app shows.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messages = <ChatMessage>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  ChatProblem? _problem;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    final repository = GrantsScope.of(context);
    setState(() {
      _messages.add(ChatMessage.user(text));
      _input.clear();
      _sending = true;
      _problem = null;
    });
    _scrollToEnd();
    try {
      final reply = await repository.askChat(List.of(_messages));
      if (!mounted) return;
      setState(() => _messages.add(reply));
    } on ChatException catch (e) {
      if (mounted) setState(() => _problem = e.problem);
    } catch (_) {
      if (mounted) setState(() => _problem = ChatProblem.failed);
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? _Intro(onPick: _send)
              : ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    for (final m in _messages) _Bubble(message: m),
                    if (_sending) const _Thinking(),
                    if (_problem != null) _ProblemNote(problem: _problem!),
                  ],
                ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.dividerTheme.color!)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    enabled: !_sending,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 500,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Ask about funders, places, or years',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton.filled(
                  tooltip: 'Send',
                  onPressed: _sending ? null : () => _send(),
                  icon: const Icon(Icons.arrow_upward),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Ask the grant data', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Answers come only from the IRS grant records in BridgeGrant, so '
          'they cover past grants, not deadlines or how to apply. They can '
          'be wrong, so check the linked records.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Try asking',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        for (final s in _suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(label: Text(s), onPressed: () => onPick(s)),
            ),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (message.fromUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(top: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(message.text, style: TextStyle(color: scheme.onPrimary)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12, right: 24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(message.text),
              if (message.grants.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Records used',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                for (final g in message.grants)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      g.recipient,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${g.funder} · ${g.taxYear}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(formatUsd(g.amountUsd)),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => GrantDetailPage(grant: g),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            'Looking through the grant records…',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProblemNote extends StatelessWidget {
  const _ProblemNote({required this.problem});

  final ChatProblem problem;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: scheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(problem.message, style: TextStyle(color: scheme.error)),
          ),
        ],
      ),
    );
  }
}
