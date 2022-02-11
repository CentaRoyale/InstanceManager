import 'dart:io';

Future<void> changePort(File propertiesFile, int port) async {
  var lines = await propertiesFile.readAsLines();
  var keys = {};
  for (var line in lines) {
    if (line.startsWith("#")) {
      continue;
    }
    keys[line.split("=")[0]] = line.split("=")[1];
  }
  keys["server-port"] = port.toString();
  var out = "";
  keys.forEach((key, value) {
    out += "$key=$value\n";
  });
  await propertiesFile.writeAsString(out);
}
