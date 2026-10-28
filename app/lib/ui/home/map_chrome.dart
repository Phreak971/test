import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../hud.dart';

/// Reports its child's laid-out size (used to keep map controls and the map's
/// content insets clear of sheets and bars).
class MeasureSize extends SingleChildRenderObjectWidget {
  const MeasureSize({super.key, required this.onChange, required super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) => _MeasureBox(onChange);

  @override
  void updateRenderObject(BuildContext context, covariant RenderObject renderObject) => (renderObject as _MeasureBox).onChange = onChange;
}

class _MeasureBox extends RenderProxyBox {
  _MeasureBox(this.onChange);

  ValueChanged<Size> onChange;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _last) return;
    _last = size;
    final s = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(s));
  }
}

/// Bottom sheet over the map, Maps-style: a grabber, a header that is always
/// visible and optional details revealed by dragging up (or tapping the
/// grabber). Dragging down collapses it, and from collapsed dismisses it.
/// Sizes to its content, so it never covers more of the map than it needs.
class MapSheet extends StatefulWidget {
  const MapSheet({
    super.key,
    required this.hud,
    required this.header,
    this.details,
    this.onDismiss,
    this.expanded,
    this.maxHeightFraction = 0.72,
  });

  final Hud hud;
  final Widget header;

  /// Shown when expanded (scrolls if long).
  final Widget? details;

  /// Swipe-down-to-dismiss; null makes the sheet persistent.
  final VoidCallback? onDismiss;

  /// Optional external control of the expanded state (e.g. a Steps button).
  final ValueNotifier<bool>? expanded;
  final double maxHeightFraction;

  @override
  State<MapSheet> createState() => _MapSheetState();
}

class _MapSheetState extends State<MapSheet> {
  double _drag = 0;
  final _own = ValueNotifier(false);

  ValueNotifier<bool> get _state => widget.expanded ?? _own;
  bool get _expanded => _state.value;
  set _expanded(bool v) => _state.value = v;

  bool get _canExpand => widget.details != null;

  @override
  void initState() {
    super.initState();
    _state.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(MapSheet old) {
    super.didUpdateWidget(old);
    if (old.expanded != widget.expanded) {
      (old.expanded ?? _own).removeListener(_rebuild);
      _state.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    _state.removeListener(_rebuild);
    _own.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _toggle() {
    if (!_canExpand) return;
    HapticFeedback.selectionClick();
    _expanded = !_expanded;
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final up = _drag < -36 || v < -350;
    final down = _drag > 36 || v > 350;
    setState(() => _drag = 0);
    if (up && _canExpand) {
      _expanded = true;
    } else if (down) {
      if (_expanded) {
        _expanded = false;
      } else {
        widget.onDismiss?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final hud = widget.hud;
    final mq = MediaQuery.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final radius = Radius.circular(hud.radius.clamp(14, 28).toDouble());

    final grabber = Semantics(
      button: _canExpand,
      label: _canExpand ? (_expanded ? l.sheetCollapse : l.sheetExpand) : null,
      onTap: _canExpand ? _toggle : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: SizedBox(
          height: 22,
          width: double.infinity,
          child: Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(color: hud.text.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(3)),
            ),
          ),
        ),
      ),
    );

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        grabber,
        widget.header,
        if (_canExpand)
          AnimatedSize(
            duration: reduce ? Duration.zero : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: mq.size.height * widget.maxHeightFraction * 0.7),
                    child: SingleChildScrollView(child: widget.details),
                  )
                : const SizedBox(width: double.infinity),
          ),
      ],
    );

    return GestureDetector(
      onVerticalDragUpdate: (d) => setState(() => _drag += d.primaryDelta ?? 0),
      onVerticalDragEnd: _onDragEnd,
      onVerticalDragCancel: () => setState(() => _drag = 0),
      child: Transform.translate(
        // Follow the finger downwards for a dismiss gesture; resist upwards.
        offset: Offset(0, _drag > 0 ? _drag : _drag * 0.15),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: mq.size.height * widget.maxHeightFraction),
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 18, offset: Offset(0, -2))],
              borderRadius: BorderRadius.vertical(top: radius, bottom: Radius.circular(radius.x * 0.6)),
            ),
            child: Material(
              color: hud.panelOpaque,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: radius, bottom: Radius.circular(radius.x * 0.6)),
                side: BorderSide(color: hud.text.withValues(alpha: 0.12)),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.only(bottom: mq.padding.bottom),
                  child: body,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The always-visible search field at the top of the map.
class SearchPill extends StatelessWidget {
  const SearchPill({super.key, required this.hud, required this.onSearch, required this.onSettings});

  final Hud hud;
  final VoidCallback onSearch;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Material(
      color: hud.panelOpaque,
      elevation: 4,
      shadowColor: Colors.black54,
      shape: StadiumBorder(side: BorderSide(color: hud.text.withValues(alpha: 0.12))),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: l.searchHere,
              excludeSemantics: true,
              child: InkWell(
                onTap: onSearch,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(Icons.search_rounded, color: hud.accentText),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          l.searchHere,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: hud.muted, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: l.railSettings,
            onPressed: onSettings,
            constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: hud.accent,
              child: Icon(Icons.person_rounded, color: hud.onAccent, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill-shaped quick action under the search field.
class QuickChip extends StatelessWidget {
  const QuickChip({super.key, required this.hud, required this.icon, required this.label, required this.onTap, this.selected = false});

  final Hud hud;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? hud.onAccent : hud.text;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? hud.accent : hud.panelOpaque,
        elevation: 2,
        shadowColor: Colors.black45,
        shape: StadiumBorder(
          side: BorderSide(color: hud.text.withValues(alpha: selected ? 0 : 0.12)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: selected ? fg : hud.accentText),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round floating map control (my location, directions, layers).
class MapFab extends StatelessWidget {
  const MapFab({
    super.key,
    required this.hud,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.active = false,
    this.size = 56,
  });

  final Hud hud;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  /// Filled with the accent colour (the main call to action).
  final bool primary;

  /// Highlighted icon (e.g. following the user).
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bg = primary ? hud.accent : hud.panelOpaque;
    final fg = primary ? hud.onAccent : (active ? hud.accentText : hud.text);
    return Semantics(
      button: true,
      label: label,
      selected: active,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: SizedBox(
          width: size,
          height: size,
          child: Material(
            color: bg,
            elevation: 4,
            shadowColor: Colors.black54,
            shape: CircleBorder(
              side: BorderSide(color: hud.text.withValues(alpha: primary ? 0 : 0.12)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onPressed();
              },
              child: Icon(icon, color: fg, size: size * 0.46),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Re-center" pill shown while navigating after the user pans away.
class RecenterPill extends StatelessWidget {
  const RecenterPill({super.key, required this.hud, required this.onPressed});

  final Hud hud;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Material(
      color: hud.panelOpaque,
      elevation: 4,
      shadowColor: Colors.black54,
      shape: StadiumBorder(side: BorderSide(color: hud.text.withValues(alpha: 0.12))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.navigation_rounded, color: hud.accentText, size: 20),
                const SizedBox(width: 8),
                Text(
                  l.recenter,
                  style: TextStyle(color: hud.text, fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
