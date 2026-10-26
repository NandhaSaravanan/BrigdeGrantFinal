import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'design.dart';
import 'models.dart';
import 'pages/chat_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/explore_page.dart';
import 'pages/help_page.dart';
import 'pages/places_page.dart';
import 'repository.dart';
import 'theme.dart';
import 'widgets.dart';

class BridgeGrantApp extends StatefulWidget {
  const BridgeGrantApp({
    super.key,
    required this.repository,
    this.initialDesign,
    this.chatEnabled,
  });

  final GrantsRepository repository;

  /// Starting mode; follows the device's light/dark setting when null.
  final AppDesign? initialDesign;

  /// Shows the Ask (chat) tab. Defaults to every platform except Android.
  final bool? chatEnabled;

  @override
  State<BridgeGrantApp> createState() => _BridgeGrantAppState();
}

class _BridgeGrantAppState extends State<BridgeGrantApp> {
  late final _design = DesignController(
    widget.initialDesign ?? AppDesign.fromSystem(),
  );

  @override
  void dispose() {
    _design.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GrantsScope(
    repository: widget.repository,
    child: DesignScope(
      controller: _design,
      child: ValueListenableBuilder<AppDesign>(
        valueListenable: _design,
        builder: (context, design, _) {
          return MaterialApp(
            title: 'BridgeGrant',
            debugShowCheckedModeBanner: false,
            // Both modes use the flat metric-grid layout: Mint colors in
            // light mode, the dark navy colors in dark mode.
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: design == AppDesign.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            home: HomeShell(
              chatEnabled:
                  widget.chatEnabled ??
                  defaultTargetPlatform != TargetPlatform.android,
            ),
          );
        },
      ),
    ),
  );
}

class _Destination {
  const _Destination(this.tab, this.label, this.icon, this.selectedIcon);

  final AppTab tab;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

// Short one-word labels so the tabs fit on small phones.
const _destinations = [
  _Destination(AppTab.home, 'Home', Icons.home_outlined, Icons.home),
  _Destination(
    AppTab.explore,
    'Explore',
    Icons.travel_explore,
    Icons.travel_explore,
  ),
  _Destination(AppTab.ask, 'Ask', Icons.chat_bubble_outline, Icons.chat_bubble),
  _Destination(AppTab.places, 'Places', Icons.place_outlined, Icons.place),
  _Destination(
    AppTab.help,
    'Help',
    Icons.volunteer_activism_outlined,
    Icons.volunteer_activism,
  ),
];

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.chatEnabled = true});

  /// Whether the Ask tab is shown.
  final bool chatEnabled;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  AppTab _tab = AppTab.home;
  ExploreView _exploreView = ExploreView.grants;

  /// County the data is limited to; null is all of South Carolina.
  String? _county;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _county = GrantsScope.of(context).county;
  }

  Future<void> _pickCounty() async {
    final repository = GrantsScope.of(context);
    final choice = await showModalBottomSheet<(String?,)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          CountySheet(current: _county, counties: repository.fetchCounties()),
    );
    if (choice == null || choice.$1 == _county) return;
    repository.county = choice.$1;
    setState(() => _county = choice.$1);
  }

  void _navigate(AppTab tab, {ExploreView? view}) => setState(() {
    _tab = tab;
    if (view != null) _exploreView = view;
  });

  List<_Destination> get _tabs => [
    for (final d in _destinations)
      if (widget.chatEnabled || d.tab != AppTab.ask) d,
  ];

  void _select(int i) => _navigate(_tabs[i].tab);

  /// Pages showing grant data are rebuilt (and reload) when the county
  /// changes; the Ask tab keeps its conversation.
  Widget _page(AppTab tab) => tab == AppTab.ask
      ? _pageFor(tab)
      : KeyedSubtree(
          key: ValueKey('${tab.name}|${_county ?? 'SC'}'),
          child: _pageFor(tab),
        );

  Widget _pageFor(AppTab tab) => switch (tab) {
    AppTab.home => DashboardPage(onNavigate: _navigate),
    AppTab.explore => ExplorePage(
      view: _exploreView,
      onViewChanged: (v) => setState(() => _exploreView = v),
    ),
    AppTab.ask => const ChatPage(),
    AppTab.places => const PlacesPage(),
    AppTab.help => HelpPage(onNavigate: _navigate),
  };

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final index = tabs
        .indexWhere((d) => d.tab == _tab)
        .clamp(0, tabs.length - 1);
    final body = IndexedStack(
      index: index,
      children: [for (final d in tabs) _page(d.tab)],
    );
    final appBar = AppBar(
      titleSpacing: 16,
      actions: [
        TextButton.icon(
          onPressed: _pickCounty,
          icon: const Icon(Icons.place_outlined, size: 18),
          label: Text(
            _county?.replaceAll(' County', '') ?? 'All SC',
            semanticsLabel:
                'Showing ${_county ?? 'all of South Carolina'}. '
                'Change county',
          ),
        ),
        const DesignSwitchButton(),
        const SizedBox(width: 8),
      ],
      title: _PageTitle(page: tabs[index].label),
    );
    if (isWide(context)) {
      return Scaffold(
        appBar: appBar,
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                minWidth: 88,
                groupAlignment: -0.9,
                selectedIndex: index,
                onDestinationSelected: _select,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final d in tabs)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(d.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: appBar,
      body: SafeArea(bottom: false, child: body),
      // Large system text sizes would otherwise wrap tab labels onto a
      // second line on small phones.
      bottomNavigationBar: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: _TabBarFrame(
          child: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: _select,
            destinations: [
              for (final d in tabs)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header: a small uppercase app name over a large page title.
class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.page});

  final String page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'BRIDGEGRANT',
          semanticsLabel: 'BridgeGrant',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        Text(page),
      ],
    );
  }
}

/// Adds a hairline above the bottom tab bar.
class _TabBarFrame extends StatelessWidget {
  const _TabBarFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: Theme.of(context).dividerTheme.color!),
      ),
    ),
    child: child,
  );
}

/// Shown instead of the explorer when build-time configuration is missing.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.problem});

  final String problem;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BridgeGrant',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(Brightness.light),
    home: Scaffold(
      body: SafeArea(
        child: MessageView(
          icon: Icons.settings,
          title: 'BridgeGrant is not configured',
          message:
              '$problem\n\nExample:\nflutter run '
              '--dart-define=SUPABASE_URL=https://<project>.supabase.co '
              '--dart-define=SUPABASE_ANON_KEY=<publishable key>',
        ),
      ),
    ),
  );
}

/// Bottom sheet for limiting the app to one county or all of South Carolina.
/// Pops with a record holding the chosen county (null for statewide).
class CountySheet extends StatelessWidget {
  const CountySheet({super.key, required this.current, required this.counties});

  final String? current;
  final Future<List<GrantAggregate>> counties;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget tile(String? county, String title, String subtitle) => ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: county == current
          ? Icon(Icons.check, color: theme.colorScheme.primary)
          : null,
      onTap: () => Navigator.of(context).pop((county,)),
    );
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) => FutureBuilder<List<GrantAggregate>>(
        future: counties,
        builder: (context, snapshot) => ListView(
          controller: scroll,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Show grants for', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Counties come from the recipient\'s ZIP code. Grants whose '
                    'ZIP crosses county lines, or is a PO box, appear only in '
                    'All of South Carolina.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            tile(null, 'All of South Carolina', 'Every county'),
            const Divider(),
            if (snapshot.hasError)
              const ListTile(title: Text('Could not load counties. Try again.'))
            else if (!snapshot.hasData)
              const LoadingView()
            else
              for (final c in snapshot.data!)
                tile(c.label, c.label, '${formatCount(c.grantCount)} grants'),
          ],
        ),
      ),
    );
  }
}
