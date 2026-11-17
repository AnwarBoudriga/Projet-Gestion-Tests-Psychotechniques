import 'package:flutter/material.dart';

import '../admin/core/api.dart';
import '../admin/core/theme.dart';
import '../admin/core/widgets.dart';
import '../entreprise/core/services/api_client.dart';
import '../entreprise/core/services/auth_service.dart';

enum LoginRole { admin, entreprise }

/// Écran de connexion unique : l'utilisateur choisit s'il entre en tant
/// qu'Administrateur (identifiant + mot de passe) ou qu'Entreprise (clé).
class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({
    super.key,
    required this.onAdminLoggedIn,
    required this.onEntrepriseLoggedIn,
  });

  final VoidCallback onAdminLoggedIn;
  final VoidCallback onEntrepriseLoggedIn;

  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen> {
  final _id = TextEditingController();
  final _pwd = TextEditingController();
  final _key = TextEditingController();

  LoginRole _role = LoginRole.admin;
  bool _loading = false;
  String? _error;

  bool get _isAdmin => _role == LoginRole.admin;

  @override
  void dispose() {
    _id.dispose();
    _pwd.dispose();
    _key.dispose();
    super.dispose();
  }

  void _selectRole(LoginRole role) {
    if (_loading || role == _role) return;
    setState(() {
      _role = role;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_loading) return;

    if (_isAdmin) {
      if (_id.text.trim().isEmpty || _pwd.text.isEmpty) {
        setState(() => _error = 'Identifiant et mot de passe requis.');
        return;
      }
    } else if (_key.text.trim().isEmpty) {
      setState(() => _error = 'La clé entreprise est obligatoire.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isAdmin) {
        await Api.login(_id.text.trim(), _pwd.text);
        // Une seule session active à la fois : on efface le token entreprise.
        await ApiClient.clearToken();
        if (!mounted) return;
        widget.onAdminLoggedIn();
      } else {
        final ok = await AuthService().loginWithCompanyKey(_key.text);
        if (!ok) {
          if (mounted) setState(() => _error = 'Clé entreprise invalide.');
        } else {
          // Une seule session active à la fois : on efface le token admin.
          await Api.logout();
          if (!mounted) return;
          widget.onEntrepriseLoggedIn();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = Api.errorMessage(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 800;
        return Row(children: [
          if (wide)
            Expanded(
              flex: 4,
              child: Container(
                color: C.navy,
                padding: const EdgeInsets.all(40),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Logo(dark: true),
                  const Spacer(),
                  Container(width: 40, height: 2, color: Colors.white54),
                  const SizedBox(height: 16),
                  const Text('Plateforme de Gestion de\nTests Psychotechniques',
                      style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.w300, height: 1.3)),
                  const Spacer(),
                  Row(children: [
                    const Icon(Icons.vpn_key_outlined, size: 14, color: Colors.white54),
                    const SizedBox(width: 8),
                    Text(_isAdmin ? 'Espace Super Administrateur' : 'Accès par clé entreprise',
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ]),
                ]),
              ),
            ),
          Expanded(
            flex: 6,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Logo(),
                    const SizedBox(height: 28),
                    const Text('Connexion', style: TextStyle(fontSize: 26, color: C.navy)),
                    const SizedBox(height: 6),
                    Text(
                      _isAdmin
                          ? 'Saisissez vos identifiants pour accéder au module Super Administrateur.'
                          : 'Saisissez votre clé entreprise pour accéder au module Entreprise (RH).',
                      style: const TextStyle(fontSize: 13, color: C.muted),
                    ),
                    const SizedBox(height: 20),
                    _RoleSwitch(role: _role, onChanged: _selectRole),
                    const SizedBox(height: 20),
                    if (_isAdmin) ...[
                      LabeledField(label: 'Identifiant', controller: _id, hint: 'Saisir votre identifiant'),
                      const SizedBox(height: 16),
                      LabeledField(
                        label: 'Mot de passe',
                        controller: _pwd,
                        hint: 'Saisir votre mot de passe',
                        obscure: true,
                        onSubmitted: (_) => _submit(),
                      ),
                    ] else
                      LabeledField(
                        label: 'Clé entreprise',
                        controller: _key,
                        hint: 'Saisir votre clé entreprise',
                        onSubmitted: (_) => _submit(),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12.5)),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(label: 'Se connecter', loading: _loading, onPressed: _submit),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}

/// Sélecteur de rôle à deux options (Administrateur / Entreprise).
class _RoleSwitch extends StatelessWidget {
  const _RoleSwitch({required this.role, required this.onChanged});

  final LoginRole role;
  final ValueChanged<LoginRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: C.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.border),
      ),
      child: Row(children: [
        _option(LoginRole.admin, 'Administrateur', Icons.admin_panel_settings_outlined),
        const SizedBox(width: 4),
        _option(LoginRole.entreprise, 'Entreprise', Icons.apartment_outlined),
      ]),
    );
  }

  Widget _option(LoginRole value, String label, IconData icon) {
    final selected = role == value;
    return Expanded(
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        elevation: selected ? 0.5 : 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onChanged(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 16, color: selected ? C.teal : C.muted),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? C.teal : C.muted,
                  )),
            ]),
          ),
        ),
      ),
    );
  }
}
