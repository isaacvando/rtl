app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.15.0/SlwdbJ-3GR7uBWQo6zlmYWNYOxnvo8r6YABXD-45UOw.tar.br",
}

import cli.Stdout
import cli.File
import cli.Path exposing [Path]
import cli.Dir
import cli.Arg
import cli.Cmd
import cli.Utc exposing [Utc]
import cli.Arg
import cli.Arg.Opt
import cli.Arg.Cli

import Cli {
    now: Utc.now,
    line: Stdout.line,
    readUtf8: File.readUtf8,
    writeUtf8: File.writeUtf8,
    display: Path.display,
    cmdNew: Cmd.new,
    cmdStatus: Cmd.status,
    cmdArgs: Cmd.args,
    deltaAsMillis: Utc.deltaAsMillis,
    dirCreateAll: Dir.createAll,
    dirList: Dir.list,
    parseOrDisplayMessage: Arg.Cli.parseOrDisplayMessage,
    cliFinish: Arg.Cli.finish,
    cliAssertValid: Arg.Cli.assertValid,
    cliMaybeStr: Arg.Opt.maybeStr,
    cliCombine: Arg.Cli.combine,
    argList: Arg.list,
}

main : Task {} [Exit I32 Str]_
main =
    Cli.cli
