import 'package:flutter/material.dart';

import '../models.dart';
import '../repository.dart';
import '../theme.dart';
import '../widgets.dart';
import 'grants_page.dart';

class _DashboardData {
  const _DashboardData({
    required this.years,
    required this.overview,
    required this.cities,
    required this.funders,
    required this.recipients,
  });

  final List<GrantAggregate> years;

  /// All-years summary; null if the overview view is unavailable.
  final GrantAggregate? overview;
  final List<GrantAggregate> cities;
  final ResultPage<GrantAggregate> funders;
  final ResultPage<GrantAggregate> recipients;
}

/// Overview of source-matched records with links into the other views.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.onNavigate});

  /// Switches the app shell to another tab.
  final NavigateTo onNavigate;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Future<_DashboardData>? _future;

  /// Selected tax year label, or null for all years.
  String? _year;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<_DashboardData> _load() async {
    final repo = GrantsScope.of(context);
    // The overview is optional so the screen still works before the
    // grants_overview view exists; totals then come from the yearly rows.
    final overview = repo.fetchOverview().then<GrantAggregate?>(
      (o) => o,
      onError: (_) => null,
    );
    final results = await Future.wait<Object>([
      repo.fetchTaxYears(),
      repo.fetchPlaces(kind: PlaceKind.city, sort: AggregateSort.amount),
      repo.fetchEntities(
        kind: EntityKind.funder,
        sort: AggregateSort.amount,
        page: 0,
        pageSize: 5,
      ),
      repo.fetchEntities(
        kind: EntityKind.recipient,
        sort: AggregateSort.amount,
        page: 0,
        pageSize: 5,
      ),
    ]);
    return _DashboardData(
      years: results[0] as List<GrantAggregate>,
      overview: await overview,
      cities: results[1] as List<GrantAggregate>,
      funders: results[2] as ResultPage<GrantAggregate>,
      recipients: results[3] as ResultPage<GrantAggregate>,
    );
  }

  void _drill(String title, GrantFilters filters) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => FilteredGrantsPage(title: title, filters: filters),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView();
        }
        if (snapshot.hasError) {
          return ErrorView(
            error: snapshot.error!,
            onRetry: () => setState(() {
              _future = _load();
            }),
          );
        }
        final data = snapshot.data!;
        if (data.years.isEmpty) {
          return const EmptyView(
            message: 'No grant records have been loaded into the database.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            final next = _load();
            setState(() {
              _future = next;
            });
            await next;
          },
          child: _buildContent(context, data),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, _DashboardData data) {
    final wide = isWide(context);
    final multiYear = data.years.length > 1;
    final yearRow = data.years.where((y) => y.label == _year).firstOrNull;
    // A single loaded year is the same as "all years".
    final GrantAggregate selected =
        yearRow ??
        (multiYear ? null : data.years.first) ??
        data.overview ??
        GrantAggregate(
          label: 'All years',
          grantCount: data.years.fold<int>(0, (s, y) => s + y.grantCount),
          totalAmountUsd: data.years.fold<num>(
            0,
            (s, y) => s + y.totalAmountUsd,
          ),
        );
    final totalCount = selected.grantCount;
    final totalAmount = selected.totalAmountUsd;
    final sortedYears = [...data.years]
      ..sort((a, b) => b.label.compareTo(a.label));
    final yearPillLabel = yearRow != null || !multiYear
        ? 'Tax year ${yearRow?.label ?? data.years.first.label}'
        : 'Tax years ${sortedYears.last.label}–${sortedYears.first.label}';

    final stats = <Widget>[
      if (selected.medianAmountUsd != null)
        StatTile(
          icon: Icons.stacked_line_chart,
          color: Brand.accents[0],
          label: 'Median grant',
          value: formatUsd(selected.medianAmountUsd!),
          caption: 'Typical record; amounts are skewed',
        ),
      if (selected.averageAmountUsd != null)
        StatTile(
          icon: Icons.functions,
          color: Brand.accents[2],
          label: 'Average grant',
          value: formatUsd(selected.averageAmountUsd!),
          caption: 'Pulled up by a few large grants',
        ),
      if (selected.funderCount != null)
        StatTile(
          icon: Icons.account_balance,
          color: Brand.accents[1],
          label: 'Funders',
          value: formatCount(selected.funderCount!),
          caption: 'Distinct EINs',
        ),
      if (selected.recipientCount != null)
        StatTile(
          icon: Icons.groups,
          color: Brand.accents[3],
          label: 'Recipients',
          value: formatCount(selected.recipientCount!),
          caption: 'By EIN, or name when no EIN',
        ),
    ];

    final hero = HeroPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const HeroPill(
                icon: Icons.description_outlined,
                label: 'Source-matched IRS filings',
              ),
              HeroPill(
                icon: Icons.calendar_today_outlined,
                label: yearPillLabel,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Reported dollars',
            style: TextStyle(
              color: BrandStyle.of(context).heroInk.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatUsd(totalAmount),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: BrandStyle.of(context).heroInk,
                fontSize: wide ? 52 : 40,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'across ${formatCount(totalCount)} grant records matched to '
            'IRS-derived filings',
            style: TextStyle(
              color: BrandStyle.of(context).heroInk.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: BrandStyle.of(context).heroButtonBg,
              foregroundColor: BrandStyle.of(context).heroButtonInk,
            ),
            onPressed: () =>
                widget.onNavigate(AppTab.explore, view: ExploreView.grants),
            icon: const Icon(Icons.manage_search),
            label: const Text('Explore all grant records'),
          ),
        ],
      ),
    );

    final cityMax = data.cities.isEmpty ? 0 : data.cities.first.totalAmountUsd;
    final cities = SectionCard(
      icon: Icons.place_outlined,
      title: 'Where funding is recorded',
      trailing: TextButton(
        onPressed: () => widget.onNavigate(AppTab.places),
        child: const Text('All places'),
      ),
      child: Column(
        children: [
          for (final (i, c) in data.cities.take(6).indexed)
            BarRow(
              rank: i + 1,
              label: c.label,
              subtitle: '${formatCount(c.grantCount)} grants',
              valueLabel: formatUsdCompact(c.totalAmountUsd),
              value: c.totalAmountUsd,
              max: cityMax,
              onTap: () => _drill(c.label, GrantFilters(city: c.label)),
            ),
        ],
      ),
    );

    Widget top(String title, ResultPage<GrantAggregate> page, bool funder) {
      final max = page.items.isEmpty ? 0 : page.items.first.totalAmountUsd;
      return SectionCard(
        icon: funder ? Icons.account_balance_outlined : Icons.groups_outlined,
        title: title,
        trailing: TextButton(
          onPressed: () => widget.onNavigate(
            AppTab.explore,
            view: funder ? ExploreView.funders : ExploreView.recipients,
          ),
          child: Text('All ${formatCount(page.totalCount)}'),
        ),
        child: Column(
          children: [
            for (final (i, r) in page.items.indexed)
              BarRow(
                rank: i + 1,
                label: r.label,
                subtitle: '${formatCount(r.grantCount)} grants',
                valueLabel: formatUsdCompact(r.totalAmountUsd),
                value: r.totalAmountUsd,
                max: max,
                onTap: () => _drill(
                  r.label,
                  funder
                      ? GrantFilters(funder: r.label)
                      : GrantFilters(recipient: r.label),
                ),
              ),
          ],
        ),
      );
    }

    final funders = top('Top funders by amount', data.funders, true);
    final recipients = top('Top recipients by amount', data.recipients, false);

    final years = SectionCard(
      icon: Icons.calendar_month_outlined,
      title: 'Tax years loaded',
      child: Text(
        data.years.length == 1
            ? 'All records are from tax year ${data.years.first.label}. Tax year '
                  'is a filter, not a trend, until more years are loaded.'
            : data.years
                  .map(
                    (y) =>
                        '${y.label}: ${formatCount(y.grantCount)} records, '
                        '${formatUsd(y.totalAmountUsd)}'
                        '${partialTaxYears.contains(int.tryParse(y.label)) ? ' (still incomplete)' : ''}',
                  )
                  .followedBy([
                    if (data.years.any(
                      (y) => partialTaxYears.contains(int.tryParse(y.label)),
                    ))
                      '\nRecent years keep growing for 2–3 years as late IRS '
                          'returns arrive, so lower totals there are not real '
                          'declines.',
                  ])
                  .join('\n'),
      ),
    );

    final yearPicker = !multiYear
        ? null
        : Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Tax year', style: Theme.of(context).textTheme.labelLarge),
              ChoiceChip(
                label: const Text('All years'),
                selected: _year == null,
                onSelected: (_) => setState(() => _year = null),
              ),
              for (final y in sortedYears)
                ChoiceChip(
                  label: Text(y.label),
                  selected: _year == y.label,
                  onSelected: (_) => setState(() => _year = y.label),
                ),
            ],
          );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(wide ? 24 : 16),
      children: [
        if (yearPicker != null) ...[yearPicker, const SizedBox(height: 12)],
        hero,
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 340
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final s in stats) SizedBox(width: width, child: s),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        if (yearRow != null && multiYear) ...[
          Text(
            'Places, funders, and recipients below include all tax years.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cities),
              const SizedBox(width: 16),
              Expanded(child: years),
            ],
          )
        else ...[
          cities,
          const SizedBox(height: 16),
          years,
        ],
        const SizedBox(height: 16),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: funders),
              const SizedBox(width: 16),
              Expanded(child: recipients),
            ],
          )
        else ...[
          funders,
          const SizedBox(height: 16),
          recipients,
        ],
      ],
    );
  }
}
