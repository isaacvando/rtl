app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.14.0/dC5ceT962N_4jmoyoffVdphJ_4GlW3YMhAPyGPr-nU0.tar.br",
}

import cli.Stdout
import cli.Task exposing [Task]
import Pages

main =
    Pages.lorem {
        name: "Benchmark",
        color: Red,
        items: List.range { start: At 0, end: At 500 },
    }
    |> Stdout.line
