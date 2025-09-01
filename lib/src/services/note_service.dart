import 'package:cloud_firestore/cloud_firestore.dart';

class NotesService {
  NotesService._();
  static final instance = NotesService._();
  final _db = FirebaseFirestore.instance;

  //Finding the destination for notes
  CollectionReference<Map<String, dynamic>> _notesCol(String uid) {
    return _db.collection('users').doc(uid).collection('notes');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMyNotes(String uid) {
    return _notesCol(uid).orderBy('aud_dt', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPublicNotes(String uid) {
    return _notesCol(uid)
        .where('visibility', isEqualTo: 'public')
        .orderBy('aud_dt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> publicFeeds() {
  return _db
        .collectionGroup('notes')
        .where('visibility', isEqualTo: 'public')
        .orderBy('aud_dt', descending: true) // or orderBy('likesCount', descending: true)
        .limit(100)
        .snapshots();
  }

  Future<String> createNote(
    String uid, {
    required String title,
    required String body,
    required String visibility,
    DateTime? dueDate,
    List<String>? tags,
  }) async {
    final doc = await _notesCol(uid).add({
      'title': title,
      'body': body,
      'visibility': visibility,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
      'tags': tags ?? [],
      'aud_dt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> updateNote(
    String uid,
    String noteId, {
    String? title,
    String? body,
    String? visibility,
    DateTime? dueDate,
    List<String>? tags,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (body != null) data['body'] = body;
    if (visibility != null) data['visibility'] = visibility;
    if (dueDate != null) {
      data['dueDate'] = Timestamp.fromDate(dueDate);
    }
    if (tags != null) data['tags'] = tags;
    await _notesCol(uid).doc(noteId).update(data);
  }

  Future<void> deleteNote(String uid, String noteId) {
    return _notesCol(uid).doc(noteId).delete();
  }
   Future<void> toggleLike({
    required DocumentReference<Map<String, dynamic>> noteRef,
    required String uid,
  }) async {
    final db = FirebaseFirestore.instance;

    await db.runTransaction((tx) async {
      final snap = await tx.get(noteRef);
      if (!snap.exists) return;

      final data = snap.data()!;
      final Map<String, dynamic> likedBy =
          Map<String, dynamic>.from(data['likedBy'] ?? const {});
      final bool alreadyLiked = likedBy[uid] == true;
      final int currentCount = (data['likesCount'] ?? 0) as int;

      if (alreadyLiked) {
        // UNLIKE
        likedBy.remove(uid);
        final newCount = (currentCount - 1).clamp(0, 1 << 30);
        tx.update(noteRef, {
          'likesCount': newCount,
          'likedBy.$uid': FieldValue.delete(),
        });
      } else {
        // LIKE
        final newCount = currentCount + 1;
        tx.update(noteRef, {
          'likesCount': newCount,
          'likedBy.$uid': true,
        });
      }
    });
  }
  Future<void> reportNote({
    required DocumentReference<Map<String, dynamic>> noteRef,
    required String uid,
    required String reason,
  }) async {
    final reportRef = noteRef.collection('reports').doc(uid);
    await reportRef.set({
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Remove the current user's report (optional "Undo report")
  Future<void> unreportNote({
    required DocumentReference<Map<String, dynamic>> noteRef,
    required String uid,
  }) async {
    await noteRef.collection('reports').doc(uid).delete();
  }

  /// Admin: stream all report docs across all notes (newest first)
  Stream<QuerySnapshot<Map<String, dynamic>>> streamAllReportsForAdmin({int limit = 200}) {
    return FirebaseFirestore.instance
        .collectionGroup('reports')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }
}