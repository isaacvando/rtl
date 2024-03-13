interface Pages
    exposes [page]
    imports []

page = \{} ->
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
            {|if true |}
            <h1>Hello, $(first) $(last)!</h1>
            {|endif|}
        </div>
    </body>
    </html>
    """
