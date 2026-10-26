import 'package:bridgegrant/src/models.dart';
import 'package:bridgegrant/src/repository.dart';

Grant fakeGrant(
  int i, {
  String funder = 'Example Foundation',
  String city = 'Rock Hill',
  String? county = 'York County',
  int amount = 15000,
  int taxYear = 2024,
  String? purpose,
}) => Grant(
  id: 'g$i',
  funder: funder,
  recipient: 'Recipient $i',
  amountUsd: amount,
  taxYear: taxYear,
  city: city,
  state: 'SC',
  zip: '29730',
  filingId: 'OID-$i',
  filingUrl: 'https://example.org/$i.xml',
  source: 'Schedule I',
  matchEvidence: 'Exact filing ID + recipient name + city',
  purpose: purpose,
  county: county,
);

/// In-memory repository applying the same filter semantics as Supabase.
class FakeGrantsRepository implements GrantsRepository {
  FakeGrantsRepository(List<Grant> grants, {this.error}) : _all = grants;

  final List<Grant> _all;

  @override
  String? county;

  /// Grants in the current [county] (all of them when statewide).
  List<Grant> get grants =>
      county == null ? _all : _all.where((g) => g.county == county).toList();
  Object? error;
  GrantFilters? lastFilters;
  final helpRequests = <HelpRequest>[];

  /// What [askChat] returns, or throws when it is a [ChatException].
  Object chatReply = const ChatMessage.assistant('Example answer.');
  final chatHistories = <List<ChatMessage>>[];

  Future<T> _result<T>(T value) async {
    if (error != null) throw error!;
    return value;
  }

  @override
  Future<ResultPage<Grant>> fetchGrants({
    required GrantFilters filters,
    required GrantSort sort,
    required int page,
    required int pageSize,
  }) {
    lastFilters = filters;
    final q = filters.search.toLowerCase();
    final rows = grants.where((g) {
      if (q.isNotEmpty &&
          !g.funder.toLowerCase().contains(q) &&
          !g.recipient.toLowerCase().contains(q) &&
          !(g.purpose?.toLowerCase().contains(q) ?? false)) {
        return false;
      }
      if (filters.city != null && g.city != filters.city) return false;
      if (filters.funder != null && g.funder != filters.funder) return false;
      if (filters.minAmount != null && g.amountUsd < filters.minAmount!) {
        return false;
      }
      if (filters.maxAmount != null && g.amountUsd > filters.maxAmount!) {
        return false;
      }
      return true;
    }).toList();
    final start = (page * pageSize).clamp(0, rows.length);
    final end = (start + pageSize).clamp(0, rows.length);
    return _result(
      ResultPage(items: rows.sublist(start, end), totalCount: rows.length),
    );
  }

  GrantAggregate _summary(String label, Iterable<Grant> rows) => GrantAggregate(
    label: label,
    grantCount: rows.length,
    totalAmountUsd: rows.fold<int>(0, (s, g) => s + g.amountUsd),
    averageAmountUsd: 15000,
    medianAmountUsd: 15000,
    funderCount: rows.map((g) => g.funder).toSet().length,
    recipientCount: rows.map((g) => g.recipient).toSet().length,
  );

  @override
  Future<List<GrantAggregate>> fetchCounties() {
    final names = _all.map((g) => g.county).whereType<String>().toSet().toList()
      ..sort();
    return _result([
      for (final c in names) _summary(c, _all.where((g) => g.county == c)),
    ]);
  }

  @override
  Future<List<GrantAggregate>> fetchTaxYears() {
    final years = grants.map((g) => g.taxYear).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    return _result([
      for (final y in years)
        _summary('$y', grants.where((g) => g.taxYear == y)),
    ]);
  }

  @override
  Future<GrantAggregate> fetchOverview() =>
      _result(_summary('All years', grants));

  @override
  Future<ResultPage<GrantAggregate>> fetchEntities({
    required EntityKind kind,
    required AggregateSort sort,
    String search = '',
    required int page,
    required int pageSize,
  }) => _result(
    const ResultPage(
      items: [
        GrantAggregate(
          label: 'Example Foundation',
          secondaryLabel: '123456789',
          grantCount: 3,
          totalAmountUsd: 45000,
          averageAmountUsd: 15000,
          recipientCount: 3,
          funderCount: 1,
        ),
      ],
      totalCount: 1,
    ),
  );

  @override
  Future<List<GrantAggregate>> fetchPlaces({
    required PlaceKind kind,
    required AggregateSort sort,
  }) => _result(const [
    GrantAggregate(
      label: 'Rock Hill',
      secondaryLabel: 'SC',
      grantCount: 3,
      totalAmountUsd: 45000,
    ),
  ]);

  @override
  Future<FilterOptions> fetchFilterOptions() => _result(
    const FilterOptions(cities: ['Fort Mill', 'Rock Hill'], taxYears: [2024]),
  );

  @override
  Future<void> submitHelpRequest(HelpRequest request) async {
    if (error != null) throw error!;
    helpRequests.add(request);
  }

  @override
  Future<ChatMessage> askChat(List<ChatMessage> history) async {
    chatHistories.add(history);
    final reply = chatReply;
    if (reply is ChatException) throw reply;
    return reply as ChatMessage;
  }
}
