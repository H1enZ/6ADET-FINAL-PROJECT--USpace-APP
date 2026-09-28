import 'package:flutter/material.dart';

/// A person's photo in a circle, or their initials when there is no photo
/// (or it fails to load).
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 40,
  });

  final String name;
  final String? imageUrl;
  final double size;

  /// "Ana Reyes" -> "AR", "mikko" -> "M".
  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final initials = Container(
      color: scheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        initialsOf(name),
        style: theme.textTheme.titleMedium?.copyWith(
          fontSize: size * 0.38,
          height: 1,
          color: scheme.primary,
        ),
      ),
    );

    return Semantics(
      label: '$name\'s photo',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: imageUrl == null
              ? initials
              : Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => initials,
                ),
        ),
      ),
    );
  }
}
