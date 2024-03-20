interface Pages
    exposes [page]
    imports []

page = \{ h1, ello, first, last, true } ->
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
            
        </div>
    </body>
    </html>
    """
    