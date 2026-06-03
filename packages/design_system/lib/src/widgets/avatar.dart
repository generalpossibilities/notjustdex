import 'package:flutter/material.dart';

class DexChatsAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? initials;
  final double size;

  const DexChatsAvatar({
    super.key,
    this.imageUrl,
    this.initials,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(imageUrl!),
      );
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        initials ?? '?',
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
