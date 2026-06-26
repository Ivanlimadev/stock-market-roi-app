import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/comments_provider.dart';
import '../theme/app_theme.dart';

/// Shared discussion area for blog posts and asset pages (app + site parity).
/// Drop `CommentsSection(target: (type: 'post', id: slug))` at the bottom of a
/// page. Reading is public; posting/liking requires a signed-in user.
class CommentsSection extends ConsumerStatefulWidget {
  final CommentTarget target;
  const CommentsSection({super.key, required this.target});

  @override
  ConsumerState<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<CommentsSection> {
  final _ctrl = TextEditingController();
  Comment? _replyingTo;
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _loggedIn =>
      Supabase.instance.client.auth.currentUser != null;

  Future<void> _refresh() async =>
      ref.invalidate(commentsProvider(widget.target));

  Future<void> _send() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await CommentsService.post(
        t: widget.target,
        body: body,
        parentId: _replyingTo?.id,
      );
      _ctrl.clear();
      _replyingTo = null;
      if (mounted) FocusScope.of(context).unfocus();
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not post your comment.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleLike(Comment c) async {
    try {
      await CommentsService.toggleLike(c.id, c.likedByMe);
      await _refresh();
    } catch (_) {/* ignore — next refresh corrects state */}
  }

  Future<void> _edit(Comment c) async {
    final updated = await _composeDialog(initial: c.body, title: 'Edit comment');
    if (updated == null || updated.trim().isEmpty) return;
    await CommentsService.edit(c.id, updated);
    await _refresh();
  }

  Future<void> _delete(Comment c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete comment', style: TextStyle(fontSize: 16)),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TextStyle(color: context.colors.textMuted))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await CommentsService.delete(c.id);
    await _refresh();
  }

  Future<String?> _composeDialog(
      {required String initial, required String title}) {
    final ctrl = TextEditingController(text: initial);
    final c = context.colors;
    return showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 5,
          minLines: 2,
          maxLength: 2000,
          style: TextStyle(color: c.textPrimary),
          decoration: InputDecoration(
            hintStyle: TextStyle(color: c.textMuted),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.emerald)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: c.textMuted))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final async = ref.watch(commentsProvider(widget.target));

    return Container(
      margin: const EdgeInsets.only(top: 28),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.surfaceAlt),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.forum_outlined, size: 18, color: c.textSecond),
            const SizedBox(width: 8),
            Text('Discussion',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary)),
            const SizedBox(width: 6),
            async.maybeWhen(
              data: (l) => Text('${l.length}',
                  style: TextStyle(fontSize: 13, color: c.textMuted)),
              orElse: () => const SizedBox.shrink(),
            ),
          ]),
          const SizedBox(height: 14),
          _composer(c),
          const SizedBox(height: 8),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text('Could not load comments.',
                  style: TextStyle(fontSize: 13, color: c.textMuted)),
            ),
            data: (all) => _list(c, all),
          ),
        ],
      ),
    );
  }

  // ── Composer ───────────────────────────────────────────────────────────────

  Widget _composer(AppThemeColors c) {
    if (!_loggedIn) {
      return GestureDetector(
        onTap: () => context.push('/login'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(Icons.lock_outline_rounded, size: 16, color: c.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Sign in to join the discussion',
                  style: TextStyle(fontSize: 13, color: c.textSecond)),
            ),
            Text('Sign in',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.emerald)),
          ]),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_replyingTo != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Icon(Icons.reply_rounded, size: 14, color: c.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text('Replying to ${_replyingTo!.authorName ?? 'user'}',
                    style: TextStyle(fontSize: 12, color: c.textMuted),
                    overflow: TextOverflow.ellipsis),
              ),
              GestureDetector(
                onTap: () => setState(() => _replyingTo = null),
                child: Icon(Icons.close_rounded, size: 16, color: c.textMuted),
              ),
            ]),
          ),
        TextField(
          controller: _ctrl,
          minLines: 1,
          maxLines: 5,
          maxLength: 2000,
          style: TextStyle(color: c.textPrimary, fontSize: 14),
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
              null,
          decoration: InputDecoration(
            hintText: _replyingTo != null
                ? 'Write a reply…'
                : 'Share your view…',
            hintStyle: TextStyle(color: c.textMuted),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.emerald)),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _sending ? null : _send,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(_replyingTo != null ? 'Reply' : 'Post'),
          ),
        ),
      ],
    );
  }

  // ── List ─────────────────────────────────────────────────────────────────

  Widget _list(AppThemeColors c, List<Comment> all) {
    final tops = all.where((x) => x.parentId == null).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final repliesByParent = <String, List<Comment>>{};
    for (final x in all.where((x) => x.parentId != null)) {
      repliesByParent.putIfAbsent(x.parentId!, () => []).add(x);
    }

    if (tops.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Center(
          child: Text('No comments yet. Be the first to share.',
              style: TextStyle(fontSize: 13, color: c.textMuted)),
        ),
      );
    }

    return Column(
      children: [
        for (final top in tops) ...[
          const SizedBox(height: 14),
          _CommentTile(
            comment: top,
            onLike: () => _toggleLike(top),
            onReply: () => setState(() {
              _replyingTo = top;
            }),
            onEdit: top.isMine ? () => _edit(top) : null,
            onDelete: top.isMine ? () => _delete(top) : null,
          ),
          for (final reply in (repliesByParent[top.id] ?? [])
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt)))
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 12),
              child: _CommentTile(
                comment: reply,
                onLike: () => _toggleLike(reply),
                onReply: () => setState(() => _replyingTo = top),
                onEdit: reply.isMine ? () => _edit(reply) : null,
                onDelete: reply.isMine ? () => _delete(reply) : null,
              ),
            ),
        ],
      ],
    );
  }
}

// ── Single comment ───────────────────────────────────────────────────────────

class _CommentTile extends StatelessWidget {
  final Comment comment;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CommentTile({
    required this.comment,
    required this.onLike,
    required this.onReply,
    this.onEdit,
    this.onDelete,
  });

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${d.inDays ~/ 7}w';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final name = (comment.authorName?.isNotEmpty ?? false)
        ? comment.authorName!
        : 'User';
    final initial = name[0].toUpperCase();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.emerald.withValues(alpha: 0.15),
          backgroundImage: comment.authorAvatar != null
              ? NetworkImage(comment.authorAvatar!)
              : null,
          child: comment.authorAvatar == null
              ? Text(initial,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.emerald))
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(name,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 6),
                Text('· ${_ago(comment.createdAt)}',
                    style: TextStyle(fontSize: 12, color: c.textMuted)),
                if (comment.edited) ...[
                  const SizedBox(width: 4),
                  Text('· edited',
                      style: TextStyle(fontSize: 11, color: c.textMuted)),
                ],
                if (onEdit != null || onDelete != null)
                  _OwnerMenu(onEdit: onEdit, onDelete: onDelete),
              ]),
              const SizedBox(height: 3),
              Text(comment.body,
                  style: TextStyle(
                      fontSize: 14, height: 1.45, color: c.textSecond)),
              const SizedBox(height: 6),
              Row(children: [
                GestureDetector(
                  onTap: onLike,
                  child: Row(children: [
                    Icon(
                      comment.likedByMe
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 15,
                      color: comment.likedByMe
                          ? AppColors.red
                          : c.textMuted,
                    ),
                    if (comment.likeCount > 0) ...[
                      const SizedBox(width: 4),
                      Text('${comment.likeCount}',
                          style: TextStyle(fontSize: 12, color: c.textMuted)),
                    ],
                  ]),
                ),
                const SizedBox(width: 18),
                GestureDetector(
                  onTap: onReply,
                  child: Text('Reply',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: c.textMuted)),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

class _OwnerMenu extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const _OwnerMenu({this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 20,
      child: PopupMenuButton<int>(
        padding: EdgeInsets.zero,
        iconSize: 16,
        icon: Icon(Icons.more_horiz_rounded, color: c.textMuted),
        color: c.surface,
        onSelected: (v) => v == 0 ? onEdit?.call() : onDelete?.call(),
        itemBuilder: (_) => [
          if (onEdit != null)
            const PopupMenuItem(value: 0, child: Text('Edit')),
          if (onDelete != null)
            PopupMenuItem(
                value: 1,
                child: Text('Delete',
                    style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
  }
}
