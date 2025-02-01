app [main!] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.19.0/Hj-J_zxz7V9YurCSTFcFdu6cQJie4guzsPMUi5kBYUk.tar.br",
}

import cli.Stdout
import Pages

main! = |_|
    Pages.lorem(
        {
            name: "Benchmark",
            color: Red,
            items: List.range({ start: At(0), end: At(500) }),
        },
    )
    |> Stdout.line!
