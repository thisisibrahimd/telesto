import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:pocketbase/pocketbase.dart';

late PocketBase pb;

Future<void> main(List<String> arguments) async {
  var runner = CommandRunner("telesto-cli", "cli to interact with telesto.")
    ..addCommand(GetCommand());

  runner.argParser.addOption(
    'pb-endpoint',
    abbr: 'e',
    help: 'pocketbase endpoint',
    defaultsTo: "http://telesto.dev/pb/",
  );
  runner.argParser.addOption('pb-email', mandatory: true);
  runner.argParser.addOption('pb-password', mandatory: true);

  late ArgResults results;
  try {
    results = runner.parse(arguments);
    pb = PocketBase(results.option("pb-endpoint")!);
    var pbEmail = results.option("pb-email");
    var pbPassword = results.option("pb-password");
    await pb.collection("users").authWithPassword(pbEmail!, pbPassword!);
  } on ArgumentError catch (error) {
    runner.usageException(error.message);
  } on UsageException catch (error) {
    runner.usageException(error.message);
  } on ArgParserException catch (error) {
    print(error);
    // if (error.commands.isEmpty) usageException(error.message);

    // var command = commands[error.commands.first]!;
    // for (var commandName in error.commands.skip(1)) {
    //   command = command.subcommands[commandName]!;
    // }

    // command.usageException(error.message);
  }

  runner.run(arguments).catchError((error) {
    if (error is! UsageException) throw error;
    print(error);
    exit(64); // Exit code 64 indicates a usage error.
  });
}

class GetClusterComand extends Command {
  @override
  final name = "cluster";
  @override
  final description = "get cluster";

  GetClusterComand() {
    argParser.addOption("name", abbr: "n", mandatory: true);
  }

  @override
  Future<void> run() async {
    try {
      var clusterName = argResults?.option("name");
      await pb.collection("otelcols").getOne(clusterName!);
    } on ArgumentError catch (error) {
      usageException(error.message);
    }
  }
}

class GetCommand extends Command {
  @override
  final name = "get";
  @override
  final description = "get resources";

  GetCommand() {
    addSubcommand(GetClusterComand());
  }
}
