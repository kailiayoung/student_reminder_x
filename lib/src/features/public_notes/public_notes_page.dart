// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:students_reminder/src/services/note_service.dart';

// class TimelinePage extends StatefulWidget {
//   const TimelinePage({super.key});

//   @override
//   State<TimelinePage> createState() => _TimelinePageState();
// }

// class _TimelinePageState extends State<TimelinePage> {
//   String _searchQuery = '';
//   final TextEditingController _searchController = TextEditingController();

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Timeline')),
//       body: Column(
//         children: [
//           // Search Section
//           Container(
//             padding: EdgeInsets.all(16),
//             child: Column(
//               children: [
//                 TextField(
//                   controller: _searchController,
//                   decoration: InputDecoration(
//                     hintText: 'Search all public notes...',
//                     prefixIcon: Icon(Icons.search),
//                     suffixIcon: _searchQuery.isNotEmpty
//                         ? IconButton(
//                             onPressed: () {
//                               _searchController.clear();
//                               setState(() => _searchQuery = '');
//                             },
//                             icon: Icon(Icons.clear),
//                           )
//                         : null,
//                     border: OutlineInputBorder(),
//                   ),
//                   onChanged: (value) {
//                     setState(() => _searchQuery = value.toLowerCase());
//                   },
//                 ),
//               ],
//             ),
//           ),

//           // Timeline List
//           Expanded(
//             child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
//               stream: NotesService.instance.watchAllPublicNotes(),
//               builder: (context, snap) {
//                 if (snap.connectionState == ConnectionState.waiting) {
//                   return Center(child: CircularProgressIndicator());
//                 }

//                 if (snap.hasError) {
//                   return Center(child: Text('Error: ${snap.error}'));
//                 }

//                 final docs = snap.data?.docs ?? [];

//                 // Apply search filter
//                 final filteredDocs = docs.where((doc) {
//                   if (_searchQuery.isEmpty) return true;

//                   final data = doc.data();
//                   final title = (data['title'] ?? '').toString().toLowerCase();
//                   final body = (data['body'] ?? '').toString().toLowerCase();
//                   final tags = List<String>.from(data['tags'] ?? []);
//                   final tagsText = tags.join(' ').toLowerCase();

//                   return title.contains(_searchQuery) ||
//                       body.contains(_searchQuery) ||
//                       tagsText.contains(_searchQuery);
//                 }).toList();

//                 if (filteredDocs.isEmpty) {
//                   return Center(
//                     child: Text(
//                       docs.isEmpty
//                           ? 'No public notes to show'
//                           : 'No notes match your search',
//                     ),
//                   );
//                 }

//                 return ListView.builder(
//                   itemCount: filteredDocs.length,
//                   padding: EdgeInsets.all(16),
//                   itemBuilder: (context, i) {
//                     final doc = filteredDocs[i];
//                     final data = doc.data();
//                     final title = (data['title'] ?? '').toString();
//                     final body = (data['body'] ?? '').toString();
//                     final tags = List<String>.from(data['tags'] ?? []);
//                     final timestamp = data['aud_dt']?.toDate();

//                     // Extract user ID from document path
//                     final userId = doc.reference.parent.parent?.id ?? 'Unknown';

//                     return Card(
//                       margin: EdgeInsets.only(bottom: 8),
//                       child: Padding(
//                         padding: EdgeInsets.all(16),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             if (title.isNotEmpty) ...[
//                               Text(
//                                 title,
//                                 style: Theme.of(context).textTheme.titleMedium
//                                     ?.copyWith(fontWeight: FontWeight.bold),
//                               ),
//                               SizedBox(height: 8),
//                             ],
//                             if (body.isNotEmpty) Text(body),
//                             if (tags.isNotEmpty) ...[
//                               SizedBox(height: 12),
//                               Wrap(
//                                 spacing: 4,
//                                 runSpacing: 4,
//                                 children: tags
//                                     .map(
//                                       (tag) => Chip(
//                                         label: Text(tag),
//                                         materialTapTargetSize:
//                                             MaterialTapTargetSize.shrinkWrap,
//                                       ),
//                                     )
//                                     .toList(),
//                               ),
//                             ],
//                             SizedBox(height: 8),
//                             Row(
//                               children: [
//                                 Expanded(
//                                   child: Text(
//                                     'By: $userId',
//                                     style: Theme.of(
//                                       context,
//                                     ).textTheme.bodySmall,
//                                   ),
//                                 ),
//                                 if (timestamp != null)
//                                   Text(
//                                     _formatTimestamp(timestamp),
//                                     style: Theme.of(
//                                       context,
//                                     ).textTheme.bodySmall,
//                                   ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   String _formatTimestamp(DateTime timestamp) {
//     final now = DateTime.now();
//     final diff = now.difference(timestamp);

//     if (diff.inMinutes < 1) return 'Just now';
//     if (diff.inHours < 1) return '${diff.inMinutes}m ago';
//     if (diff.inDays < 1) return '${diff.inHours}h ago';
//     if (diff.inDays < 7) return '${diff.inDays}d ago';

//     return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
//   }
// }
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:students_reminder/src/features/notes/dialogs/note_editor_dialog.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/note_service.dart';

class PublicFeeds extends StatelessWidget {
  const PublicFeeds({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Public Feeds')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: NotesService.instance.publicFeeds(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData) {
            return const Center(child: Text('Loading...'));
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text('No notes to show. Click the + button to add a note.'),
            );
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 2),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data();
              final ref = doc.reference;

              final visible = (data['visibility'] ?? 'private') as String;
              final title = (data['title'] ?? '').toString();
              final body  = (data['body'] ?? '').toString();

              final likes   = (data['likesCount'] ?? 0) as int;
              final likedBy = Map<String, dynamic>.from(data['likedBy'] ?? const {});
              final bool isLiked = likedBy[uid] == true;

              return ListTile(
                leading: Chip(label: Text(visible)),
                title: Text(title),
                subtitle: Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(likes.toString()),
                    IconButton(
                      tooltip: isLiked ? 'Unlike' : 'Like',
                      icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
                      onPressed: () {
                        NotesService.instance.toggleLike(noteRef: ref, uid: uid);
                      },
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'report') {
                          final reason = await askReportReason(context);
                          if (reason != null && reason.trim().isNotEmpty) {
                            await NotesService.instance.reportNote(
                              noteRef: ref,
                              uid: uid,
                              reason: reason.trim(),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Thanks — report submitted.')),
                            );
                          }
                        } else if (v == 'unreport') {
                          await NotesService.instance.unreportNote(noteRef: ref, uid: uid);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Your report was removed.')),
                          );
                        }
                      },
                      itemBuilder: (BuildContext context) {
                        // If you later cache "did I report?", toggle which items to show.
                        return const [
                          PopupMenuItem(value: 'report', child: Text('Report')),
                          PopupMenuItem(value: 'unreport', child: Text('Undo report')),
                        ];
                      },
                    ),
                  ],
                ),
                onTap: () {
                  // TODO: push a detail page if you have one
                },
              );
            },
          );
        },
      ),

      // Optional: quick-add note (opens your editor)
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => NoteEditorDialog(uid: uid),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Keep this OUTSIDE the widget class (or make it a static method).
Future<String?> askReportReason(BuildContext context) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Report note'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Briefly say what’s wrong (spam, offensive, etc.)',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Submit'),
        ),
      ],
    ),
  );
}