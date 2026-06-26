import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A comment thread target = (entityType, entityId). Dart records give value
/// equality, so this works directly as a Riverpod family key.
/// `type` is one of 'stock' | 'crypto' | 'post'; `id` is the symbol or post slug.
typedef CommentTarget = ({String type, String id});

class Comment {
  final String id;
  final String userId;
  final String body;
  final int likeCount;
  final bool edited;
  final DateTime createdAt;
  final String? parentId;
  final String? authorName;
  final String? authorAvatar;
  final bool likedByMe;

  const Comment({
    required this.id,
    required this.userId,
    required this.body,
    required this.likeCount,
    required this.edited,
    required this.createdAt,
    required this.parentId,
    required this.authorName,
    required this.authorAvatar,
    required this.likedByMe,
  });

  factory Comment.fromJson(Map<String, dynamic> j, {required bool likedByMe}) {
    final author = j['author'] as Map<String, dynamic>?;
    return Comment(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      body: j['body'] as String,
      likeCount: (j['like_count'] as num?)?.toInt() ?? 0,
      edited: j['edited'] as bool? ?? false,
      createdAt: DateTime.parse(j['created_at'] as String),
      parentId: j['parent_id'] as String?,
      authorName: author?['display_name'] as String?,
      authorAvatar: author?['avatar_url'] as String?,
      likedByMe: likedByMe,
    );
  }

  bool get isMine => userId == Supabase.instance.client.auth.currentUser?.id;
}

class CommentsService {
  CommentsService._();
  static SupabaseClient get _c => Supabase.instance.client;

  /// Fetches every comment for [t] (top-level + replies), each annotated with
  /// the author's public profile and whether the current user has liked it.
  static Future<List<Comment>> fetch(CommentTarget t) async {
    final rows = await _c
        .from('comments')
        .select(
            'id,user_id,body,like_count,edited,created_at,parent_id,author:profiles(display_name,avatar_url)')
        .eq('entity_type', t.type)
        .eq('entity_id', t.id)
        .order('created_at', ascending: true);

    final list = List<Map<String, dynamic>>.from(rows);

    // Which of these did the signed-in user like?
    var liked = <String>{};
    final myId = _c.auth.currentUser?.id;
    if (myId != null && list.isNotEmpty) {
      final ids = list.map((r) => r['id'] as String).toList();
      final likeRows = await _c
          .from('comment_likes')
          .select('comment_id')
          .eq('user_id', myId)
          .inFilter('comment_id', ids);
      liked = {
        for (final r in List<Map<String, dynamic>>.from(likeRows))
          r['comment_id'] as String
      };
    }

    return [
      for (final r in list)
        Comment.fromJson(r, likedByMe: liked.contains(r['id'] as String))
    ];
  }

  static Future<void> post({
    required CommentTarget t,
    required String body,
    String? parentId,
  }) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return;
    await _c.from('comments').insert({
      'user_id': uid,
      'entity_type': t.type,
      'entity_id': t.id,
      'body': body.trim(),
      'parent_id': parentId,
    });
  }

  static Future<void> edit(String id, String body) =>
      _c.from('comments').update({'body': body.trim()}).eq('id', id);

  static Future<void> delete(String id) =>
      _c.from('comments').delete().eq('id', id);

  static Future<void> toggleLike(String commentId, bool currentlyLiked) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return;
    if (currentlyLiked) {
      await _c
          .from('comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', uid);
    } else {
      await _c
          .from('comment_likes')
          .insert({'comment_id': commentId, 'user_id': uid});
    }
  }
}

/// All comments for a target (flat list; the UI groups replies under parents).
final commentsProvider =
    FutureProvider.autoDispose.family<List<Comment>, CommentTarget>(
        (ref, t) => CommentsService.fetch(t));

/// Total comment count for a target (used in headers / badges).
final commentCountProvider =
    FutureProvider.autoDispose.family<int, CommentTarget>((ref, t) async {
  final list = await ref.watch(commentsProvider(t).future);
  return list.length;
});
