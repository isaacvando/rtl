app [main!] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.18.0/0APbwVN1_p1mJ96tXjaoiUCr8NBGamr8G8Ac_DrXR-o.tar.br",
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
