import 'package:flutter/material.dart';

import '../bar_chart.dart';
import '../models.dart';
import '../repository.dart';
import '../widgets.dart';
import 'grants_page.dart';

/// Where funding is recorded, by city and ZIP code.
class PlacesPage extends StatefulWidget {
  const PlacesPage({super.key});

  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends State<PlacesPage> {
  PlaceKind _kind = PlaceKind.city;
  bool _byAmount = true;
  int _selected = 0;
  Future<List<GrantAggregate>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<GrantAggregate>> _load() => GrantsScope.of(context).fetchPlaces(
    kind: _kind,
    sort: _byAmount ? AggregateSort.amount : AggregateSort.count,
  );

  void _reload() => setState(() {
    _selected = 0;
    _future = _load();
  });

  void _open(GrantAggregate row) {
    final isCity = _kind == PlaceKind.city;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FilteredGrantsPage(
          title: isCity ? row.label : 'ZIP ${row.label}',
          filters: isCity
              ? GrantFilters(city: row.label)
              : GrantFilters(zip: row.label),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            SegmentedButton<PlaceKind>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: PlaceKind.city, label: Text('City')),
                ButtonSegment(value: PlaceKind.zip, label: Text('ZIP code')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) {
                _kind = s.first;
                _reload();
              },
            ),
            AggregateSortToggle(
              byAmount: _byAmount,
              onChanged: (v) {
                _byAmount = v;
                _reload();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<GrantAggregate>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LoadingView();
            }
            if (snapshot.hasError) {
              return ErrorView(error: snapshot.error!, onRetry: _reload);
            }
            final rows = snapshot.data!;
            if (rows.isEmpty) {
              return const EmptyView(message: 'No locations recorded yet.');
            }
            final max = rows
                .map((r) => _byAmount ? r.totalAmountUsd : r.grantCount)
                .reduce((a, b) => a > b ? a : b);
            final isCity = _kind == PlaceKind.city;
            final chartRows = rows.take(7).toList();
            final selected = _selected.clamp(0, chartRows.length - 1);
            String value(GrantAggregate r) => _byAmount
                ? formatUsdCompact(r.totalAmountUsd)
                : formatCount(r.grantCount);

            final chart = SectionCard(
              icon: Icons.bar_chart_rounded,
              title:
                  '${_byAmount ? 'Grant dollars' : 'Grants'} by '
                  '${isCity ? 'city' : 'ZIP code'}'
                  '${rows.length > chartRows.length ? ' · top ${chartRows.length}' : ''}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tap a bar to see its value',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  VerticalBarChart(
                    labels: [for (final r in chartRows) r.label],
                    values: [
                      for (final r in chartRows)
                        _byAmount ? r.totalAmountUsd : r.grantCount,
                    ],
                    valueLabels: [for (final r in chartRows) value(r)],
                    selected: selected,
                    onSelect: (i) => setState(() => _selected = i),
                  ),
                ],
              ),
            );

            final list = Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    for (final (i, r) in rows.indexed)
                      BarRow(
                        rank: i + 1,
                        label: _kind == PlaceKind.city
                            ? '${r.label}, ${r.secondaryLabel}'
                            : '${r.label} · ${r.secondaryLabel}',
                        subtitle: _subtitle(r),
                        valueLabel: _byAmount
                            ? formatUsdCompact(r.totalAmountUsd)
                            : formatCount(r.grantCount),
                        value: _byAmount ? r.totalAmountUsd : r.grantCount,
                        max: max,
                        onTap: () => _open(r),
                      ),
                  ],
                ),
              ),
            );
            return Column(children: [chart, const SizedBox(height: 16), list]);
          },
        ),
      ],
    );
  }

  String _subtitle(GrantAggregate r) {
    final parts = [
      '${formatCount(r.grantCount)} grants',
      formatUsd(r.totalAmountUsd),
      if (r.medianAmountUsd != null)
        'median ${formatUsdCompact(r.medianAmountUsd!)}',
      '${formatCount(r.funderCount ?? 0)} funders',
      '${formatCount(r.recipientCount ?? 0)} recipients',
    ];
    return parts.join(' · ');
  }
}
