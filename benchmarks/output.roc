app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.15.0/SlwdbJ-3GR7uBWQo6zlmYWNYOxnvo8r6YABXD-45UOw.tar.br",
}

import cli.Stdout
import Pages

main =
    Pages.lorem {
        name: "Benchmark",
        color: Red,
        items: List.range { start: At 0, end: At 500 },
    }
    |> Stdout.line
