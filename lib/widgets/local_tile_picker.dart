import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../l10n/app_localizations.dart';
import '../models/local_tile_selection.dart';
import '../models/region.dart';
import '../theme.dart';

class LocalTileChoice {
  const LocalTileChoice({this.selection, this.region});

  final LocalTileSelection? selection;
  final Region? region;
}

class LocalTilePicker extends StatefulWidget {
  const LocalTilePicker({
    super.key,
    required this.regions,
    required this.selectedRegion,
    this.initialSelection,
    this.pickFiles,
    this.validateFiles,
  });

  final List<Region> regions;
  final Region? selectedRegion;
  final LocalTileSelection? initialSelection;
  final Future<List<String>?> Function()? pickFiles;
  final Future<void> Function(LocalTileSelection)? validateFiles;

  @override
  State<LocalTilePicker> createState() => _LocalTilePickerState();
}

class _LocalTilePickerState extends State<LocalTilePicker> {
  String? _mapPath;
  String? _routingPath;
  String? _error;
  bool _dragging = false;
  bool _validating = false;

  @override
  void initState() {
    super.initState();
    _mapPath = widget.initialSelection?.mapPath;
    _routingPath = widget.initialSelection?.routingPath;
  }

  String _errorFor(LocalTileError reason, AppLocalizations l10n) =>
      switch (reason) {
        LocalTileError.noFiles => l10n.localTilesNoFiles,
        LocalTileError.mapExtension => l10n.localTilesInvalidExtension,
        LocalTileError.routingExtension => l10n.localTilesInvalidRouting,
        LocalTileError.regionMismatch => l10n.localTilesMismatch,
        LocalTileError.unreadable => l10n.localTilesUnreadable,
        LocalTileError.invalidMap => l10n.localTilesInvalidMap,
      };

  void _addPaths(List<String> paths) {
    final l10n = AppLocalizations.of(context)!;
    String? map = _mapPath;
    String? routing = _routingPath;
    for (final filePath in paths) {
      if (LocalTileSelection.isMapPath(filePath)) {
        map = filePath;
      } else if (LocalTileSelection.isRoutingPath(filePath)) {
        routing = filePath;
      } else {
        setState(() {
          _error = l10n.localTilesUnsupported;
          _dragging = false;
        });
        return;
      }
    }
    setState(() {
      _mapPath = map;
      _routingPath = routing;
      _error = null;
      _dragging = false;
    });
  }

  Future<void> _browse() async {
    final files = await (widget.pickFiles?.call() ?? _chooseFiles());
    if (mounted && files != null) _addPaths(files);
  }

  Future<List<String>?> _chooseFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mbtiles', 'tar', 'zst'],
      allowMultiple: true,
      withData: false,
    );
    return result?.files.map((file) => file.path).whereType<String>().toList();
  }

  Future<void> _apply() async {
    if (_validating) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _validating = true;
      _error = null;
    });
    try {
      final selection = LocalTileSelection.fromPaths(
        mapPath: _mapPath,
        routingPath: _routingPath,
      );
      final slug = selection.regionSlug ?? widget.selectedRegion?.slug;
      if (slug == null) {
        setState(() => _error = l10n.localTilesNoRegion);
        return;
      }
      final published = widget.regions.where((r) => r.slug == slug).firstOrNull;
      if (published == null &&
          (selection.mapPath == null || selection.routingPath == null)) {
        setState(() => _error = l10n.localTilesCustomPair);
        return;
      }
      await (widget.validateFiles?.call(selection) ??
          selection.validateFiles());
      if (!mounted) return;
      Navigator.pop(
        context,
        LocalTileChoice(
          selection: selection,
          region: published ?? Region.fromSlug(slug),
        ),
      );
    } on LocalTileException catch (e) {
      if (mounted) setState(() => _error = _errorFor(e.reason, l10n));
    } catch (_) {
      if (mounted) setState(() => _error = l10n.localTilesUnreadable);
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  Widget _fileRow(
    String label,
    String? filePath,
    VoidCallback onRemove,
    AppLocalizations l10n,
  ) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Tooltip(
              message: filePath ?? l10n.localTilesUnset,
              child: Text(
                filePath == null
                    ? l10n.localTilesUnset
                    : path.basename(filePath),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: kTextMuted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      if (filePath != null)
        IconButton(
          tooltip: l10n.localTilesRemove,
          onPressed: onRemove,
          icon: const Icon(Icons.close, size: 18),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
      title: Text(l10n.localTilesTitle),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.localTilesIntro),
              const SizedBox(height: 16),
              DropTarget(
                onDragEntered: (_) => setState(() => _dragging = true),
                onDragExited: (_) => setState(() => _dragging = false),
                onDragDone: (details) =>
                    _addPaths([for (final file in details.files) file.path]),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: _dragging
                        ? kAccent.withValues(alpha: 0.12)
                        : kSurfaceHigh,
                    border: Border.all(color: _dragging ? kAccent : kOutline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.file_upload_outlined, color: kTextMuted),
                      const SizedBox(height: 6),
                      Text(l10n.localTilesDrop),
                      TextButton.icon(
                        key: const ValueKey('local-tiles-pick'),
                        onPressed: _browse,
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: Text(l10n.localTilesPick),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _fileRow(
                l10n.localTilesMap,
                _mapPath,
                () => setState(() => _mapPath = null),
                l10n,
              ),
              const SizedBox(height: 8),
              _fileRow(
                l10n.localTilesRouting,
                _routingPath,
                () => setState(() => _routingPath = null),
                l10n,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: kDanger, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (widget.initialSelection != null)
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              LocalTileChoice(
                region: widget.regions
                    .where((r) => r.slug == widget.selectedRegion?.slug)
                    .firstOrNull,
              ),
            ),
            child: Text(l10n.localTilesClear),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancelButton),
        ),
        FilledButton(
          onPressed: _validating || (_mapPath == null && _routingPath == null)
              ? null
              : _apply,
          child: Text(l10n.localTilesUse),
        ),
      ],
    );
  }
}
