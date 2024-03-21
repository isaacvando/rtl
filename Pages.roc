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
            
    """,
    
    
        if Bool.true then
                """
                <h1>Hello, world</h1>
                
        """
        else 
            "",
    
    
    """
    
        </div>
    </body>
    </html>
    
    """
    ] |> Str.joinWith ""
    