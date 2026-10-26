import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../repository.dart';
import '../widgets.dart';
import 'grants_page.dart';

/// Ranked funders or recipients with search, sort, and pagination.
class EntitiesPage extends StatefulWidget {
  const EntitiesPage({super.key, required this.kind, this.pageSize = 20});

  final EntityKind kind;
  final int pageSize;

  @override
  State<EntitiesPage> createState() => _EntitiesPageState();
}

class _EntitiesPageState extends State<EntitiesPage> {
  bool _byAmount = true;
  String _search = '';
  int _page = 0;
  Future<ResultPage<GrantAggregate>>? _future;
  Timer? _debounce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<ResultPage<GrantAggregate>> _load() =>
      GrantsScope.of(context).fetchEntities(
        kind: widget.kind,
        sort: _byAmount ? AggregateSort.amount : AggregateSort.count,
        search: _search,
        page: _page,
        pageSize: widget.pageSize,
      );

  void _reload({int page = 0}) => setState(() {
    _page = page;
    _future = _load();
  });

  void _open(GrantAggregate row) {
    final filters = widget.kind == EntityKind.funder
        ? GrantFilters(funder: row.label)
        : GrantFilters(recipient: row.label);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FilteredGrantsPage(title: row.label, filters: filters),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final noun = widget.kind == EntityKind.funder ? 'funder' : 'recipient';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: isWide(context) ? 420 : double.infinity,
                    child: TextField(
                      onChanged: (v) {
                        _debounce?.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 350),
                          () {
                            if (!mounted) return;
                            _search = v;
                            _reload();
                          },
                        );
                      },
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Search $noun name',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
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
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<ResultPage<GrantAggregate>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LoadingView();
              }
              if (snapshot.hasError) {
                return ErrorView(
                  error: snapshot.error!,
                  onRetry: () => _reload(page: _page),
                );
              }
              final page = snapshot.data!;
              if (page.items.isEmpty) {
                return EmptyView(message: 'No ${noun}s match this search.');
              }
              final max = _byAmount
                  ? page.items.first.totalAmountUsd
                  : page.items.first.grantCount;
              return Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: page.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final row = page.items[i];
                        final others = widget.kind == EntityKind.funder
                            ? '${formatCount(row.recipientCount ?? 0)} recipients'
                            : '${formatCount(row.funderCount ?? 0)} funders';
                        final bar = BarRow(
                          rank: _page * widget.pageSize + i + 1,
                          label: row.label,
                          subtitle:
                              '${formatCount(row.grantCount)} grants · '
                              'avg ${formatUsdCompact(row.averageAmountUsd ?? 0)}'
                              ' · $others · EIN ${row.secondaryLabel}',
                          valueLabel: _byAmount
                              ? formatUsdCompact(row.totalAmountUsd)
                              : formatCount(row.grantCount),
                          value: _byAmount
                              ? row.totalAmountUsd
                              : row.grantCount,
                          // Relative to the top of the overall ranking on
                          // page one; later pages use their own top row.
                          max: max,
                          onTap: () => _open(row),
                        );
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: InitialsAvatar(row.label, size: 36),
                                ),
                                Expanded(child: bar),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Pager(
                    page: _page,
                    pageSize: widget.pageSize,
                    totalCount: page.totalCount,
                    onPage: (p) => _reload(page: p),
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
