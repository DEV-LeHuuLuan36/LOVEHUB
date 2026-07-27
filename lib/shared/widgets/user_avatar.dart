import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.photoUrl,
    required String name,
    this.size = 48,
    this.textStyle,
  }) : _name = name;

  final String? photoUrl;
  final String _name;
  final double size;
  final TextStyle? textStyle;

  String get _initial {
    final display = displayName(_name);
    if (display.isEmpty) return '?';
    return display[0].toUpperCase();
  }

  static String displayName(String? displayName) {
    if (displayName != null && displayName.trim().isNotEmpty) {
      return displayName.trim().split(' ').first;
    }
    return '';
  }

  static String? photoUrlOrNull(dynamic photoUrl) {
    if (photoUrl == null) return null;
    final s = photoUrl.toString().trim();
    return s.isEmpty ? null : s;
  }

  @override
  Widget build(BuildContext context) {
    final url = photoUrlOrNull(photoUrl);

    if (url != null) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => _initialCircle(loading: true),
          errorWidget: (context, url, error) => _initialCircle(),
        ),
      );
    }

    return _initialCircle();
  }

  Widget _initialCircle({bool loading = false}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6B9D), Color(0xFF9B4DCA)],
        ),
      ),
      child: Center(
        child: loading
            ? SizedBox(
                width: size * 0.4,
                height: size * 0.4,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              )
            : Text(
                _initial,
                style: textStyle ??
                    TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.42,
                      fontWeight: FontWeight.w700,
                    ),
              ),
      ),
    );
  }
}
