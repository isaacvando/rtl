interface Pages
    exposes [
        page,
        hello
    ]
    imports []

page = \model ->
    [
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
            <title>Roc Template Example</title>
            <link rel="icon" href="/favicon.svg">
        </head>
        <body>
            <div>
                <strong>$(model.name |> escapeHtml)</strong>
                
        """,
        if Bool.true then
            [
                """
                <h1>Hello, $(model.username |> escapeHtml)</h1>
                        <p>
                            a paragraph here
                        </p>
                            
                """,
                if Bool.true then
                    """
                    nesting!
                                
                    """
                else
                    "",
                if model.username == "isaacvando" then
                    """
                    inline!
                    """
                else
                    ""
            ]
            |> Str.joinWith ""
        else
            "",
        """
        <p>paragraph after the endif</p>
                
        """,
        List.map model.names \name ->
            [
                """
                <em>Hello, $(name |> escapeHtml)!</em>
                        
                """,
                if Str.startsWith name "foo" then
                    [
                        """
                        $(name |> escapeHtml) starts with foo!
                                <ul>
                                
                        """,
                        List.map [1,2,3,4] \x ->
                            """
                            <li>$(Num.toStr x |> escapeHtml)</li>
                                    
                            """
                        |> Str.joinWith "",
                        """
                        </ul>
                                
                        """
                    ]
                    |> Str.joinWith ""
                else
                    ""
            ]
            |> Str.joinWith ""
        |> Str.joinWith "",
        """
        
                
        """,
        if Bool.false then
            """
            This should be $("<strong>bold</strong>")
                    <br>
                    
            """
        else
            """
            This should be $("<strong>escaped</strong>" |> escapeHtml)
                    
            """,
        """
        </div>
        </body>
        </html>
        
        """
    ]
    |> Str.joinWith ""

hello = \model ->
    [
        """
        <p>Hello, $(model.name |> escapeHtml)!</p>
        
        <ul>
        
        """,
        List.map model.numbers \number ->
            """
            <li>$(Num.toStr number |> escapeHtml)</li>
            
            """
        |> Str.joinWith "",
        """
        </ul>
        
        
        """,
        if model.isSubscribed then
            """
            <a href="/subscription">Subscription</a>
            """
        else
            """
            <a href="/signup">Sign up</a>
            """
    ]
    |> Str.joinWith ""

escapeHtml : Str -> Str
escapeHtml = \input ->
    input
    |> Str.replaceEach "&" "&amp;"
    |> Str.replaceEach "<" "&lt;"
    |> Str.replaceEach ">" "&gt;"
    |> Str.replaceEach "\"" "&quot;"
    |> Str.replaceEach "'" "&#39;"
