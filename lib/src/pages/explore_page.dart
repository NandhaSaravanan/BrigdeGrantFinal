import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets.dart';
import 'entities_page.dart';
import 'grants_page.dart';

/// Grants, funders, and recipients in one tab, switched with a segmented
/// control. Each list keeps its search, filters, and page when switching.
class ExplorePage extends StatelessWidget {
  const ExplorePage({
    super.key,
    required this.view,
    required this.onViewChanged,
  });

  final ExploreView view;
  final ValueChanged<ExploreView> onViewChanged;

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    ButtonSegment<ExploreView> segment(
      ExploreView v,
      String label,
      IconData icon,
    ) => ButtonSegment(
      value: v,
      // Icons only where there is room, so labels never wrap on phones.
      icon: wide ? Icon(icon) : null,
      label: Text(label, maxLines: 1, softWrap: false),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SizedBox(
            width: wide ? 520 : double.infinity,
            child: SegmentedButton<ExploreView>(
              showSelectedIcon: false,
              segments: [
                segment(ExploreView.grants, 'Grants', Icons.list_alt),
                segment(
                  ExploreView.funders,
                  'Funders',
                  Icons.account_balance_outlined,
                ),
                segment(
                  ExploreView.recipients,
                  'Recipients',
                  Icons.groups_outlined,
                ),
              ],
              selected: {view},
              onSelectionChanged: (s) => onViewChanged(s.first),
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: view.index,
            children: const [
              GrantExplorer(),
              EntitiesPage(kind: EntityKind.funder),
              EntitiesPage(kind: EntityKind.recipient),
            ],
          ),
        ),
      ],
    );
  }
}
