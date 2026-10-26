import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../repository.dart';
import '../widgets.dart';
import 'grant_detail_page.dart';

/// Searchable, filterable, sortable, paginated list of grant records.
class GrantExplorer extends StatefulWidget {
  const GrantExplorer({
    super.key,
    this.initialFilters = const GrantFilters(),
    this.pageSize = 25,
  });

  final GrantFilters initialFilters;
  final int pageSize;

  @override
  State<GrantExplorer> createState() => _GrantExplorerState();
}

class _GrantExplorerState extends State<GrantExplorer> {
  late GrantFilters _filters = widget.initialFilters;
  late final _searchController = TextEditingController(
    text: widget.initialFilters.search,
  );
  GrantSort _sort = GrantSort.amountDesc;
  int _page = 0;
  Future<ResultPage<Grant>>? _future;
  Future<FilterOptions>? _options;
  Timer? _debounce;

  GrantsRepository get _repo => GrantsScope.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<ResultPage<Grant>> _load() => _repo.fetchGrants(
    filters: _filters,
    sort: _sort,
    page: _page,
    pageSize: widget.pageSize,
  );

  void _update({GrantFilters? filters, GrantSort? sort, int page = 0}) {
    setState(() {
      _filters = filters ?? _filters;
      _sort = sort ?? _sort;
      _page = page;
      _future = _load();
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _update(filters: _filters.copyWith(search: value));
    });
  }

  void _reset() {
    _searchController.clear();
    _update(filters: const GrantFilters());
  }

  Future<void> _openFilters() async {
    _options ??= _repo.fetchFilterOptions();
    final result = await showModalBottomSheet<GrantFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(
        initial: _filters,
        options: _options!,
        onRetryOptions: () => _options = _repo.fetchFilterOptions(),
      ),
    );
    if (result != null) _update(filters: result);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              _Toolbar(
                controller: _searchController,
                sort: _sort,
                onSearch: _onSearchChanged,
                onSort: (s) => _update(sort: s),
                onFilters: _openFilters,
              ),
              _ActiveFilters(
                filters: _filters,
                onChanged: (f) => _update(filters: f),
                onReset: _reset,
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<ResultPage<Grant>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LoadingView();
              }
              if (snapshot.hasError) {
                return ErrorView(
                  error: snapshot.error!,
                  onRetry: () => _update(page: _page),
                );
              }
              final page = snapshot.data!;
              if (page.items.isEmpty) {
                return EmptyView(
                  message: _filters.isEmpty
                      ? 'No grant records are available yet.'
                      : 'Try removing a filter or changing the search.',
                  action: _filters.isEmpty
                      ? null
                      : OutlinedButton(
                          onPressed: _reset,
                          child: const Text('Clear filters'),
                        ),
                );
              }
              return Column(
                children: [
                  Expanded(
                    child: isWide(context)
                        ? _GrantTable(grants: page.items)
                        : _GrantCards(grants: page.items),
                  ),
                  Pager(
                    page: _page,
                    pageSize: widget.pageSize,
                    totalCount: page.totalCount,
                    onPage: (p) => _update(page: p),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Stand-alone page used for drill-down from funder, recipient, and place
/// views.
class FilteredGrantsPage extends StatelessWidget {
  const FilteredGrantsPage({
    super.key,
    required this.title,
    required this.filters,
  });

  final String title;
  final GrantFilters filters;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title, overflow: TextOverflow.ellipsis)),
    body: SafeArea(child: GrantExplorer(initialFilters: filters)),
  );
}

void openGrant(BuildContext context, Grant grant) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => GrantDetailPage(grant: grant)));

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.sort,
    required this.onSearch,
    required this.onSort,
    required this.onFilters,
  });

  final TextEditingController controller;
  final GrantSort sort;
  final ValueChanged<String> onSearch;
  final ValueChanged<GrantSort> onSort;
  final VoidCallback onFilters;

  @override
  Widget build(BuildContext context) {
    final search = TextField(
      controller: controller,
      onChanged: onSearch,
      textInputAction: TextInputAction.search,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: 'Search funder, recipient, or purpose',
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );
    final wide = isWide(context);
    final sortMenu = PopupMenuButton<GrantSort>(
      tooltip: 'Sort: ${sort.label}',
      initialValue: sort,
      onSelected: onSort,
      itemBuilder: (_) => [
        for (final s in GrantSort.values)
          PopupMenuItem(value: s, child: Text(s.label)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort),
            if (wide) ...[const SizedBox(width: 4), Text(sort.label)],
          ],
        ),
      ),
    );
    final filterButton = wide
        ? FilledButton.tonalIcon(
            onPressed: onFilters,
            icon: const Icon(Icons.filter_list),
            label: const Text('Filters'),
          )
        : IconButton.filledTonal(
            tooltip: 'Filters',
            onPressed: onFilters,
            icon: const Icon(Icons.filter_list),
          );
    return Row(
      children: [
        Expanded(child: search),
        SizedBox(width: wide ? 12 : 4),
        sortMenu,
        SizedBox(width: wide ? 8 : 0),
        filterButton,
      ],
    );
  }
}

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({
    required this.filters,
    required this.onChanged,
    required this.onReset,
  });

  final GrantFilters filters;
  final ValueChanged<GrantFilters> onChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (filters.funder != null)
        _chip(
          'Funder: ${filters.funder}',
          filters.copyWith(funder: () => null),
        ),
      if (filters.recipient != null)
        _chip(
          'Recipient: ${filters.recipient}',
          filters.copyWith(recipient: () => null),
        ),
      if (filters.city != null)
        _chip('City: ${filters.city}', filters.copyWith(city: () => null)),
      if (filters.zip != null)
        _chip('ZIP: ${filters.zip}', filters.copyWith(zip: () => null)),
      if (filters.taxYear != null)
        _chip(
          'Tax year: ${filters.taxYear}',
          filters.copyWith(taxYear: () => null),
        ),
      if (filters.minAmount != null)
        _chip(
          'Min ${formatUsd(filters.minAmount!)}',
          filters.copyWith(minAmount: () => null),
        ),
      if (filters.maxAmount != null)
        _chip(
          'Max ${formatUsd(filters.maxAmount!)}',
          filters.copyWith(maxAmount: () => null),
        ),
    ];
    if (chips.isEmpty) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...chips,
            TextButton(onPressed: onReset, child: const Text('Clear all')),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, GrantFilters without) => InputChip(
    label: Text(label, overflow: TextOverflow.ellipsis),
    onDeleted: () => onChanged(without),
  );
}

class _GrantCards extends StatelessWidget {
  const _GrantCards({required this.grants});

  final List<Grant> grants;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
    itemCount: grants.length,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (context, i) => _GrantCard(grant: grants[i]),
  );
}

class _GrantCard extends StatelessWidget {
  const _GrantCard({required this.grant});

  final Grant grant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final g = grant;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openGrant(context, g),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InitialsAvatar(g.recipient, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.recipient,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'From ${g.funder}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: muted,
                    ),
                    if (g.purpose != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        g.purpose!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            '${g.city}, ${g.state} ${g.zip} · ${g.taxYear}',
                            overflow: TextOverflow.ellipsis,
                            style: muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _AmountPill(g.amountUsd),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountPill extends StatelessWidget {
  const _AmountPill(this.amount);

  final int amount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        formatUsd(amount),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GrantTable extends StatelessWidget {
  const _GrantTable({required this.grants});

  final List<Grant> grants;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            showCheckboxColumn: false,
            headingRowColor: WidgetStatePropertyAll(
              theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
            ),
            headingTextStyle: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
            dataRowMinHeight: 56,
            dataRowMaxHeight: 64,
            columns: const [
              DataColumn(label: Text('Recipient')),
              DataColumn(label: Text('Funder')),
              DataColumn(label: Text('Purpose')),
              DataColumn(label: Text('Amount'), numeric: true),
              DataColumn(label: Text('Year'), numeric: true),
              DataColumn(label: Text('City')),
              DataColumn(label: Text('ZIP')),
            ],
            rows: [
              for (final g in grants)
                DataRow(
                  onSelectChanged: (_) => openGrant(context, g),
                  cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InitialsAvatar(g.recipient, size: 30),
                          const SizedBox(width: 10),
                          _clip(
                            g.recipient,
                            theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(_clip(g.funder)),
                    DataCell(_clip(g.purpose ?? '—')),
                    DataCell(
                      Text(
                        formatUsd(g.amountUsd),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    DataCell(Text('${g.taxYear}')),
                    DataCell(Text(g.city)),
                    DataCell(Text(g.zip)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _clip(String text, [TextStyle? style]) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 240),
    child: Text(text, overflow: TextOverflow.ellipsis, style: style),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initial,
    required this.options,
    required this.onRetryOptions,
  });

  final GrantFilters initial;
  final Future<FilterOptions> options;
  final VoidCallback onRetryOptions;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _city = widget.initial.city;
  late int? _taxYear = widget.initial.taxYear;
  late final _min = TextEditingController(
    text: widget.initial.minAmount?.toString() ?? '',
  );
  late final _max = TextEditingController(
    text: widget.initial.maxAmount?.toString() ?? '',
  );
  String? _amountError;

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _apply() {
    final min = int.tryParse(_min.text);
    final max = int.tryParse(_max.text);
    if (min != null && max != null && min > max) {
      setState(() => _amountError = 'Minimum must not exceed maximum.');
      return;
    }
    Navigator.of(context).pop(
      widget.initial.copyWith(
        city: () => _city,
        taxYear: () => _taxYear,
        minAmount: () => min,
        maxAmount: () => max,
      ),
    );
  }

  void _clear() => setState(() {
    _city = null;
    _taxYear = null;
    _min.clear();
    _max.clear();
    _amountError = null;
  });

  @override
  Widget build(BuildContext context) {
    Widget amountField(TextEditingController c, String label) => Expanded(
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          prefixText: r'$ ',
          border: const OutlineInputBorder(),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filters', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            FutureBuilder<FilterOptions>(
              future: widget.options,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError) {
                  return Row(
                    children: [
                      const Expanded(
                        child: Text('Filter choices could not be loaded.'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onRetryOptions();
                        },
                        child: const Text('Close'),
                      ),
                    ],
                  );
                }
                final o = snapshot.data!;
                return Column(
                  children: [
                    _dropdown<String>(
                      label: 'City',
                      value: _city,
                      items: o.cities,
                      text: (c) => c,
                      onChanged: (v) => setState(() => _city = v),
                    ),
                    const SizedBox(height: 12),
                    _dropdown<int>(
                      label: 'Tax year',
                      value: _taxYear,
                      items: o.taxYears,
                      text: (y) => '$y',
                      onChanged: (v) => setState(() => _taxYear = v),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                amountField(_min, 'Min amount'),
                const SizedBox(width: 12),
                amountField(_max, 'Max amount'),
              ],
            ),
            if (_amountError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _amountError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: _clear, child: const Text('Reset')),
                const SizedBox(width: 8),
                FilledButton(onPressed: _apply, child: const Text('Apply')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) text,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T?>(
      initialValue: items.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem<T?>(
          value: null,
          child: Text('Any ${label.toLowerCase()}'),
        ),
        for (final item in items)
          DropdownMenuItem<T?>(value: item, child: Text(text(item))),
      ],
      onChanged: onChanged,
    );
  }
}
