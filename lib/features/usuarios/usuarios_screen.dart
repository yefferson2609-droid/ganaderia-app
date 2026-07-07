import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/perfil_usuario.dart';
import '../../core/repositories/perfil_usuario_repository.dart';

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  final _repo = PerfilUsuarioRepository();
  List<PerfilUsuario> _usuarios = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _usuarios = await _repo.getAll();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        leading: BackButton(onPressed: () => context.go('/dashboard')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            context.push('/usuarios/nuevo').then((_) => _load()),
        child: const Icon(Icons.person_add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _usuarios.isEmpty
              ? const Center(child: Text('No hay usuarios registrados'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _usuarios.length,
                    itemBuilder: (_, i) {
                      final u = _usuarios[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: u.activo
                                ? const Color(0xFFE8F5E9)
                                : Colors.grey[200],
                            child: Icon(Icons.person,
                                color: u.activo
                                    ? const Color(0xFF2E7D32)
                                    : Colors.grey),
                          ),
                          title: Text(u.nombre,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text(u.correo),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context
                              .push('/usuarios/${u.id}/permisos')
                              .then((_) => _load()),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
