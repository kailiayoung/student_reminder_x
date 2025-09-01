import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:students_reminder/src/features/notes/dialogs/note_editor_dialog.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/note_service.dart';

class MyNotesPage extends StatefulWidget {
  const MyNotesPage({super.key});

  @override
  State<MyNotesPage> createState() => _MyNotesPageState();
}

class _MyNotesPageState extends State<MyNotesPage> {
  String _searchQuery = '';
  String _visibilityFilter = 'all';
  DateTimeRange? _dueDateRange;
  final List<String> _selectedTags = [];
  String _sortBy = 'aud_dt'; // aud_dt, dueDate, title
  bool _sortAscending = false;
  final TextEditingController _searchController = TextEditingController();

  // Get all unique tags from notes
  Set<String> _getAllTags(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    Set<String> allTags = {};
    for (var doc in docs) {
      final data = doc.data();
      final tags = data['tags'] as List<dynamic>? ?? [];
      allTags.addAll(tags.cast<String>());
    }
    return allTags;
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('My Notes'),
        actions: [
          IconButton(
            onPressed: _showFilterDialog,
            icon: Icon(Icons.filter_list),
          ),
          IconButton(
            onPressed: _showSortDialog,
            icon: Icon(Icons.arrow_downward_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => NoteEditorDialog(uid: uid),
          );
        },
        child: Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search notes by title or body...',
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            icon: Icon(Icons.clear),
                          )
                        : null,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value.toLowerCase());
                  },
                ),

                // Active Filters Display
                if (_selectedTags.isNotEmpty ||
                    _visibilityFilter != 'all' ||
                    _dueDateRange != null) ...[
                  SizedBox(height: 12),
                  Text(
                    'Active Filters:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      // Visibility filter chip
                      if (_visibilityFilter != 'all')
                        Chip(
                          label: Text(
                            'Visibility: $_visibilityFilter',
                            style: TextStyle(fontSize: 10),
                          ),
                          backgroundColor: Colors.orange[100],
                          deleteIcon: Icon(Icons.close, size: 14),
                          onDeleted: () =>
                              setState(() => _visibilityFilter = 'all'),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      // Due date filter chip
                      if (_dueDateRange != null)
                        Chip(
                          label: Text(
                            'Due: ${_dueDateRange!.start.toString().split(' ').first} - ${_dueDateRange!.end.toString().split(' ').first}',
                            style: TextStyle(fontSize: 10),
                          ),
                          backgroundColor: Colors.green[100],
                          deleteIcon: Icon(Icons.close, size: 14),
                          onDeleted: () => setState(() => _dueDateRange = null),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      // Tag filter chips
                      ..._selectedTags.map(
                        (tag) => Chip(
                          label: Text(
                            'Tag: $tag',
                            style: TextStyle(fontSize: 10),
                          ),
                          backgroundColor: Colors.blue[100],
                          deleteIcon: Icon(Icons.close, size: 14),
                          onDeleted: () =>
                              setState(() => _selectedTags.remove(tag)),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Notes List
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: NotesService.instance.watchMyNotes(uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final docs = snap.data?.docs ?? [];

                // Apply filters
                final filteredDocs = docs.where((doc) {
                  final data = doc.data();
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final body = (data['body'] ?? '').toString().toLowerCase();
                  final visibility = data['visibility'] ?? 'private';
                  final dueDate = data['dueDate']?.toDate();

                  // Search filter
                  if (_searchQuery.isNotEmpty) {
                    if (!title.contains(_searchQuery) &&
                        !body.contains(_searchQuery)) {
                      return false;
                    }
                  }

                  // Visibility filter
                  if (_visibilityFilter != 'all' &&
                      visibility != _visibilityFilter) {
                    return false;
                  }

                  // Due date range filter
                  if (_dueDateRange != null && dueDate != null) {
                    if (dueDate.isBefore(_dueDateRange!.start) ||
                        dueDate.isAfter(_dueDateRange!.end)) {
                      return false;
                    }
                  }

                  // Tag filter
                  if (_selectedTags.isNotEmpty) {
                    final noteTags = List<String>.from(data['tags'] ?? []);
                    final hasSelectedTag = _selectedTags.any(
                      (selectedTag) => noteTags.contains(selectedTag),
                    );
                    if (!hasSelectedTag) {
                      return false;
                    }
                  }

                  return true;
                }).toList();

                // Apply sorting
                filteredDocs.sort((a, b) {
                  final dataA = a.data();
                  final dataB = b.data();

                  switch (_sortBy) {
                    case 'title':
                      final titleA = (dataA['title'] ?? '')
                          .toString()
                          .toLowerCase();
                      final titleB = (dataB['title'] ?? '')
                          .toString()
                          .toLowerCase();
                      final comparison = titleA.compareTo(titleB);
                      return _sortAscending ? comparison : -comparison;

                    case 'dueDate':
                      final dueDateA = dataA['dueDate']?.toDate();
                      final dueDateB = dataB['dueDate']?.toDate();

                      // Handle null due dates (put them at the end)
                      if (dueDateA == null && dueDateB == null) return 0;
                      if (dueDateA == null) return 1;
                      if (dueDateB == null) return -1;

                      final comparison = dueDateA.compareTo(dueDateB);
                      return _sortAscending ? comparison : -comparison;

                    case 'aud_dt':
                    default:
                      final audDtA = dataA['aud_dt']?.toDate();
                      final audDtB = dataB['aud_dt']?.toDate();

                      // Handle null audit dates
                      if (audDtA == null && audDtB == null) return 0;
                      if (audDtA == null) return 1;
                      if (audDtB == null) return -1;

                      final comparison = audDtA.compareTo(audDtB);
                      return _sortAscending ? comparison : -comparison;
                  }
                });

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Text(
                      docs.isEmpty
                          ? 'No notes to show. Click the + button to add a note.'
                          : 'No notes match your search criteria.',
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filteredDocs.length,
                  separatorBuilder: (_, _) => Divider(height: 2),
                  itemBuilder: (context, i) {
                    final data = filteredDocs[i];
                    final visible = data['visibility'] ?? 'private';
                    final title = (data['title'] ?? '').toString();
                    final body = (data['body'] ?? '').toString();
                    final tags = List<String>.from(data['tags'] ?? []);

                    print(
                      'Note: $title, Tags: $tags, Raw data tags: ${data['tags']}',
                    ); // Enhanced debug print

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    visible,
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                SizedBox(width: 8),
                                IconButton(
                                  onPressed: () async {
                                    await NotesService.instance.deleteNote(
                                      uid,
                                      data.id,
                                    );
                                  },
                                  icon: Icon(Icons.delete_outlined),
                                  iconSize: 20,
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            // Always show tag section for debugging
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  'Tags: ',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (tags.isEmpty)
                                  Text(
                                    '(none)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[400],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  )
                                else
                                  Expanded(
                                    child: Wrap(
                                      spacing: 4,
                                      runSpacing: 2,
                                      children: tags
                                          .map(
                                            (tag) => Chip(
                                              label: Text(
                                                tag,
                                                style: TextStyle(fontSize: 10),
                                              ),
                                              backgroundColor: Colors.blue[50],
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: 4),
                            InkWell(
                              onTap: () async {
                                await showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => NoteEditorDialog(
                                    uid: uid,
                                    noteId: data.id,
                                    existing: data.data(),
                                  ),
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.edit,
                                      size: 16,
                                      color: Colors.blue,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Edit',
                                      style: TextStyle(color: Colors.blue),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.tune),
              SizedBox(width: 8),
              Text('Filter Notes'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sort options
                SizedBox(height: 16),

                // Visibility Filter
                Text(
                  'Visibility:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                DropdownButton<String>(
                  value: _visibilityFilter,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'private', child: Text('Private')),
                    DropdownMenuItem(value: 'public', child: Text('Public')),
                  ],
                  onChanged: (value) {
                    setDialogState(() => _visibilityFilter = value ?? 'all');
                  },
                ),
                SizedBox(height: 16),

                // Due Date Filter
                Text(
                  'Due Date Range:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  icon: Icon(Icons.date_range),
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime.now().subtract(
                        Duration(days: 365 * 2),
                      ),
                      lastDate: DateTime.now().add(Duration(days: 365 * 5)),
                      initialDateRange: _dueDateRange,
                    );
                    if (picked != null) {
                      setDialogState(() => _dueDateRange = picked);
                    }
                  },
                  label: Text(
                    _dueDateRange == null
                        ? 'Select Range'
                        : '${_dueDateRange!.start.toString().split(' ').first} - ${_dueDateRange!.end.toString().split(' ').first}',
                  ),
                ),
                if (_dueDateRange != null)
                  TextButton.icon(
                    icon: Icon(Icons.clear),
                    onPressed: () => setDialogState(() => _dueDateRange = null),
                    label: Text('Clear Date Range'),
                  ),
                SizedBox(height: 16),

                // Tags Filter
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: NotesService.instance.watchMyNotes(
                    AuthService.instance.currentUser!.uid,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return SizedBox.shrink();
                    }

                    final allTags = _getAllTags(snapshot.data?.docs ?? []);

                    if (allTags.isEmpty) {
                      return SizedBox.shrink();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filter by Tags:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: allTags.map((tag) {
                            final isSelected = _selectedTags.contains(tag);
                            return FilterChip(
                              label: Text(tag),
                              selected: isSelected,
                              onSelected: (selected) {
                                setDialogState(() {
                                  if (selected) {
                                    _selectedTags.add(tag);
                                  } else {
                                    _selectedTags.remove(tag);
                                  }
                                });
                              },
                              backgroundColor: Colors.grey[200],
                              selectedColor: Colors.blue[100],
                              checkmarkColor: Colors.blue[700],
                            );
                          }).toList(),
                        ),
                        if (_selectedTags.isNotEmpty)
                          TextButton.icon(
                            icon: Icon(Icons.clear),
                            onPressed: () =>
                                setDialogState(() => _selectedTags.clear()),
                            label: Text('Clear Tags'),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setDialogState(() {
                  _searchQuery = '';
                  _searchController.clear();
                  _visibilityFilter = 'all';
                  _dueDateRange = null;
                  _selectedTags.clear();
                  _sortBy = 'aud_dt';
                  _sortAscending = false;
                });
                setState(() {}); // Update main UI
              },
              child: Text('Clear All'),
            ),
            TextButton(
              onPressed: () {
                setState(() {}); // Update main UI
                Navigator.pop(context);
              },
              child: Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [Icon(Icons.sort), SizedBox(width: 8), Text('Sort Notes')],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sort by:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            RadioListTile<String>(
              title: Text('Date Created (newest first)'),
              value: 'aud_dt',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                  _sortAscending = false;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: Text('Date Created (oldest first)'),
              value: 'aud_dt_asc',
              groupValue: _sortBy == 'aud_dt' && _sortAscending
                  ? 'aud_dt_asc'
                  : _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = 'aud_dt';
                  _sortAscending = true;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: Text('Due Date (soonest first)'),
              value: 'dueDate',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                  _sortAscending = true;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: Text('Due Date (latest first)'),
              value: 'dueDate_desc',
              groupValue: _sortBy == 'dueDate' && !_sortAscending
                  ? 'dueDate_desc'
                  : _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = 'dueDate';
                  _sortAscending = false;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: Text('Title (A-Z)'),
              value: 'title',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                  _sortAscending = true;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: Text('Title (Z-A)'),
              value: 'title_desc',
              groupValue: _sortBy == 'title' && !_sortAscending
                  ? 'title_desc'
                  : _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = 'title';
                  _sortAscending = false;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
