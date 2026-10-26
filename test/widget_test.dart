import 'package:bridgegrant/src/app.dart';
import 'package:bridgegrant/src/design.dart';
import 'package:bridgegrant/src/models.dart';
import 'package:bridgegrant/src/pages/grant_detail_page.dart';
import 'package:bridgegrant/src/repository.dart';
import 'package:bridgegrant/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_repository.dart';

Future<void> _pumpApp(
  WidgetTester tester,
  GrantsRepository repo, {
  Size size = const Size(400, 800),
  AppDesign design = AppDesign.light,
  bool chatEnabled = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    BridgeGrantApp(
      repository: repo,
      initialDesign: design,
      chatEnabled: chatEnabled,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  final grants = [
    fakeGrant(1, amount: 40000),
    fakeGrant(2, city: 'Fort Mill', amount: 5000),
    fakeGrant(3, funder: 'Other Fund'),
  ];

  testWidgets('opens on the dashboard', (tester) async {
    await _pumpApp(tester, FakeGrantsRepository(grants));
    expect(find.text('BRIDGEGRANT'), findsOneWidget);
    expect(find.text('Source-matched IRS filings'), findsOneWidget);
    expect(find.text('Reported dollars'), findsOneWidget);
    expect(find.text(r'$60,000'), findsOneWidget);
    expect(find.textContaining('confirmed York County grants'), findsNothing);
  });

  testWidgets('grant list shows records and opens source details', (
    tester,
  ) async {
    await _pumpApp(tester, FakeGrantsRepository(grants));
    await _openTab(tester, 'Explore');
    expect(find.text('Recipient 1'), findsOneWidget);
    expect(find.text('1–3 of 3'), findsOneWidget);

    await tester.tap(find.text('Recipient 1'));
    await tester.pumpAndSettle();
    expect(find.text('Grant record'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Open source filing (XML)'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(GrantDetailPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Filing ID'), findsOneWidget);
    expect(
      find.textContaining(
        RegExp('verif|independently confirmed', caseSensitive: false),
      ),
      findsNothing,
    );
    expect(find.text('Open source filing (XML)'), findsOneWidget);
  });

  testWidgets('search narrows results and shows an empty state', (
    tester,
  ) async {
    final repo = FakeGrantsRepository(grants);
    await _pumpApp(tester, repo);
    await _openTab(tester, 'Explore');

    await tester.enterText(find.byType(TextField).first, 'other');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(repo.lastFilters?.search, 'other');
    expect(find.text('Recipient 3'), findsOneWidget);
    expect(find.text('Recipient 1'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'zzz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('No matching records'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Recipient 1'), findsOneWidget);
  });

  testWidgets('amount filters are applied from the filter sheet', (
    tester,
  ) async {
    final repo = FakeGrantsRepository(grants);
    await _pumpApp(tester, repo);
    await _openTab(tester, 'Explore');

    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Min amount'),
      '10000',
    );
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(repo.lastFilters?.minAmount, 10000);
    expect(find.text(r'Min $10,000'), findsOneWidget);
    expect(find.text('Recipient 2'), findsNothing);
  });

  testWidgets('shows an error state with retry', (tester) async {
    final repo = FakeGrantsRepository(grants, error: Exception('boom'));
    await _pumpApp(tester, repo);
    expect(find.text('Could not load grant data'), findsOneWidget);

    repo.error = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Reported dollars'), findsOneWidget);
  });

  testWidgets('funder drill-down filters grants by funder', (tester) async {
    final repo = FakeGrantsRepository(grants);
    await _pumpApp(tester, repo);
    await _openTab(tester, 'Explore');
    await tester.tap(find.text('Funders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Example Foundation'));
    await tester.pumpAndSettle();
    expect(repo.lastFilters?.funder, 'Example Foundation');
    expect(find.text('Funder: Example Foundation'), findsOneWidget);
    expect(find.text('Recipient 3'), findsNothing);
  });

  testWidgets('uses a navigation rail and table on wide screens', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      FakeGrantsRepository(grants),
      size: const Size(1280, 900),
    );
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await _openTab(tester, 'Explore');
    expect(find.byType(DataTable), findsOneWidget);
  });

  testWidgets('dashboard empty state when no records exist', (tester) async {
    await _pumpApp(tester, FakeGrantsRepository(const <Grant>[]));
    expect(find.text('No matching records'), findsOneWidget);
  });

  testWidgets('config error screen explains required dart-defines', (
    tester,
  ) async {
    await tester.pumpWidget(const ConfigErrorApp(problem: 'Missing config.'));
    expect(find.textContaining('SUPABASE_ANON_KEY'), findsOneWidget);
  });

  testWidgets('dashboard links open the matching explore list', (tester) async {
    await _pumpApp(tester, FakeGrantsRepository(grants));
    await tester.scrollUntilVisible(find.text('Top recipients by amount'), 200);
    await tester.tap(find.text('All 1').last);
    await tester.pumpAndSettle();
    expect(find.text('Search recipient name'), findsOneWidget);
  });

  testWidgets('no verification wording anywhere', (tester) async {
    final noVerification = find.textContaining(
      RegExp('verif|independently confirmed', caseSensitive: false),
    );
    await _pumpApp(tester, FakeGrantsRepository(grants));
    expect(noVerification, findsNothing);
    for (final tab in ['Explore', 'Places', 'Help']) {
      await _openTab(tester, tab);
      expect(noVerification, findsNothing, reason: tab);
    }
    await _openTab(tester, 'Explore');
    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
    expect(noVerification, findsNothing, reason: 'filter sheet');
  });

  testWidgets('explore switches between grants, funders, and recipients', (
    tester,
  ) async {
    await _pumpApp(tester, FakeGrantsRepository(grants));
    await _openTab(tester, 'Explore');
    expect(find.text('Search funder, recipient, or purpose'), findsOneWidget);
    await tester.tap(find.text('Funders'));
    await tester.pumpAndSettle();
    expect(find.text('Search funder name'), findsOneWidget);
    await tester.tap(find.text('Recipients'));
    await tester.pumpAndSettle();
    expect(find.text('Search recipient name'), findsOneWidget);
  });

  testWidgets('help form validates and submits a request', (tester) async {
    final repo = FakeGrantsRepository(grants);
    await _pumpApp(tester, repo, size: const Size(400, 3000));
    await _openTab(tester, 'Help');
    await tester.tap(find.text('Request help'));
    await tester.pumpAndSettle();

    Future<void> send() async {
      await tester.ensureVisible(find.text('Send request'));
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
    }

    await send();
    expect(find.text('Enter your name.'), findsOneWidget);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Choose at least one kind of help.'), findsOneWidget);
    expect(repo.helpRequests, isEmpty);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name *'),
      'Jordan Lee',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email *'),
      'jordan@example.org',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone'),
      '(803) 555-0100',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nonprofit name'),
      'Rock Hill Reads',
    );
    await tester.ensureVisible(find.text('Grant writing'));
    await tester.tap(find.text('Grant writing'));
    await tester.tap(find.text('Starting a nonprofit'));
    await tester.pump();
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await send();

    expect(repo.helpRequests, hasLength(1));
    final json = repo.helpRequests.single.toJson();
    expect(json['full_name'], 'Jordan Lee');
    expect(json['npo_name'], 'Rock Hill Reads');
    expect(json['help_types'], ['start_nonprofit', 'grant_writing']);
    expect(json['message'], isNull);
    expect(find.text('Thank you!'), findsOneWidget);
  });

  testWidgets('light mode is Mint and both modes share the flat layout', (
    tester,
  ) async {
    await _pumpApp(tester, FakeGrantsRepository(grants));
    ThemeData theme() => Theme.of(tester.element(find.byType(HomeShell)));
    expect(theme().scaffoldBackgroundColor, Mint.background);
    expect(theme().brightness, Brightness.light);

    expect(theme().extension<BrandStyle>()?.flat, isTrue);
    expect(find.text('BRIDGEGRANT'), findsOneWidget);

    await tester.tap(find.byTooltip('Switch to dark mode'));
    await tester.pumpAndSettle();
    expect(theme().brightness, Brightness.dark);
    expect(theme().extension<BrandStyle>()?.flat, isTrue);
    expect(find.text('Reported dollars'), findsOneWidget);
    expect(find.byType(HomeShell), findsOneWidget);

    await tester.tap(find.byTooltip('Switch to light mode'));
    await tester.pumpAndSettle();
    expect(theme().scaffoldBackgroundColor, Mint.background);
  });

  testWidgets('light (Mint) mode uses dark text on its light hero', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      FakeGrantsRepository(grants),
      design: AppDesign.light,
    );
    final amount = tester.widget<Text>(find.text(r'$60,000'));
    expect(amount.style?.color, Mint.ink);
    expect(
      tester.widget<Text>(find.text('Source-matched IRS filings')).style?.color,
      Mint.ink,
    );
  });

  for (final design in AppDesign.values) {
    testWidgets('places chart highlights the tapped bar (${design.label})', (
      tester,
    ) async {
      await _pumpApp(tester, FakeGrantsRepository(grants), design: design);
      await _openTab(tester, 'Places');
      expect(find.text('Grant dollars by city'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Rock Hill: ')), findsOneWidget);
      await tester.tap(find.text('Count'));
      await tester.pumpAndSettle();
      expect(find.text('Grants by city'), findsOneWidget);
    });
  }

  testWidgets('home tax-year picker switches totals', (tester) async {
    await _pumpApp(
      tester,
      FakeGrantsRepository([
        fakeGrant(1, amount: 40000),
        fakeGrant(2, amount: 5000, taxYear: 2025),
        fakeGrant(3, amount: 15000, taxYear: 2025),
      ]),
      size: const Size(400, 2000),
    );
    expect(find.text(r'$60,000'), findsOneWidget);
    expect(find.text('Tax years 2024–2025'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '2025'));
    await tester.pumpAndSettle();
    expect(find.text(r'$20,000'), findsOneWidget);
    expect(find.text('Tax year 2025'), findsOneWidget);
    expect(
      find.text('Places, funders, and recipients below include all tax years.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'All years'));
    await tester.pumpAndSettle();
    expect(find.text(r'$60,000'), findsOneWidget);
  });

  testWidgets('single tax year hides the picker', (tester) async {
    await _pumpApp(tester, FakeGrantsRepository(grants));
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Tax year 2024'), findsOneWidget);
  });

  testWidgets('grant purpose is searchable and shown in details', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      FakeGrantsRepository([
        fakeGrant(1),
        fakeGrant(2, purpose: 'ROOF REPLACEMENT'),
      ]),
    );
    await _openTab(tester, 'Explore');
    await tester.enterText(find.byType(TextField).first, 'roof');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Recipient 2'), findsOneWidget);
    expect(find.text('Recipient 1'), findsNothing);
    expect(find.text('ROOF REPLACEMENT'), findsOneWidget);

    await tester.tap(find.text('Recipient 2'));
    await tester.pumpAndSettle();
    expect(find.text('Purpose'), findsOneWidget);
  });

  testWidgets('ask tab answers a question and links the records used', (
    tester,
  ) async {
    final repo = FakeGrantsRepository(grants)
      ..chatReply = ChatMessage.assistant(
        'Example Foundation gave the most.',
        grants: [grants.first],
      );
    await _pumpApp(tester, repo);
    await _openTab(tester, 'Ask');
    expect(find.text('Ask the grant data'), findsOneWidget);

    await tester.tap(find.text('Which funders gave the most in Fort Mill?'));
    await tester.pumpAndSettle();
    expect(repo.chatHistories.single.single.text, contains('Fort Mill'));
    expect(find.text('Example Foundation gave the most.'), findsOneWidget);
    expect(find.text('Records used'), findsOneWidget);

    await tester.tap(find.text('Recipient 1'));
    await tester.pumpAndSettle();
    expect(find.byType(GrantDetailPage), findsOneWidget);
  });

  testWidgets('ask tab explains when chat billing is not set up', (
    tester,
  ) async {
    final repo = FakeGrantsRepository(grants)
      ..chatReply = const ChatException(ChatProblem.billing);
    await _pumpApp(tester, repo);
    await _openTab(tester, 'Ask');
    await tester.enterText(find.byType(TextField), 'Who funds literacy?');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Who funds literacy?'), findsOneWidget);
    expect(find.text(ChatProblem.billing.message), findsOneWidget);
  });

  testWidgets('Android hides the Ask tab', (tester) async {
    // flutter_test runs as Android by default, so this uses the real default.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      BridgeGrantApp(
        repository: FakeGrantsRepository(grants),
        initialDesign: AppDesign.light,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ask'), findsNothing);
    await _openTab(tester, 'Places');
    expect(find.text('Grant dollars by city'), findsOneWidget);
    await _openTab(tester, 'Help');
    expect(find.byType(HomeShell), findsOneWidget);
  });

  testWidgets('county picker limits the data to one county', (tester) async {
    final repo = FakeGrantsRepository([
      fakeGrant(1, amount: 40000),
      fakeGrant(2, amount: 5000),
      fakeGrant(
        3,
        city: 'Greenville',
        county: 'Greenville County',
        amount: 7000,
      ),
    ]);
    await _pumpApp(tester, repo);
    expect(find.text(r'$52,000'), findsOneWidget);

    await tester.tap(find.text('All SC'));
    await tester.pumpAndSettle();
    expect(find.text('All of South Carolina'), findsOneWidget);
    await tester.tap(find.text('Greenville County'));
    await tester.pumpAndSettle();

    expect(repo.county, 'Greenville County');
    expect(find.text('Greenville'), findsWidgets);
    expect(find.text(r'$7,000'), findsWidgets);
    expect(find.text(r'$52,000'), findsNothing);

    await tester.tap(find.text('Greenville').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('All of South Carolina'));
    await tester.pumpAndSettle();
    expect(repo.county, isNull);
    expect(find.text(r'$52,000'), findsOneWidget);
  });
}
