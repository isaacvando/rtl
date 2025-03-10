## Generated by RTL https://github.com/isaacvando/rtl
module [
    home,
    blog_post,
]

import Format

home = |model|
    [
        """
        <!doctype html>
        <html>
            <head>
                <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
                <title>Roc Template Example Blog</title>
            </head>
            <body>
                <div>
                    <h1>Posts</h1>
                    <ul>
                        
        """,
        List.map(
            model.posts,
            |post|
                """

                                <li>
                                    <a href="/posts/${post.slug |> escape_html}">${post.title |> escape_html}</a>
                                </li>
                                
                """,
        )
        |> Str.join_with(""),
        """

                    </ul>
                </div>
            </body>
        </html>

        """,
    ]
    |> Str.join_with("")

blog_post = |model|
    [
        """

        <!doctype html>
        <html>
            <head>
                <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
                <title>
                    ${model.post.title |> Format.to_upper |> Result.with_default("") |> escape_html} -
                    Roc Template Example
                </title>
            </head>
            <body>
                <div>
                    <h1>${model.post.title |> escape_html}</h1>
                    
        """,
        List.map(
            model.post.content,
            |item|
                [
                    " ",
                    when item is
                        Text(t) ->
                            """

                                        <p>${t |> escape_html}</p>
                                        
                            """

                        Code(c) ->
                            """

                                        <pre>${c |> escape_html}</pre>
                                        
                            """

                        Image(i) ->
                            """
                             <img src="${i |> escape_html}" width="100" />
                                        
                            """,
                    " ",
                ]
                |> Str.join_with(""),
        )
        |> Str.join_with(""),
        """

                    <br />
                    <a href="/">Home</a>
                </div>
            </body>
        </html>

        """,
    ]
    |> Str.join_with("")

escape_html : Str -> Str
escape_html = |input|
    input
    |> Str.replace_each("&", "&amp;")
    |> Str.replace_each("<", "&lt;")
    |> Str.replace_each(">", "&gt;")
    |> Str.replace_each("\"", "&quot;")
    |> Str.replace_each("'", "&#39;")
