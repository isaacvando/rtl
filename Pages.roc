interface Pages
    exposes [page]
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
                <strong>$(model.name)</strong>
                
        """,
        if Bool.true then
            """
            <h1>Hello, $(model.username)</h1>
                    <p>
                        a paragraph here
                    </p>
                    
            """
        else
            "",
        """
        <p>paragraph after the endif</p>
            </div>
        </body>
        </html>
        
        """
    ]
    |> Str.joinWith ""