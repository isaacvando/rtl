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
import cli.Arg.Opt as Opt
import cli.Arg.Cli as Cli

main : Task {} [Exit I32 Str]_
main =
    Cmd.exec! "roc" ["build", "rtl.roc"]
    Cmd.exec! "bash" ["-c", "echo hello world"]
    Cmd.exec! "bash" ["-c", "./rtl -i benchmarks -o benchmarks && roc benchmarks/output.roc"]

tests = [
    { name: "benchmark", command: "./rtl -i benchmarks -o benchmarks && roc benchmarks/output.roc" },
]
