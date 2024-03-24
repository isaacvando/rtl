app "engine"
    packages {
        pf: "https://github.com/roc-lang/basic-cli/releases/download/0.8.1/x8URkvfyi9I0QhmVG98roKBUs_AZRkLFwFJVJ3942YA.tar.br",
    }
    imports [
        pf.Stdout,
        Pages,
    ]
    provides [main] to pf

main =
    Pages.page {
        name: "Isaac",
        username: "isaacvando",
        names: ["Ashley", "Tony"],
    }
    |> Stdout.line
