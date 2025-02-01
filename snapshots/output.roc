app [main!] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.19.0/Hj-J_zxz7V9YurCSTFcFdu6cQJie4guzsPMUi5kBYUk.tar.br",
}

import cli.Stdout
import Pages

main! = |_|
    Pages.template(
        {
            items: ["first", "second", "third", "fourth", "fifth"],
            condition: Bool.true,
            animal: Cat({ name: "Gob", age: 10 }),
        },
    )
    |> Stdout.line!
