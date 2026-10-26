import 'package:flutter/material.dart';

import 'theme.dart';

/// Single-series vertical bar chart. Bars use the theme's chart color; the
/// selected bar uses its highlight color and shows its value above it. Thin
/// bars with 4px rounded tops sit on a shared baseline over faint gridlines.
/// Tap a bar to select it. Colors come from the theme's [BrandStyle].
class VerticalBarChart extends StatelessWidget {
  const VerticalBarChart({
    super.key,
    required this.labels,
    required this.values,
    required this.valueLabels,
    required this.selected,
    required this.onSelect,
  });

  final List<String> labels;
  final List<num> values;
  final List<String> valueLabels;
  final int selected;
  final ValueChanged<int> onSelect;

  static const _plotHeight = 170.0;

  /// Splits a label between words onto at most two lines so names never
  /// break mid-word (e.g. "Lake Wylie" -> "Lake\nWylie").
  static String _twoLines(String label) {
    final words = label.trim().split(RegExp(r'\s+'));
    if (words.length < 2) return label.trim();
    final half = (words.length / 2).ceil();
    return '${words.take(half).join(' ')}\n${words.skip(half).join(' ')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = BrandStyle.of(context);
    final max = values.fold<num>(0, (m, v) => v > m ? v : m);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    // Reserve room for the value tip and two label lines at the user's
    // text size, so larger accessibility text never overflows.
    final textScaler = MediaQuery.textScalerOf(context);
    final line = textScaler.scale(11) * 1.35;
    final tooltipSpace = line + 8 + 10;
    final labelHeight = line * 2 + 8;
    // Horizontal alignment that centers the tip over the selected bar while
    // keeping it inside the chart at the first and last bars.
    final tipX = values.isEmpty
        ? 0.0
        : (selected + 0.5) / values.length * 2 - 1;

    return SizedBox(
      height: tooltipSpace + _plotHeight + labelHeight,
      child: Stack(
        children: [
          // Recessive gridlines at thirds; the bottom one is the baseline.
          for (var i = 0; i <= 3; i++)
            Positioned(
              left: 0,
              right: 0,
              top: tooltipSpace + _plotHeight * i / 3,
              child: Container(
                height: 1,
                color: scheme.outlineVariant.withValues(
                  alpha: i == 3 ? 1 : 0.5,
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selected,
                    label: '${labels[i]}: ${valueLabels[i]}',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelect(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(height: tooltipSpace),
                          SizedBox(
                            height: _plotHeight,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                                width: 16,
                                height: max <= 0
                                    ? 0
                                    : (_plotHeight * values[i] / max).clamp(
                                        values[i] > 0 ? 3.0 : 0.0,
                                        _plotHeight,
                                      ),
                                decoration: BoxDecoration(
                                  color: i == selected
                                      ? brand.chartSelected
                                      : brand.chartBar,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: labelHeight,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
                              // Shrinks a single long word to fit the column
                              // instead of breaking it across lines.
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.topCenter,
                                child: Text(
                                  _twoLines(labels[i]),
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  style: i == selected
                                      ? labelStyle?.copyWith(
                                          color: scheme.onSurface,
                                          fontWeight: FontWeight.w700,
                                        )
                                      : labelStyle,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Drawn above the bars at full chart width so the value is never
          // squeezed into a single bar's column.
          if (selected >= 0 && selected < values.length)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: tooltipSpace,
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment(tipX, -1),
                  child: _ValueTip(valueLabels[selected]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ValueTip extends StatelessWidget {
  const _ValueTip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: TextStyle(
          color: scheme.onInverseSurface,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
