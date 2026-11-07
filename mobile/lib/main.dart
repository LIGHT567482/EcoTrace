import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api.dart';
import 'core/session.dart';
import 'core/widgets.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = Api();
  final session = Session(api);
  runApp(EcoTraceApp(session: session));
}

class EcoTraceApp extends StatefulWidget {
  final Session session;
  const EcoTraceApp({super.key, required this.session});

  @override
  State<EcoTraceApp> createState() => _EcoTraceAppState();
}

class _EcoTraceAppState extends State<EcoTraceApp> {
  late Future<void> _init;

  @override
  void initState() {
    super.initState();
    _init = widget.session.init();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<Session>.value(
      value: widget.session,
      child: MaterialApp(
        title: 'EcoTrace',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: FutureBuilder<void>(
          future: _init,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final session = context.watch<Session>();
            if (session.user == null) return const LoginScreen();
            return const HomeShell();
          },
        ),
      ),
    );
  }
}
