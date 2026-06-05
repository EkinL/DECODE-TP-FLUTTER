import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/routes.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Not Found'),
      ),
      body: SizedBox(
        width: .infinity,
        child: Column(
          crossAxisAlignment: .center,
          mainAxisAlignment: .center,
          spacing: 16,
          children: [
            const Text('Oops! The page you are looking for does not exist.'),
            ElevatedButton(
              onPressed: () {
                context.go(rtHome);
              },
              child: const Text('Retour à l\'accueil'),
            ),
          ],
        ),
      ),
    );
  }
}
