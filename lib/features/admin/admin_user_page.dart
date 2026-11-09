// This file is part of mPlayer.
// Copyright (C) 2026 Nam <namicedtea@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
// See the LICENSE file at the app root for the full notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../servers/server_admin.dart';
import '../../widgets/section_header.dart';
import 'admin_activity_page.dart' show ActivityEntryRow;
import 'admin_providers.dart';
import 'admin_widgets.dart';

/// One account, in two tabs: what it may do (Profile), and what it has been
/// doing and from where (Activity). Its password and deleting it are behind
/// the ⋮.
///
/// Two tabs rather than one long page because the two are asked at different
/// times: the editor is a form with a Save at its foot, and the activity is a
/// log that would push that form a screen further down every week.
///
/// **The editor is a draft.** Nothing reaches the server until Save, and Save
/// sends the whole draft at once — a switch that wrote on every flip would be
/// a policy read and written whole a dozen times over, each one racing the
/// last. Leaving with changes unsaved asks first.
class AdminUserPage extends ConsumerStatefulWidget {
  const AdminUserPage({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<AdminUserPage> createState() => _AdminUserPageState();
}

class _AdminUserPageState extends ConsumerState<AdminUserPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    // The Save bar belongs to the Profile tab; redraw when the tab changes.
    ..addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// The account as the server last described it, which the draft is
  /// compared against to know whether there is anything to save.
  AdminUserDetail? _source;
  UserPolicy? _draft;
  bool _saving = false;

  bool get _dirty =>
      _source != null && _draft != null && _draft != _source!.policy;

  void _edit(UserPolicy Function(UserPolicy) change) {
    final draft = _draft;
    if (draft == null) return;
    setState(() => _draft = change(draft));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(adminUserProvider(widget.userId));
    final isSelf = ref.watch(currentAdminUserIdProvider) == widget.userId;

    // A fresh answer from the server — the first one, or the one a save or a
    // pull brought back — replaces the draft. Kept across rebuilds otherwise,
    // or every switch flipped would be thrown away by the next frame.
    final loaded = detail.value;
    if (loaded != null && !identical(loaded, _source)) {
      _source = loaded;
      _draft = loaded.policy;
    }

    final name = _source?.user.name ?? l10n.adminUsers;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final leave = await confirmAdminAction(
          context,
          title: l10n.adminDiscardQuestion,
          body: l10n.adminDiscardBody,
          confirmLabel: l10n.adminDiscard,
        );
        if (!leave || !mounted) return;
        // Dropping the draft first lets the pop through the PopScope.
        setState(() => _draft = _source?.policy);
        navigator.pop();
      },
      child: AdminScaffold(
        title: name,
        actions: <Widget>[
          if (_source != null) _UserMenu(detail: _source!, isSelf: isSelf),
        ],
        tabs: TabBar(
          controller: _tabs,
          tabs: <Widget>[
            Tab(text: l10n.adminTabProfile),
            Tab(text: l10n.adminTabActivity),
          ],
        ),
        onRefresh: () async {
          ref
            ..invalidate(adminUserProvider(widget.userId))
            ..invalidate(adminLibrariesProvider)
            ..invalidate(adminUserDevicesProvider(widget.userId));
          final user = _source?.user;
          if (user != null) {
            ref.invalidate(
              adminUserActivityProvider((id: user.id, name: user.name)),
            );
          }
          await ref.read(adminUserProvider(widget.userId).future);
        },
        bottomBar: _draft == null || _tabs.index != 0
            ? null
            : _saveBar(context, l10n, name),
        child: TabBarView(
          controller: _tabs,
          children: <Widget>[
            _profile(detail, l10n, isSelf),
            _UserActivity(userId: widget.userId, name: _source?.user.name),
          ],
        ),
      ),
    );
  }

  Widget _profile(
    AsyncValue<AdminUserDetail?> detail,
    AppLocalizations l10n,
    bool isSelf,
  ) {
    return switch (detail) {
      AsyncError(:final error) => AdminList(
        emptyText: '$error',
        children: const <Widget>[],
      ),
      _ when _draft == null => AdminList(
        loading: detail.isLoading,
        emptyText: l10n.adminUserNotFound,
        children: const <Widget>[],
      ),
      _ => _PolicyEditor(
        detail: _source!,
        policy: _draft!,
        isSelf: isSelf,
        onChanged: _edit,
      ),
    };
  }

  Widget _saveBar(BuildContext context, AppLocalizations l10n, String name) {
    final spacing = context.spacing;

    return Material(
      color: context.colors.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.screenHorizontal(context.windowSize),
            vertical: spacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _dirty && !_saving
                      ? () => setState(() => _draft = _source?.policy)
                      : null,
                  child: Text(l10n.actionCancel),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: _dirty && !_saving ? () => _save(name) : null,
                  child: _saving
                      ? SizedBox.square(
                          dimension: spacing.lg,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(l10n.actionSave),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save(String name) async {
    final draft = _draft;
    if (draft == null) return;

    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);

    await runAdminAction(
      context,
      ref,
      action: (admin) => admin.setUserPolicy(widget.userId, draft),
      success: l10n.adminUserSaved(name),
      refresh: () => ref
        ..invalidate(adminUserProvider(widget.userId))
        ..invalidate(adminUsersProvider),
    );

    if (mounted) setState(() => _saving = false);
  }
}

/// The Activity tab: the devices the account signs in from, then the log.
class _UserActivity extends ConsumerWidget {
  const _UserActivity({required this.userId, required this.name});

  final String userId;

  /// Null until the account has loaded — the log is asked for by name too.
  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final devices = ref.watch(adminUserDevicesProvider(userId));
    final accountName = name;
    final entries = accountName == null
        ? const AsyncLoading<List<ActivityEntry>>()
        : ref.watch(adminUserActivityProvider((id: userId, name: accountName)));

    return AdminList(
      children: <Widget>[
        SectionHeader(title: l10n.adminDevices),
        ...switch (devices) {
          AsyncData(:final value) when value.isNotEmpty => <Widget>[
            for (final AdminDevice device in value)
              ListTile(
                leading: const Icon(Icons.devices_rounded),
                title: Text(device.name.isEmpty ? device.appName : device.name),
                subtitle: Text(
                  <String>[
                    <String>[
                      device.appName,
                      device.appVersion,
                    ].where((s) => s.isNotEmpty).join(' '),
                    relativeTime(device.lastSeen, l10n),
                  ].where((s) => s.isNotEmpty).join(' · '),
                ),
              ),
          ],
          AsyncError(:final error) => <Widget>[AdminNote(text: '$error')],
          AsyncLoading() => const <Widget>[
            Center(child: CircularProgressIndicator()),
          ],
          _ => <Widget>[AdminNote(text: l10n.adminNoDevices)],
        },
        SizedBox(height: spacing.sectionGap),
        SectionHeader(title: l10n.adminActivity),
        ...switch (entries) {
          AsyncData(:final value) when value.isNotEmpty => <Widget>[
            for (final ActivityEntry entry in value)
              ActivityEntryRow(entry: entry),
          ],
          AsyncError(:final error) => <Widget>[AdminNote(text: '$error')],
          AsyncLoading() => const <Widget>[
            Center(child: CircularProgressIndicator()),
          ],
          _ => <Widget>[AdminNote(text: l10n.adminNoUserActivity)],
        },
      ],
    );
  }
}

/// Set password and Delete, behind the app bar's ⋮.
class _UserMenu extends ConsumerWidget {
  const _UserMenu({required this.detail, required this.isSelf});

  final AdminUserDetail detail;
  final bool isSelf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return PopupMenuButton<VoidCallback>(
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (action) => action(),
      itemBuilder: (menuContext) => <PopupMenuEntry<VoidCallback>>[
        PopupMenuItem<VoidCallback>(
          value: () => _setPassword(context, ref, l10n),
          child: ListTile(
            leading: const Icon(Icons.password_rounded),
            title: Text(l10n.adminSetPassword),
          ),
        ),
        // Deleting yourself would end the session this screen runs in, with
        // the section answering 403 from then on; the server allows it while
        // another administrator exists, which is not reason enough to offer.
        if (!isSelf)
          PopupMenuItem<VoidCallback>(
            value: () => _delete(context, ref, l10n),
            child: ListTile(
              leading: Icon(
                Icons.person_remove_outlined,
                color: context.colors.error,
              ),
              title: Text(
                l10n.adminDeleteUser,
                style: TextStyle(color: context.colors.error),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _setPassword(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _PasswordDialog(),
    );
    if (password == null || !context.mounted) return;

    final name = detail.user.name;
    await runAdminAction(
      context,
      ref,
      action: (admin) => admin.setUserPassword(detail.user.id, password),
      success: password.isEmpty
          ? l10n.adminPasswordRemoved(name)
          : l10n.adminPasswordChanged(name),
      refresh: () => ref.invalidate(adminUserProvider(detail.user.id)),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final name = detail.user.name;
    final sure = await confirmAdminAction(
      context,
      title: l10n.adminDeleteUserQuestion(name),
      body: l10n.adminDeleteUserBody,
      confirmLabel: l10n.adminDeleteUser,
    );
    if (!sure || !context.mounted) return;

    final router = GoRouter.of(context);
    final deleted = await runAdminAction(
      context,
      ref,
      action: (admin) => admin.deleteUser(detail.user.id),
      success: l10n.adminUserDeleted(name),
      refresh: () => ref
        ..invalidate(adminUsersProvider)
        ..invalidate(adminDevicesProvider),
    );

    // There is nothing left to show here.
    if (deleted && router.canPop()) router.pop();
  }
}

/// The policy, as switches and pickers grouped the way Jellyfin's own editor
/// groups them.
class _PolicyEditor extends ConsumerWidget {
  const _PolicyEditor({
    required this.detail,
    required this.policy,
    required this.isSelf,
    required this.onChanged,
  });

  final AdminUserDetail detail;
  final UserPolicy policy;
  final bool isSelf;
  final void Function(UserPolicy Function(UserPolicy)) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;

    final libraries = ref.watch(adminLibrariesProvider);
    final ratings =
        ref.watch(parentalRatingsProvider).value ??
        const <ParentalRatingOption>[];

    final user = detail.user;
    final summary = <String>[
      if (isSelf) l10n.adminUserYou,
      detail.hasPassword ? l10n.adminHasPassword : l10n.adminNoPassword,
      if (user.lastActivity != null) relativeTime(user.lastActivity, l10n),
    ].where((s) => s.isNotEmpty).join(' · ');

    return AdminList(
      children: <Widget>[
        ListTile(
          leading: CircleAvatar(
            backgroundColor: context.colors.primaryContainer,
            child: Icon(
              policy.isAdministrator
                  ? Icons.shield_outlined
                  : Icons.person_outline_rounded,
              color: context.colors.onPrimaryContainer,
            ),
          ),
          title: Text(user.name),
          subtitle: Text(summary),
        ),

        // ------------------------------------------------------- account
        SectionHeader(title: l10n.adminSectionAccount),
        SwitchListTile(
          title: Text(l10n.adminUserAdmin),
          subtitle: Text(
            isSelf ? l10n.adminPolicySelf : l10n.adminPolicyAdminBody,
          ),
          value: policy.isAdministrator,
          onChanged: isSelf
              ? null
              : (v) => onChanged(
                  // The server refuses a disabled administrator, so making
                  // one an administrator turns it back on in the same write.
                  (p) => p.copyWith(
                    isAdministrator: v,
                    isDisabled: v ? false : null,
                  ),
                ),
        ),
        SwitchListTile(
          title: Text(l10n.adminUserDisabled),
          subtitle: Text(
            isSelf
                ? l10n.adminPolicySelf
                : policy.isAdministrator
                ? l10n.adminPolicyAdminNotDisabled
                : l10n.adminPolicyDisabledBody,
          ),
          value: policy.isDisabled,
          onChanged: isSelf || policy.isAdministrator
              ? null
              : (v) => onChanged((p) => p.copyWith(isDisabled: v)),
        ),
        SwitchListTile(
          title: Text(l10n.adminPolicyHidden),
          value: policy.isHidden,
          onChanged: (v) => onChanged((p) => p.copyWith(isHidden: v)),
        ),

        // ----------------------------------------------------- libraries
        SizedBox(height: spacing.md),
        SectionHeader(title: l10n.adminSectionLibraries),
        SwitchListTile(
          title: Text(l10n.adminPolicyAllLibraries),
          subtitle: Text(l10n.adminPolicyAllLibrariesBody),
          value: policy.enableAllFolders,
          onChanged: (v) => onChanged((p) => p.copyWith(enableAllFolders: v)),
        ),
        if (!policy.enableAllFolders) ..._libraryRows(context, l10n, libraries),

        // ------------------------------------------------------ playback
        SizedBox(height: spacing.md),
        SectionHeader(title: l10n.adminSectionPlayback),
        _switch(
          l10n.adminPolicyPlayback,
          policy.enableMediaPlayback,
          (p, v) => p.copyWith(enableMediaPlayback: v),
        ),
        _switch(
          l10n.adminPolicyVideoTranscoding,
          policy.enableVideoTranscoding,
          (p, v) => p.copyWith(enableVideoTranscoding: v),
        ),
        _switch(
          l10n.adminPolicyAudioTranscoding,
          policy.enableAudioTranscoding,
          (p, v) => p.copyWith(enableAudioTranscoding: v),
        ),
        _switch(
          l10n.adminPolicyRemuxing,
          policy.enableRemuxing,
          (p, v) => p.copyWith(enableRemuxing: v),
        ),
        SwitchListTile(
          title: Text(l10n.adminPolicyRemoteAccess),
          subtitle: Text(l10n.adminPolicyRemoteAccessBody),
          value: policy.enableRemoteAccess,
          onChanged: (v) => onChanged((p) => p.copyWith(enableRemoteAccess: v)),
        ),
        _ChoiceTile<int>(
          title: l10n.adminPolicyBitrate,
          value: policy.remoteBitrateLimit,
          options: _withCurrent(_bitrates, policy.remoteBitrateLimit),
          label: (bps) =>
              bps <= 0 ? l10n.adminNoLimit : l10n.adminMbps(formatMbps(bps)),
          onChanged: (v) => onChanged((p) => p.copyWith(remoteBitrateLimit: v)),
        ),
        _ChoiceTile<int>(
          title: l10n.adminPolicySessions,
          value: policy.maxActiveSessions,
          options: _withCurrent(_sessionCounts, policy.maxActiveSessions),
          label: (n) => n <= 0 ? l10n.adminNoLimit : '$n',
          onChanged: (v) => onChanged((p) => p.copyWith(maxActiveSessions: v)),
        ),

        // ------------------------------------------------------- content
        SizedBox(height: spacing.md),
        SectionHeader(title: l10n.adminSectionContent),
        _switch(
          l10n.adminPolicyDownloads,
          policy.enableContentDownloading,
          (p, v) => p.copyWith(enableContentDownloading: v),
        ),
        _switch(
          l10n.adminPolicyDeletion,
          policy.enableContentDeletion,
          (p, v) => p.copyWith(enableContentDeletion: v),
        ),
        _switch(
          l10n.adminPolicyCollections,
          policy.enableCollectionManagement,
          (p, v) => p.copyWith(enableCollectionManagement: v),
        ),

        // ------------------------------------------------------ parental
        SizedBox(height: spacing.md),
        SectionHeader(title: l10n.adminSectionParental),
        _ChoiceTile<_Rating>(
          title: l10n.adminPolicyMaxRating,
          value: _Rating(policy.maxParentalRating, policy.maxParentalSubRating),
          options: _ratingOptions(ratings, policy),
          label: (r) => _ratingLabel(r, ratings, l10n),
          onChanged: (r) => onChanged(
            (p) => p.copyWith(
              parentalRating: (score: r.score, subScore: r.subScore),
            ),
          ),
        ),
      ],
    );
  }

  Widget _switch(
    String title,
    bool value,
    UserPolicy Function(UserPolicy, bool) change,
  ) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: (v) => onChanged((p) => change(p, v)),
    );
  }

  List<Widget> _libraryRows(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<List<AdminLibrary>> libraries,
  ) {
    final list = libraries.value;
    if (list == null) {
      return <Widget>[
        if (libraries.hasError)
          ListTile(title: Text('${libraries.error}'))
        else
          const Center(child: CircularProgressIndicator()),
      ];
    }
    if (list.isEmpty) {
      return <Widget>[ListTile(title: Text(l10n.adminNoLibraries))];
    }

    return <Widget>[
      for (final AdminLibrary library in list)
        CheckboxListTile(
          title: Text(library.name),
          value: policy.enabledFolders.contains(library.id),
          onChanged: (checked) => onChanged(
            (p) => p.copyWith(
              enabledFolders: <String>[
                // A grant for a library since deleted is kept as it was:
                // it is the server's to clean up, and dropping it here would
                // be a change nobody asked for.
                for (final String id in p.enabledFolders)
                  if (id != library.id) id,
                if (checked ?? false) library.id,
              ],
            ),
          ),
        ),
    ];
  }

  /// No limit, then the steps Jellyfin's own editor's users tend to pick.
  static const List<int> _bitrates = <int>[
    0,
    1000000,
    2000000,
    4000000,
    8000000,
    10000000,
    15000000,
    20000000,
    40000000,
    60000000,
    80000000,
    120000000,
  ];

  static const List<int> _sessionCounts = <int>[0, 1, 2, 3, 4, 5, 10];

  /// [options] with [current] in its place, so a value set from the web
  /// client that is not one of the steps here is still shown as chosen
  /// rather than silently replaced by the nearest one.
  static List<int> _withCurrent(List<int> options, int current) {
    if (options.contains(current)) return options;
    return <int>[...options, current]..sort();
  }

  static List<_Rating> _ratingOptions(
    List<ParentalRatingOption> ratings,
    UserPolicy policy,
  ) {
    final current = _Rating(
      policy.maxParentalRating,
      policy.maxParentalSubRating,
    );
    final options = <_Rating>[
      const _Rating(null, null),
      for (final ParentalRatingOption r in ratings)
        _Rating(r.score, r.subScore),
    ];
    if (!options.contains(current)) options.add(current);
    return options;
  }

  static String _ratingLabel(
    _Rating rating,
    List<ParentalRatingOption> ratings,
    AppLocalizations l10n,
  ) {
    final score = rating.score;
    if (score == null) return l10n.adminNoLimit;
    for (final ParentalRatingOption r in ratings) {
      if (r.score == score && r.subScore == rating.subScore) return r.name;
    }
    return l10n.adminRatingScore(score);
  }
}

/// "8", "1.5", "120" — megabits, without a trailing ".0".
String formatMbps(int bitsPerSecond) {
  final mbps = bitsPerSecond / 1000000;
  if (mbps == mbps.roundToDouble()) return '${mbps.round()}';
  return mbps.toStringAsFixed(1);
}

@immutable
class _Rating {
  const _Rating(this.score, this.subScore);

  final int? score;
  final int? subScore;

  @override
  bool operator ==(Object other) =>
      other is _Rating && other.score == score && other.subScore == subScore;

  @override
  int get hashCode => Object.hash(score, subScore);
}

/// A row whose value is one of a short list, picked from a dialog.
///
/// A dialog rather than a dropdown in the trailing slot: the labels are as
/// long as a rating list makes them ("PG-13 / TV-14"), and a trailing
/// dropdown on a phone is where those get cut in half.
class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.value,
    required this.options,
    required this.label,
    required this.onChanged,
  });

  final String title;
  final T value;
  final List<T> options;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(label(value)),
      trailing: const Icon(Icons.arrow_drop_down_rounded),
      onTap: () async {
        final picked = await showDialog<_Picked<T>>(
          context: context,
          builder: (dialogContext) => SimpleDialog(
            title: Text(title),
            children: <Widget>[
              for (final T option in options)
                SimpleDialogOption(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(_Picked<T>(option)),
                  child: Row(
                    children: <Widget>[
                      Expanded(child: Text(label(option))),
                      if (option == value)
                        Icon(
                          Icons.check_rounded,
                          color: context.colors.primary,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
        if (picked != null) onChanged(picked.value);
      },
    );
  }
}

/// Wraps a pick so that choosing a null-ish option is told apart from
/// dismissing the dialog.
class _Picked<T> {
  const _Picked(this.value);
  final T value;
}

/// Asks for a new password twice. Answers the password, empty for none, or
/// null when cancelled.
class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _mismatch = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (_password.text != _confirm.text) {
      setState(() => _mismatch = true);
      return;
    }
    Navigator.of(context).pop(_password.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;

    return AlertDialog(
      title: Text(l10n.adminSetPassword),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: _password,
              autofocus: true,
              obscureText: true,
              autofillHints: const <String>[AutofillHints.newPassword],
              decoration: InputDecoration(labelText: l10n.adminNewPassword),
              onChanged: (_) {
                if (_mismatch) setState(() => _mismatch = false);
              },
            ),
            SizedBox(height: spacing.md),
            TextField(
              controller: _confirm,
              obscureText: true,
              autofillHints: const <String>[AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: l10n.adminConfirmPassword,
                errorText: _mismatch ? l10n.adminPasswordMismatch : null,
              ),
              onChanged: (_) {
                if (_mismatch) setState(() => _mismatch = false);
              },
              onSubmitted: (_) => _submit(),
            ),
            SizedBox(height: spacing.md),
            Text(
              l10n.adminPasswordEmptyHint,
              style: context.texts.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.actionSave)),
      ],
    );
  }
}

/// Asks for a new account's name and, optionally, its password. Answers
/// null when cancelled.
Future<({String name, String password})?> showCreateUserDialog(
  BuildContext context,
) {
  return showDialog<({String name, String password})>(
    context: context,
    builder: (_) => const _CreateUserDialog(),
  );
}

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _name = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) return;
    Navigator.of(
      context,
    ).pop((name: _name.text.trim(), password: _password.text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.adminNewUserTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: _name,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.adminUserNameLabel),
              // Create follows the name: an account with no name is not one
              // the server will make.
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: context.spacing.md),
            TextField(
              controller: _password,
              obscureText: true,
              autofillHints: const <String>[AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: l10n.adminPasswordOptional,
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty ? null : _submit,
          child: Text(l10n.adminCreate),
        ),
      ],
    );
  }
}
