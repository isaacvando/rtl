app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.17.0/lZFLstMUCUvd5bjnnpYromZJXkQUrdhbva4xdBInicE.tar.br",
}

import cli.Cmd

main : Task {} [Exit I32 Str]_
main =
    Cmd.exec! "roc" ["build", "../rtl.roc"]
    bash! "../rtl"
    bash! "roc output.roc > output.txt"

bash = \command ->
    Cmd.exec! "bash" ["-c", command]
