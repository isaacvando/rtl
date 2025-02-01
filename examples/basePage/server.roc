app [Model, respond!, init!] { pf: platform "https://github.com/roc-lang/basic-webserver/releases/download/0.12.0/Q4h_In-sz1BqAvlpmCsBHhEJnn_YvfRRMiNACB_fBbk.tar.br" }

import Pages

Model : {}

init! = |{}| Ok({})

respond! = |req, _|
    when Str.split_on(req.uri, "/") |> List.drop_first(1) is
        ["first"] ->
            Pages.base(
                {
                    content: Pages.first(
                        {
                            foo: "very nice string",
                        },
                    ),
                },
            )
            |> success

        ["second"] | _ ->
            Pages.base(
                {
                    content: Pages.second(
                        {
                            bar: 100,
                        },
                    ),
                },
            )
            |> success

success = |body|
    Ok(
        {
            status: 200,
            headers: [{ name: "Content-Type", value: "text/html" }],
            body: body |> Str.to_utf8,
        },
    )
