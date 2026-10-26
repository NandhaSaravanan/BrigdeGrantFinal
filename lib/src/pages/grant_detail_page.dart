import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class GrantDetailPage extends StatelessWidget {
  const GrantDetailPage({super.key, required this.grant});

  final Grant grant;

  Future<void> _openFiling(BuildContext context) async {
    final uri = Uri.tryParse(grant.filingUrl);
    final ok =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the source filing.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = grant;
    return Scaffold(
      appBar: AppBar(title: const Text('Grant record')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                HeroPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          InitialsAvatar(g.recipient, size: 48),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              g.recipient,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: BrandStyle.of(context).heroInk,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatUsd(g.amountUsd),
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: BrandStyle.of(context).heroInk,
                          ),
                        ),
                      ),
                      Text(
                        'Reported amount, tax year ${g.taxYear}',
                        style: TextStyle(
                          color: BrandStyle.of(
                            context,
                          ).heroInk.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          HeroPill(
                            icon: Icons.account_balance_outlined,
                            label: 'From ${_short(g.funder)}',
                          ),
                          HeroPill(
                            icon: Icons.place_outlined,
                            label: '${g.city}, ${g.state}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  icon: Icons.receipt_long_outlined,
                  title: 'Record',
                  rows: {
                    'Funder': g.funder,
                    'Recipient': g.recipient,
                    if (g.purpose != null) 'Purpose': g.purpose!,
                    'Recorded location': '${g.city}, ${g.state} ${g.zip}',
                    'County':
                        g.county ??
                        'Not assigned (ZIP spans counties or is a PO box)',
                    'Tax year': '${g.taxYear}',
                  },
                ),
                const SizedBox(height: 12),
                _Section(
                  icon: Icons.description_outlined,
                  title: 'Source',
                  rows: {
                    'Source': g.source,
                    if (g.matchEvidence.isNotEmpty)
                      'Match evidence': g.matchEvidence,
                    'Filing ID': g.filingId,
                  },
                ),
                const SizedBox(height: 16),
                if (g.filingUrl.isNotEmpty)
                  FilledButton.tonalIcon(
                    onPressed: () => _openFiling(context),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open source filing (XML)'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _short(String name) =>
    name.length > 32 ? '${name.substring(0, 30).trimRight()}…' : name;

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows, this.icon});

  final String title;
  final IconData? icon;
  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      icon: icon,
      title: title,
      child: Column(
        children: [
          for (final entry in rows.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 150,
                    child: Text(
                      entry.key,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SelectableText(
                      entry.value.isEmpty ? '—' : entry.value,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
