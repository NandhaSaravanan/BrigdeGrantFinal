import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:supabase/supabase.dart';

import 'models.dart';

/// Read-only access to the statewide South Carolina grant data
/// (`sc_grants_public` and `sc_aggregate` in supabase/sc_app_views.sql).
abstract class GrantsRepository {
  /// County every query is limited to, e.g. "York County"; null means all of
  /// South Carolina.
  String? county;

  /// Counties that have grants, statewide, for the county picker.
  Future<List<GrantAggregate>> fetchCounties();

  Future<ResultPage<Grant>> fetchGrants({
    required GrantFilters filters,
    required GrantSort sort,
    required int page,
    required int pageSize,
  });

  Future<List<GrantAggregate>> fetchTaxYears();

  /// One summary row across all tax years (the `grants_overview` view).
  Future<GrantAggregate> fetchOverview();

  Future<ResultPage<GrantAggregate>> fetchEntities({
    required EntityKind kind,
    required AggregateSort sort,
    String search = '',
    required int page,
    required int pageSize,
  });

  Future<List<GrantAggregate>> fetchPlaces({
    required PlaceKind kind,
    required AggregateSort sort,
  });

  Future<FilterOptions> fetchFilterOptions();

  /// Stores a help request. The table is insert-only for app users.
  Future<void> submitHelpRequest(HelpRequest request);

  /// Answers the last user question in [history] from the grant data.
  /// Throws [ChatException] when it cannot.
  Future<ChatMessage> askChat(List<ChatMessage> history);
}

class SupabaseGrantsRepository implements GrantsRepository {
  SupabaseGrantsRepository(this._client);

  final SupabaseClient _client;

  /// Random id for this app session, used only for the chat's daily limit.
  static final _deviceId = List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  @override
  Future<ResultPage<Grant>> fetchGrants({
    required GrantFilters filters,
    required GrantSort sort,
    required int page,
    required int pageSize,
  }) async {
    var query = _client.from('sc_grants_public').select();
    if (county != null) query = query.eq('county', county!);
    final search = sanitizeSearch(filters.search);
    if (search.isNotEmpty) {
      query = query.or(
        'funder.ilike.*$search*,recipient.ilike.*$search*,'
        'purpose.ilike.*$search*',
      );
    }
    if (filters.city != null) query = query.eq('city', filters.city!);
    if (filters.zip != null) query = query.eq('zip', filters.zip!);
    if (filters.taxYear != null) {
      query = query.eq('tax_year', filters.taxYear!);
    }
    if (filters.funder != null) query = query.eq('funder', filters.funder!);
    if (filters.recipient != null) {
      query = query.eq('recipient', filters.recipient!);
    }
    if (filters.minAmount != null) {
      query = query.gte('amount_usd', filters.minAmount!);
    }
    if (filters.maxAmount != null) {
      query = query.lte('amount_usd', filters.maxAmount!);
    }
    final from = page * pageSize;
    final response = await query
        .order(sort.column, ascending: sort.ascending)
        // Stable tie-breaker so pages never overlap.
        .order('id', ascending: true)
        .range(from, from + pageSize - 1)
        .count(CountOption.exact);
    return ResultPage(
      items: response.data.map(Grant.fromJson).toList(),
      totalCount: response.count,
    );
  }

  @override
  String? county;

  /// Grouped totals from `sc_aggregate` for the current [county].
  PostgrestFilterBuilder<List<Map<String, dynamic>>> _aggregate(
    String group, {
    bool statewide = false,
  }) => _client.rpc<List<Map<String, dynamic>>>(
    'sc_aggregate',
    params: {'p_group': group, 'p_county': statewide ? null : county},
  );

  static GrantAggregate _row(Map<String, dynamic> r) => GrantAggregate.fromJson(
    r,
    labelKey: 'label',
    secondaryKey: 'secondary_label',
  );

  @override
  Future<List<GrantAggregate>> fetchCounties() async {
    final rows = await _aggregate('county', statewide: true)
        .neq('label', 'Unknown or multiple counties')
        .order('label', ascending: true);
    return rows.map(_row).toList();
  }

  @override
  Future<List<GrantAggregate>> fetchTaxYears() async {
    final rows = await _aggregate('tax_year').order('label', ascending: false);
    return rows.map(_row).toList();
  }

  @override
  Future<GrantAggregate> fetchOverview() async {
    final row = await _aggregate('overview').maybeSingle();
    if (row == null) {
      return const GrantAggregate(
        label: 'All years',
        grantCount: 0,
        totalAmountUsd: 0,
      );
    }
    return _row(row);
  }

  @override
  Future<ResultPage<GrantAggregate>> fetchEntities({
    required EntityKind kind,
    required AggregateSort sort,
    String search = '',
    required int page,
    required int pageSize,
  }) async {
    var query = _aggregate(kind.group);
    final term = sanitizeSearch(search);
    if (term.isNotEmpty) query = query.ilike('label', '%$term%');
    final from = page * pageSize;
    final response = await query
        .order(_sortColumn(sort), ascending: false)
        .order('label', ascending: true)
        .order('secondary_label', ascending: true)
        .range(from, from + pageSize - 1)
        .count(CountOption.exact);
    return ResultPage(
      items: response.data.map(_row).toList(),
      totalCount: response.count,
    );
  }

  @override
  Future<List<GrantAggregate>> fetchPlaces({
    required PlaceKind kind,
    required AggregateSort sort,
  }) async {
    final rows = await _aggregate(kind.group)
        .order(_sortColumn(sort), ascending: false)
        .order('label', ascending: true)
        // Statewide there are hundreds of cities and ZIPs; the chart and
        // list only need the leaders.
        .limit(100);
    return rows.map(_row).toList();
  }

  @override
  Future<FilterOptions> fetchFilterOptions() async {
    final results = await Future.wait([
      _aggregate('city').order('label', ascending: true),
      _aggregate('tax_year').order('label', ascending: false),
    ]);
    return FilterOptions(
      cities: {for (final r in results[0]) r['label'].toString()}.toList(),
      taxYears: [
        for (final r in results[1]) ?int.tryParse(r['label'].toString()),
      ],
    );
  }

  @override
  Future<void> submitHelpRequest(HelpRequest request) =>
      // No `.select()`: anon may insert but not read help requests.
      _client.from('help_requests').insert(request.toJson());

  @override
  Future<ChatMessage> askChat(List<ChatMessage> history) async {
    final Map<String, dynamic> data;
    try {
      final response = await _client.functions.invoke(
        'grant-chat',
        headers: {'x-device-id': _deviceId},
        body: {
          'messages': history.map((m) => m.toJson()).toList(),
          'county': ?county,
        },
      );
      data = Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (e) {
      final details = e.details;
      throw ChatException(
        ChatProblem.fromCode(details is Map ? details['error'] : null),
      );
    } on ChatException {
      rethrow;
    } catch (_) {
      throw const ChatException(ChatProblem.failed);
    }
    return ChatMessage.assistant(
      data['answer']?.toString() ?? '',
      grants: [
        for (final g in (data['grants'] as List? ?? const []))
          Grant.fromJson(Map<String, dynamic>.from(g as Map)),
      ],
    );
  }

  static String _sortColumn(AggregateSort sort) =>
      sort == AggregateSort.amount ? 'total_amount_usd' : 'grant_count';
}

/// Makes the repository available to the widget tree.
class GrantsScope extends InheritedWidget {
  const GrantsScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final GrantsRepository repository;

  static GrantsRepository of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GrantsScope>()!.repository;

  @override
  bool updateShouldNotify(GrantsScope oldWidget) =>
      repository != oldWidget.repository;
}
