/// La cuenta con la sesión abierta: nombre e ítem (número de empleado).
class AccountInfo {
  final String name;
  final String? item;

  const AccountInfo({required this.name, this.item});

  /// Lee `{ name, item }` de `GET /auth/me`; null si no trae un nombre.
  static AccountInfo? fromUserJson(dynamic user) {
    if (user is! Map) return null;
    final name = user['name']?.toString().trim() ?? '';
    if (name.isEmpty) return null;
    final item = user['item']?.toString().trim();
    return AccountInfo(
      name: name,
      item: item == null || item.isEmpty ? null : item,
    );
  }
}
