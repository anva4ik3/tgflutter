import 'package:flutter/material.dart';
import '../theme.dart';

class AppAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final double size;
  final bool showOnline;
  final bool isOnline;

  const AppAvatar({
    super.key, required this.name, this.url, required this.size,
    this.showOnline = false, this.isOnline = false,
  });

  Color get _color {
    final colors = [
      AppColors.primary, const Color(0xFF2ECC71), const Color(0xFFE74C3C),
      const Color(0xFF9B59B6), const Color(0xFFE67E22), const Color(0xFF1ABC9C),
      const Color(0xFF3498DB), const Color(0xFFF39C12),
    ];
    if (name.isEmpty) return colors[0];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  String get _initials {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    Widget avatar;
    if (url != null && url!.isNotEmpty && !url!.startsWith('data:')) {
      avatar = CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(url!),
        backgroundColor: _color.withOpacity(0.2),
      );
    } else {
      avatar = CircleAvatar(
        radius: size / 2,
        backgroundColor: _color.withOpacity(0.25),
        child: Text(_initials,
            style: TextStyle(color: _color, fontWeight: FontWeight.bold, fontSize: size * 0.38)),
      );
    }
    if (!showOnline) return avatar;
    return Stack(children: [
      avatar,
      Positioned(
        right: 0, bottom: 0,
        child: Container(
          width: size * 0.28, height: size * 0.28,
          decoration: BoxDecoration(
            color: isOnline ? AppColors.online : AppColors.offline,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.bg2, width: 1.5),
          ),
        ),
      ),
    ]);
  }
}
