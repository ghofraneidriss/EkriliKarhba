import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/user.dart';
import '../domain/user_failures.dart';
import '../services/user_service.dart';
import 'user_form_screen.dart';

/// Dashboard Admin : liste des utilisateurs avec onglets Tous / Admins /
/// Agences / Clients, recherche textuelle, badge de statut coloré et actions
/// (Modifier, Supprimer, Bannir/Débannir, Activer/Désactiver).
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _search = TextEditingController();
  final UserService _service = UserService.instance;

  List<User> _users = const [];
  bool _loading = true;
  String? _error;

  static const _tabs = [null, UserRole.admin, UserRole.agence, UserRole.client];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_load);
    _service.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _tabController.removeListener(_load);
    _tabController.dispose();
    _search.dispose();
    _service.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final role = _tabs[_tabController.index];
      final query = _search.text.trim().isEmpty ? null : _search.text.trim();
      final users = await _service.getUsers(role: role, query: query);
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _onSearchChanged(String _) => _load();

  Future<void> _openForm([User? user]) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UserFormScreen(user: user),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _confirmDelete(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cet utilisateur ?'),
        content: Text(
            '« ${user.displayName} » sera supprimé définitivement.\n'
            'Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.deleteUser(
        userId: user.id!,
        actor: _service.currentUser!,
      );
      messenger.showSnackBar(
        SnackBar(content: Text('${user.displayName} supprimé')),
      );
    } on UserFailure catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  Future<void> _toggleBan(User user) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.toggleBan(
        userId: user.id!,
        actor: _service.currentUser!,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(user.isBanni
              ? '${user.displayName} débanni'
              : '${user.displayName} banni'),
        ),
      );
    } on UserFailure catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.red),
      );
    }
  }

  Future<void> _toggleActive(User user) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.toggleActive(
        userId: user.id!,
        actor: _service.currentUser!,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(user.isActif
              ? '${user.displayName} désactivé'
              : '${user.displayName} activé'),
        ),
      );
    } on UserFailure catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gestion des utilisateurs'),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.tealAccent,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textHeaderSub,
          tabs: const [
            Tab(text: 'Tous'),
            Tab(text: 'Admins'),
            Tab(text: 'Agences'),
            Tab(text: 'Clients'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'adminUsersAddFab',
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Ajouter'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Rechercher (nom, email, téléphone…)',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.inputBorder),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!,
                              style:
                                  const TextStyle(color: AppColors.red)),
                        ),
                      )
                    : _users.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_outline,
                                    size: 48, color: AppColors.textMuted),
                                const SizedBox(height: 8),
                                const Text('Aucun utilisateur trouvé',
                                    style: TextStyle(
                                        color: AppColors.textMuted)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 4, 16, 100),
                              itemCount: _users.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) =>
                                  _UserCard(
                                    user: _users[i],
                                    onEdit: () => _openForm(_users[i]),
                                    onDelete: () =>
                                        _confirmDelete(_users[i]),
                                    onToggleBan: () =>
                                        _toggleBan(_users[i]),
                                    onToggleActive: () =>
                                        _toggleActive(_users[i]),
                                  ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleBan,
    required this.onToggleActive,
  });

  final User user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleBan;
  final VoidCallback onToggleActive;

  Color _roleBadgeColor() => switch (user.role) {
        UserRole.admin => AppColors.primaryBlue,
        UserRole.agence => AppColors.orange,
        UserRole.client => AppColors.green,
      };

  Color _statusBadgeColor() => switch (user.statut) {
        UserStatus.actif => AppColors.green,
        UserStatus.desactive => AppColors.textMuted,
        UserStatus.banni => AppColors.red,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [AppColors.softShadow],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _roleBadgeColor().withValues(alpha: 0.15),
                  child: Text(
                    user.prenom.isNotEmpty
                        ? user.prenom[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: _roleBadgeColor(),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                _Badge(label: user.role.label, color: _roleBadgeColor()),
                const SizedBox(width: 6),
                _Badge(label: user.statut.label, color: _statusBadgeColor()),
              ],
            ),
            if (user.isAgence && user.nomAgence != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const SizedBox(width: 52),
                  Icon(Icons.store_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    user.nomAgence!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 52),
                Icon(Icons.phone_outlined,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(user.telephone,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
                const Spacer(),
                _ActionButton(
                  icon: Icons.edit_outlined,
                  color: AppColors.primaryBlue,
                  tooltip: 'Modifier',
                  onTap: onEdit,
                ),
                _ActionButton(
                  icon: user.isBanni
                      ? Icons.lock_open_outlined
                      : Icons.block_outlined,
                  color: user.isBanni ? AppColors.green : AppColors.orange,
                  tooltip: user.isBanni ? 'Débannir' : 'Bannir',
                  onTap: onToggleBan,
                ),
                _ActionButton(
                  icon: user.isActif
                      ? Icons.toggle_on_outlined
                      : Icons.toggle_off_outlined,
                  color:
                      user.isActif ? AppColors.green : AppColors.textMuted,
                  tooltip: user.isActif ? 'Désactiver' : 'Activer',
                  onTap: onToggleActive,
                ),
                _ActionButton(
                  icon: Icons.delete_outline,
                  color: AppColors.red,
                  tooltip: 'Supprimer',
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      color: color,
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

