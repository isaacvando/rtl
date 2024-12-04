app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.17.0/lZFLstMUCUvd5bjnnpYromZJXkQUrdhbva4xdBInicE.tar.br",
}

import cli.Stdout
import Pages

main =
    Pages.template {
        items: ["first", "second", "third", "fourth", "fifth"],
        condition: Bool.true,
        animal: Cat { name: "Gob", age: 10 },
    }
    |> Stdout.line
