app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.10.0/vNe6s9hWzoTZtFmNkvEICPErI9ptji_ySjicO6CkucY.tar.br",
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
