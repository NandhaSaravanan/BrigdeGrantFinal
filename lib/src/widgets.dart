import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'theme.dart';

final _currency = NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0);
final _compactCurrency = NumberFormat.compactSimpleCurrency(name: 'USD');
final _count = NumberFormat.decimalPattern();

String formatUsd(num value) => _currency.format(value);

String formatUsdCompact(num value) => value.abs() < 10000
    ? _currency.format(value)
    : _compactCurrency.format(value);

String formatCount(num value) => _count.format(value);

/// Width at which layouts switch from phone to tablet/desktop arrangements.
const wideBreakpoint = 840.0;

bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= wideBreakpoint;

/// Up to two uppercase initials from [name], or an empty string.
String initialsOf(String name) => name
    .split(RegExp(r'[\s&/-]+'))
    .where((w) => w.isNotEmpty && RegExp(r'[A-Za-z0-9]').hasMatch(w[0]))
    .take(2)
    .map((w) => w[0].toUpperCase())
    .join();

/// Circular initials badge with a color derived from [name].
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.name, {super.key, this.size = 40});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = initialsOf(name);
    final color = Brand.accentFor(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.25)!],
        ),
      ),
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

/// Rounded, tinted square holding an icon.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, required this.color, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(size * 0.3),
    ),
    child: Icon(icon, color: color, size: size * 0.55),
  );
}

/// Gradient banner used at the top of the dashboard and detail pages.
class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final style = BrandStyle.of(context);
    Widget orb(double size, double alpha) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(
          alpha: (alpha * style.heroOrbAlphaScale).clamp(0, 1),
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        gradient: style.heroGradient,
        borderRadius: BorderRadius.circular(style.heroRadius),
        border: style.heroBorder == null
            ? null
            : Border.all(color: style.heroBorder!),
        boxShadow: [
          BoxShadow(
            color: style.heroShadow.withValues(
              alpha: style.heroBorder == null ? 0.28 : 0.06,
            ),
            blurRadius: style.heroBorder == null ? 24 : 12,
            offset: Offset(0, style.heroBorder == null ? 10 : 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(right: -60, top: -70, child: orb(220, 0.08)),
          Positioned(right: 60, bottom: -90, child: orb(180, 0.06)),
          Positioned(left: -40, bottom: -50, child: orb(120, 0.05)),
          Padding(padding: const EdgeInsets.all(24), child: child),
        ],
      ),
    );
  }
}

/// Small translucent pill shown on [HeroPanel].
class HeroPill extends StatelessWidget {
  const HeroPill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final style = BrandStyle.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: style.heroPillBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.heroPillBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: style.heroInk),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: style.heroInk,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: CircularProgressIndicator(),
    ),
  );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => MessageView(
    icon: Icons.cloud_off,
    title: 'Could not load grant data',
    message: describeError(error),
    action: FilledButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('Try again'),
    ),
  );
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => MessageView(
    icon: Icons.search_off,
    title: 'No matching records',
    message: message,
    action: action,
  );
}

class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.6,
                ),
              ),
              child: Icon(icon, size: 40, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Short, non-technical error text. Never includes request headers or keys.
String describeError(Object error) {
  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('XMLHttpRequest')) {
    return 'Check your internet connection and try again.';
  }
  if (text.contains('permission denied') || text.contains('42501')) {
    return 'The public grant views are not readable with this key.';
  }
  if (text.contains('does not exist') || text.contains('PGRST205')) {
    return 'The grant views were not found. Run the Supabase setup script.';
  }
  return 'Something went wrong while contacting the data service.';
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.icon = Icons.insights,
    this.color,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    final flat = BrandStyle.of(context).flat;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (!flat) ...[
                  IconBadge(icon, color: accent, size: 34),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: flat ? 6 : 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: flat
                    ? theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      )
                    : theme.textTheme.headlineSmall,
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 2),
              Text(
                caption!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A labeled horizontal bar; the bar length is [value] relative to [max].
class BarRow extends StatelessWidget {
  const BarRow({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.max,
    this.subtitle,
    this.rank,
    this.onTap,
  });

  final String label;
  final String? subtitle;
  final String valueLabel;
  final num value;
  final num max;

  /// 1-based position shown as a badge when set.
  final int? rank;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0).toDouble();
    final top = rank != null && rank! <= 3;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rank != null) ...[
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: top ? BrandStyle.of(context).badgeGradient : null,
                  color: top ? null : scheme.surfaceContainerHighest,
                ),
                child: Text(
                  '$rank',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: top
                        ? BrandStyle.of(context).badgeInk
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        valueLabel,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                      if (onTap != null)
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: scheme.outline,
                        ),
                    ],
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: fraction == 0 ? 0 : fraction.clamp(0.02, 1),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            colors: [scheme.secondary, scheme.primary],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Pager extends StatelessWidget {
  const Pager({
    super.key,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.onPage,
  });

  final int page;
  final int pageSize;
  final int totalCount;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pageCount = (totalCount / pageSize).ceil().clamp(1, 1 << 30);
    final first = totalCount == 0 ? 0 : page * pageSize + 1;
    final last = ((page + 1) * pageSize).clamp(0, totalCount);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$first–$last of ${formatCount(totalCount)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Previous page',
                  visualDensity: VisualDensity.compact,
                  onPressed: page > 0 ? () => onPage(page - 1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '${page + 1} / $pageCount',
                  style: theme.textTheme.labelLarge,
                ),
                IconButton(
                  tooltip: 'Next page',
                  visualDensity: VisualDensity.compact,
                  onPressed: page + 1 < pageCount
                      ? () => onPage(page + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Section with a title used on the dashboard and aggregate pages.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      // Keep children (e.g. chart bars, rows) as separate accessibility
      // nodes instead of merging the whole card into one.
      semanticContainer: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null && !BrandStyle.of(context).flat) ...[
                  IconBadge(icon!, color: theme.colorScheme.primary, size: 32),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// Toggle between ranking by dollars and by number of grants.
class AggregateSortToggle extends StatelessWidget {
  const AggregateSortToggle({
    super.key,
    required this.byAmount,
    required this.onChanged,
  });

  final bool byAmount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<bool>(
    showSelectedIcon: false,
    segments: const [
      ButtonSegment(value: true, label: Text('Amount')),
      ButtonSegment(value: false, label: Text('Count')),
    ],
    selected: {byAmount},
    onSelectionChanged: (s) => onChanged(s.first),
  );
}
