num _num(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value) ?? 0;
  return 0;
}

int _int(Object? value) => _num(value).round();

String _str(Object? value) => value?.toString() ?? '';

String? _optStr(Object? value) {
  final s = value?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}

/// One row of the `sc_grants_public` view.
class Grant {
  const Grant({
    required this.id,
    required this.funder,
    required this.recipient,
    required this.amountUsd,
    required this.taxYear,
    required this.city,
    required this.state,
    required this.zip,
    required this.filingId,
    required this.filingUrl,
    required this.source,
    required this.matchEvidence,
    this.purpose,
    this.county,
  });

  factory Grant.fromJson(Map<String, dynamic> json) => Grant(
    id: _str(json['id']),
    funder: _str(json['funder']),
    recipient: _str(json['recipient']),
    amountUsd: _int(json['amount_usd']),
    taxYear: _int(json['tax_year']),
    city: _str(json['city']),
    state: _str(json['state']),
    zip: _str(json['zip']),
    filingId: _str(json['filing_id']),
    filingUrl: _str(json['filing_url']),
    source: _str(json['source']),
    matchEvidence: _str(json['match_evidence']),
    purpose: _optStr(json['purpose']),
    county: _optStr(json['county']),
  );

  final String id;

  /// Recipient's county from its ZIP code; null when the ZIP crosses county
  /// lines or isn't a Census ZIP area (e.g. a PO box).
  final String? county;
  final String funder;
  final String recipient;
  final int amountUsd;
  final int taxYear;
  final String city;
  final String state;
  final String zip;
  final String filingId;
  final String filingUrl;
  final String source;
  final String matchEvidence;

  /// Purpose of the grant as written in the filing, when reported.
  final String? purpose;
}

/// A grouped row from one of the aggregate views. Fields a view does not
/// provide are null.
class GrantAggregate {
  const GrantAggregate({
    required this.label,
    this.secondaryLabel,
    required this.grantCount,
    required this.totalAmountUsd,
    this.averageAmountUsd,
    this.medianAmountUsd,
    this.funderCount,
    this.recipientCount,
  });

  factory GrantAggregate.fromJson(
    Map<String, dynamic> json, {
    required String labelKey,
    String? secondaryKey,
  }) => GrantAggregate(
    label: _str(json[labelKey]),
    secondaryLabel: secondaryKey == null ? null : _str(json[secondaryKey]),
    grantCount: _int(json['grant_count']),
    totalAmountUsd: _num(json['total_amount_usd']),
    averageAmountUsd: json['average_amount_usd'] == null
        ? null
        : _num(json['average_amount_usd']),
    medianAmountUsd: json['median_amount_usd'] == null
        ? null
        : _num(json['median_amount_usd']),
    funderCount: json['funder_count'] == null
        ? null
        : _int(json['funder_count']),
    recipientCount: json['recipient_count'] == null
        ? null
        : _int(json['recipient_count']),
  );

  final String label;
  final String? secondaryLabel;
  final int grantCount;
  final num totalAmountUsd;
  final num? averageAmountUsd;
  final num? medianAmountUsd;
  final int? funderCount;
  final int? recipientCount;
}

enum GrantSort {
  amountDesc('Amount: high to low', 'amount_usd', false),
  amountAsc('Amount: low to high', 'amount_usd', true),
  funder('Funder A–Z', 'funder', true),
  recipient('Recipient A–Z', 'recipient', true),
  city('City A–Z', 'city', true),
  taxYearDesc('Tax year: newest', 'tax_year', false);

  const GrantSort(this.label, this.column, this.ascending);

  final String label;
  final String column;
  final bool ascending;
}

/// Filters applied to the `grants_public` query.
class GrantFilters {
  const GrantFilters({
    this.search = '',
    this.city,
    this.zip,
    this.taxYear,
    this.funder,
    this.recipient,
    this.minAmount,
    this.maxAmount,
  });

  final String search;
  final String? city;
  final String? zip;
  final int? taxYear;

  /// Exact funder name, used for drill-down from the funder view.
  final String? funder;

  /// Exact recipient name, used for drill-down from the recipient view.
  final String? recipient;
  final int? minAmount;
  final int? maxAmount;

  bool get isEmpty =>
      search.trim().isEmpty &&
      city == null &&
      zip == null &&
      taxYear == null &&
      funder == null &&
      recipient == null &&
      minAmount == null &&
      maxAmount == null;

  GrantFilters copyWith({
    String? search,
    String? Function()? city,
    String? Function()? zip,
    int? Function()? taxYear,
    String? Function()? funder,
    String? Function()? recipient,
    int? Function()? minAmount,
    int? Function()? maxAmount,
  }) => GrantFilters(
    search: search ?? this.search,
    city: city == null ? this.city : city(),
    zip: zip == null ? this.zip : zip(),
    taxYear: taxYear == null ? this.taxYear : taxYear(),
    funder: funder == null ? this.funder : funder(),
    recipient: recipient == null ? this.recipient : recipient(),
    minAmount: minAmount == null ? this.minAmount : minAmount(),
    maxAmount: maxAmount == null ? this.maxAmount : maxAmount(),
  );
}

/// Removes characters that carry meaning in PostgREST filter syntax so user
/// search text cannot alter the query structure.
String sanitizeSearch(String input) =>
    input.replaceAll(RegExp(r'[,()*%\\:."]'), ' ').trim();

class ResultPage<T> {
  const ResultPage({required this.items, required this.totalCount});

  final List<T> items;
  final int totalCount;
}

/// Values used to populate filter dropdowns.
class FilterOptions {
  const FilterOptions({required this.cities, required this.taxYears});

  final List<String> cities;
  final List<int> taxYears;
}

enum EntityKind {
  funder('Funders', 'funder'),
  recipient('Recipients', 'recipient');

  const EntityKind(this.title, this.group);

  final String title;

  /// `p_group` for the `sc_aggregate` function.
  final String group;
}

enum PlaceKind {
  city('city'),
  zip('zip');

  const PlaceKind(this.group);

  /// `p_group` for the `sc_aggregate` function.
  final String group;
}

/// Tax years NCCS is still filling in as late returns arrive.
const partialTaxYears = {2024, 2025};

enum AggregateSort { amount, count }

/// Top-level sections of the app shell.
enum AppTab { home, explore, ask, places, help }

/// Lists available inside the Explore tab.
enum ExploreView { grants, funders, recipients }

/// Switches the app shell to [tab]; [view] picks the Explore list.
typedef NavigateTo = void Function(AppTab tab, {ExploreView? view});

/// Kinds of help a visitor can request. Keys must match the
/// `help_requests_help_types_check` constraint in
/// `supabase/help_requests.sql`.
const helpTypeOptions = {
  'start_nonprofit': 'Starting a nonprofit',
  'tax_exempt_status': '501(c)(3) application',
  'find_funders': 'Finding grants & funders',
  'grant_writing': 'Grant writing',
  'board_governance': 'Board & governance',
  'fundraising': 'Fundraising & donors',
  'volunteers': 'Volunteers',
  'mentorship': 'Mentorship',
  'other': 'Something else',
};

/// Where the organization is today. Keys must match the
/// `help_requests_stage_check` constraint.
const stageOptions = {
  'idea': 'Just an idea',
  'forming': 'Forming / incorporating',
  'applying': 'Applying for tax-exempt status',
  'established': 'Established nonprofit',
};

/// A submission from the help request form.
class HelpRequest {
  const HelpRequest({
    required this.fullName,
    required this.email,
    this.phone,
    this.npoName,
    this.stage,
    required this.helpTypes,
    this.message,
  });

  final String fullName;
  final String email;
  final String? phone;
  final String? npoName;
  final String? stage;
  final List<String> helpTypes;
  final String? message;

  Map<String, dynamic> toJson() => {
    'full_name': fullName.trim(),
    'email': email.trim(),
    'phone': _blankToNull(phone),
    'npo_name': _blankToNull(npoName),
    'stage': stage,
    'help_types': helpTypes,
    'message': _blankToNull(message),
    'consent': true,
  };

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isValidEmail(String value) => _emailPattern.hasMatch(value.trim());

/// Accepts common phone formats with 7–15 digits.
bool isValidPhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return RegExp(r'^[0-9+()\-.\s]+$').hasMatch(value.trim()) &&
      digits.length >= 7 &&
      digits.length <= 15;
}

/// One turn in the Ask tab conversation.
class ChatMessage {
  const ChatMessage.user(this.text) : fromUser = true, grants = const [];

  const ChatMessage.assistant(this.text, {this.grants = const []})
    : fromUser = false;

  final bool fromUser;
  final String text;

  /// Grant records the answer was based on.
  final List<Grant> grants;

  Map<String, dynamic> toJson() => {
    'role': fromUser ? 'user' : 'assistant',
    'content': text,
  };
}

/// Why a chat question could not be answered.
enum ChatProblem {
  /// The OpenAI key is missing or invalid on the server.
  notConfigured('The assistant is not set up yet. Please try again later.'),

  /// The OpenAI account needs billing or has run out of credit.
  billing(
    'The assistant is unavailable: its OpenAI account needs billing set up '
    'or more credit.',
  ),

  rateLimited(
    "You've reached today's question limit. Please try again tomorrow.",
  ),
  failed('Something went wrong while answering. Please try again.');

  const ChatProblem(this.message);

  final String message;

  static ChatProblem fromCode(Object? code) => switch (code) {
    'not_configured' => notConfigured,
    'billing' => billing,
    'rate_limited' => rateLimited,
    _ => failed,
  };
}

class ChatException implements Exception {
  const ChatException(this.problem);

  final ChatProblem problem;

  @override
  String toString() => 'ChatException(${problem.name})';
}
