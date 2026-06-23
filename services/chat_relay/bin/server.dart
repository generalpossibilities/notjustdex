import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:args/args.dart';
import '../lib/relay_server.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('port', abbr: 'p', defaultsTo: '8585')
    ..addOption('host', abbr: 'h', defaultsTo: '0.0.0.0')
    ..addFlag('help', abbr: '?', defaultsTo: false);

  final parsed = parser.parse(args);
  if (parsed['help'] as bool) {
    print('Usage: dart run bin/server.dart [options]');
    print(parser.usage);
    exit(0);
  }

  final port = int.parse(parsed['port'] as String);
  final host = parsed['host'] as String;
  final relay = RelayServer();

  final handler = Cascade()
    .add(relay.healthHandler)
    .add(relay.handler)
    .handler;

  final server = await shelf_io.serve(handler, host, port);
  print('Chat relay running on ws://$host:$port/ws');
  print('Health: http://$host:$port/');

  // Graceful shutdown
  ProcessSignal.sigint.watch().listen((_) {
    print('\nShutting down...');
    relay.dispose();
    server.close();
    exit(0);
  });
}
