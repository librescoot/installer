import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/region.dart';
import '../theme.dart';

/// Single-region selection with country tabs and alphabetically ordered pills.
class RegionPicker extends StatefulWidget {
  const RegionPicker({
    super.key,
    required this.regions,
    required this.selectedRegion,
    required this.onSelected,
    this.maxRegionHeight,
  });

  final List<Region> regions;
  final Region? selectedRegion;
  final ValueChanged<Region> onSelected;
  final double? maxRegionHeight;

  @override
  State<RegionPicker> createState() => _RegionPickerState();
}

class _RegionPickerState extends State<RegionPicker>
    with SingleTickerProviderStateMixin {
  late Map<String, List<Region>> _groups;
  late TabController _tabs;

  static Map<String, List<Region>> _group(List<Region> regions) {
    final grouped = <String, List<Region>>{};
    for (final region in regions) {
      grouped.putIfAbsent(region.country, () => []).add(region);
    }
    final countries = grouped.keys.toList()
      ..sort((a, b) {
        if (a == 'Deutschland') return -1;
        if (b == 'Deutschland') return 1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    return {
      for (final country in countries)
        country: grouped[country]!
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          ),
    };
  }

  int _indexFor(Region? selected, Map<String, List<Region>> groups) {
    final index = selected == null
        ? -1
        : groups.keys.toList().indexOf(selected.country);
    return index < 0 ? 0 : index;
  }

  void _initTabs(int index) {
    _tabs = TabController(
      length: _groups.length,
      initialIndex: index,
      vsync: this,
    )..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _groups = _group(widget.regions);
    _initTabs(_indexFor(widget.selectedRegion, _groups));
  }

  @override
  void didUpdateWidget(covariant RegionPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldCountries = _groups.keys.toList();
    final activeCountry = oldCountries.isEmpty
        ? null
        : oldCountries[_tabs.index];
    final groups = _group(widget.regions);
    _groups = groups;
    if (!listEquals(oldCountries, groups.keys.toList())) {
      _tabs.removeListener(_onTabChanged);
      _tabs.dispose();
      final country = widget.selectedRegion?.country ?? activeCountry;
      final index = country == null
          ? -1
          : groups.keys.toList().indexOf(country);
      _initTabs(index < 0 ? 0 : index);
    } else if (oldWidget.selectedRegion != widget.selectedRegion &&
        widget.selectedRegion != null) {
      _tabs.animateTo(_indexFor(widget.selectedRegion, groups));
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_groups.isEmpty) return const SizedBox.shrink();
    final activeCountry = _groups.keys.elementAt(_tabs.index);
    final pills = Wrap(
      key: const ValueKey('region-pills'),
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final region in _groups[activeCountry]!)
          ChoiceChip(
            key: ValueKey('region-${region.slug}'),
            label: Text(region.name),
            selected: widget.selectedRegion == region,
            showCheckmark: false,
            shape: const StadiumBorder(),
            side: BorderSide(
              color: widget.selectedRegion == region ? kAccent : Colors.white30,
            ),
            selectedColor: kAccent.withValues(alpha: 0.2),
            onSelected: (_) {
              if (widget.selectedRegion != region) widget.onSelected(region);
            },
          ),
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelPadding: const EdgeInsets.symmetric(horizontal: 16),
          indicatorColor: kAccent,
          labelColor: kAccent,
          unselectedLabelColor: Colors.white70,
          tabs: [
            for (final country in _groups.keys)
              Tab(key: ValueKey('country-$country'), text: country),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.maxRegionHeight case final height?)
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: height),
            child: SingleChildScrollView(
              key: ValueKey('regions-$activeCountry'),
              child: pills,
            ),
          )
        else
          pills,
      ],
    );
  }
}
