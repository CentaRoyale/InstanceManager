import 'dart:convert';
import 'dart:io';

import 'package:server_scaler/utils/properties.dart';
import 'package:server_scaler/utils/range.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:http/http.dart' as http;

final PORT_RANGE = range(19132, 20000);
final Map<int, LocalServer> servers = {};

const MAIN = 'http://localhost:8080';

String ip;
void main(List<String> args) async {
  ip = await File("ip").readAsString();

  var app = Router();

  app.put("/create", (Request request) async {
    var data = jsonDecode(await request.readAsString());

    var port = 19132;
    while (servers.containsKey(port)) {
      port++;
      if (port > 20000) {
        port = 19132;
      }
    }

    var server = LocalServer(
      port,
      data["repo"],
      data["id"],
      (exitCode) {
        servers.remove(port);
      },
    );

    servers[port] = server;
    server.start();
    return Response.ok(jsonEncode({
      "port": port,
      "ip": ip,
      "editUrl": "http://${ip}:9000/server/$port",
    }));
  });

  await io.serve(app, "localhost", 9000);
}

class LocalServer {
  final int port;
  bool open = false;
  String repo;
  Function(int) onExit;
  String id;

  LocalServer(this.port, this.repo, this.id, this.onExit);

  Future<void> start() async {
    open = true;
    if (await Directory("instances/$port").exists()) {
      await Directory("instances/$port").delete(recursive: true);
    }
    await Process.run("git", ["clone", repo, "instances/$port"]);
    File("instances/$port/id").writeAsString(id);
    await changePort(File("instances/$port/server.properties"), port);
    var proc = await Process.start(
        "instances/$port/start.cmd".replaceAll("/", Platform.pathSeparator),
        []);
    proc.exitCode.then(_onExit);

    proc.stdout.transform(utf8.decoder).forEach(print);
    proc.stderr.transform(utf8.decoder).forEach(print);
  }

  _onExit(int exitCode) async {
    open = false;
    await http.delete(Uri.parse(MAIN + "/server/${ip}/$port"));
    onExit(exitCode);
  }
}
