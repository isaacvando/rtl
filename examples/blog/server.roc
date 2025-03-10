app [Model, respond!, init!] { pf: platform "https://github.com/roc-lang/basic-webserver/releases/download/0.12.0/Q4h_In-sz1BqAvlpmCsBHhEJnn_YvfRRMiNACB_fBbk.tar.br" }

import Pages

Model : {}

init! = |{}| Ok({})

respond! = |req, _|
    when Str.split_on(req.uri, "/") |> List.drop_first(1) is
        ["posts", slug] ->
            post =
                List.find_first(
                    posts,
                    |p|
                        p.slug == slug,
                )
                |> try
            Pages.blog_post(
                {
                    post,
                },
            )
            |> success

        [""] | _ ->
            Pages.home({ posts }) |> success

posts = [
    {
        title: "How to write a template engine in Roc",
        slug: "template-engine",
        content: [Text("Roc's type inference shines through here. It makes it easy to write a template language with compile time errors while having the same feel as dynamic languages.")],
    },
    {
        title: "My story: thinking of blog ideas for this example",
        slug: "my-story",
        content: [Text("What follows is a code block:"), Code("[1,2,3] |> List.map \\x -> x * x")],
    },
    {
        title: "The last blog post",
        slug: "fin",
        content: [Text("Here's an image"), Image("https://www.roc-lang.org/favicon.svg")],
    },
]

success = |body|
    Ok(
        {
            status: 200,
            headers: [{ name: "Content-Type", value: "text/html" }],
            body: body |> Str.to_utf8,
        },
    )
