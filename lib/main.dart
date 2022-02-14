import 'dart:convert';

import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:http/http.dart' as http;

Map<String, RemoteServer> servers = {};
Map<String, String> serverIds = {};

List<Remote> remotes = [Remote(Uri.parse("http://localhost:9000"))];

Future<RemoteServer> createServer(String id, String repo) async {
  Map<int, int> remotesAndServerCountMap = {};
  remotes.asMap().forEach((key, value) {
    remotesAndServerCountMap[key] = 0;
  });
  for (var key in remotes.asMap().keys) {
    var value = remotes.asMap()[key];
    remotesAndServerCountMap[key] = await value.serverCount;
  }
  List<int> remotesAndServerCount = remotesAndServerCountMap.values.toList();
  remotesAndServerCount.sort((a, b) => a.compareTo(b));
  var remoteIndex;
  try {
    remoteIndex = remotesAndServerCount.where((element) => element >= 20).first;
  } on StateError {
    remoteIndex = remotesAndServerCount.first;
  }
  var remote = remotes[remoteIndex];

  var server = await remote.createServer(id, repo);

  servers[server.ip + ":" + server.port.toString()] = server;
  serverIds[id] = server.ip + ":" + server.port.toString();

  return server;
}

class Remote {
  Uri url;

  Future<int> get serverCount async {
    var r = await http.get(Uri(
      scheme: url.scheme,
      host: url.host,
      port: url.port,
      path: '/count',
    ));
    return int.tryParse(r.body) ?? 0;
  }

  Remote(this.url);

  Future<RemoteServer> createServer(String id, String repo) async {
    var uri = Uri(
      scheme: url.scheme,
      host: url.host,
      port: url.port,
      path: url.path + "/create",
    );
    var r = await http.put(uri, body: json.encode({"repo": repo, "id": id}));
    var data = json.decode(r.body);
    return RemoteServer(
        data["port"], data["ip"], id, Uri.parse(data["editUrl"]));
  }
}

class RemoteServer {
  int port;
  String ip;
  String id;
  Uri editUrl;
  Map<String, dynamic> data;

  RemoteServer(this.port, this.ip, this.id, this.editUrl);

  Future<void> sendCommand(String command) async {
    http.post(
        Uri(
          scheme: editUrl.scheme,
          host: editUrl.host,
          port: editUrl.port,
          path: editUrl.path + "/stdin",
        ),
        body: command);
  }
}

void main(List<String> args) async {
  var app = Router();

  app.put('/server/<id>', (Request request, String id) async {
    var strData = await request.readAsString();
    var server = await createServer(
      id,
      (json.decode(strData)["repo"]) ?? "https://github.com/Xd-pro/testRepo",
    );
    if (servers.containsKey(id)) {
      return Response.forbidden(json.encode({"error": "id already exists"}));
    }
    servers[id] = server;
    await Future.delayed(Duration(seconds: 5));
    return Response.ok(jsonEncode({
      "ip": server.ip,
      "port": server.port,
    }));
  });

  app.post("/server/<id>", (Request request, String id) async {
    var strData = await request.readAsString();
    var server = servers[id];
    server.data = json.decode(strData);
    return Response.ok(json.encode({"success": true}));
  });

  app.delete('/server/<ip>/<port>', (Request request, String ip, String port) {
    servers.remove(ip + ":" + port);
    serverIds.removeWhere((key, value) => value == ip + ":" + port);
    return Response.ok(jsonEncode({"success": true}));
  });

  app.get("/server", (Request request) {
    return Response.ok(jsonEncode(serverIds.map((id, serverKey) {
      var server = servers[serverKey];
      return MapEntry(id, {
        "ip": server.ip,
        "port": server.port,
        "id": server.id,
        "editUrl": server.editUrl.toString(),
        "data": server.data
      });
    })));
  });

  app.get("/server/<id>", (Request request, String id) {
    if (!serverIds.containsKey(id)) {
      return Response.notFound(json.encode({"error": "id not found"}));
    }
    var server = servers[serverIds[id]];
    return Response.ok(json.encode({
      "ip": server.ip,
      "port": server.port,
      "id": server.id,
      "editUrl": server.editUrl.toString(),
      "data": server.data
    }));
  });
  var server = await io.serve(app, 'localhost', 8080);
}
