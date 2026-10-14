import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../state/editor_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

class BackupsScreen extends StatefulWidget {
  const BackupsScreen({super.key});
  @override
  State<BackupsScreen> createState() => _BackupsScreenState();
}

class _BackupsScreenState extends State<BackupsScreen> {
  late Future<List<BackupEntry>> _future = EditorState.listBackups();

  @override
  Widget build(BuildContext context) {
    final state = context.read<EditorState>();
    final p = context.farm;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Backups'))),
      body: FutureBuilder<List<BackupEntry>>(
        future: _future,
        builder: (context, snap) {
          final list = snap.data;
          if (list == null) return Center(child: CircularProgressIndicator());
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.history,
              title: tr('No backups yet'),
              message: tr('Every save you open is copied here first, so you can always go back.'),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => SizedBox(height: 10),
            itemBuilder: (context, i) {
              final b = list[i];
              return PixelPanel(
                child: Row(children: [
                  Icon(Icons.save_outlined, color: p.woodDark),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(b.saveName, style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('${DateFormat.yMMMd().add_Hm().format(b.createdAt)} · ${(b.size / 1024 / 1024).toStringAsFixed(1)} MB',
                          style: TextStyle(fontSize: 12, color: p.textMuted)),
                    ]),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'open') {
                        await state.openBackup(b);
                        if (context.mounted) Navigator.pop(context);
                      } else if (v == 'export') {
                        await state.exportBackup(b);
                      } else if (v == 'delete') {
                        await b.file.delete();
                        setState(() => _future = EditorState.listBackups());
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'open', child: Text(tr('Open in editor'))),
                      PopupMenuItem(value: 'export', child: Text(tr('Export copy…'))),
                      PopupMenuItem(value: 'delete', child: Text(tr('Delete'))),
                    ],
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
