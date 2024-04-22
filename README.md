# Roc Template Language (RTL)
An HTML template language for Roc with compile time validation and tag unions.

First write a template like `hello.rtl`:
```
<p>Hello, {{model.name}}!</p>

<ul>
{|list number : model.numbers |}
    <li>{{Num.toStr number}}</li>
{|endlist|}
</ul>

{|if model.isSubscribed |}
<a href="/subscription">Subscription</a>
{|else|}
<a href="/signup">Sign up</a>
{|endif|}
```
Then run `rtl` in the directory containing `hello.rtl` to generate `Pages.roc`.

Now you can call the generated function
```roc
Pages.hello {
        name: "World",
        numbers: [1, 2, 3],
        isSubscribed: Bool.true,
    }
```
to generate your HTML!
```html
<p>Hello, World!</p>

<ul>
    <li>1</li>
    <li>2</li>
    <li>3</li>
</ul>

<a href="/subscription">Subscription</a>
```

## Installation

Right now RTL must be built locally. For a quick start, run these commands to build RTL and place it in `/usr/local/bin`.
```bash
wget https://github.com/isaacvando/rtl/archive/refs/heads/main.zip
unzip main.zip
roc build rtl-main/rtl.roc --optimize
sudo mv rtl-main/rtl /usr/local/bin
rm -r rtl-main main.zip
rtl --help
```

## How It Works
Running `rtl` in a directory containing `.rtl` templates generates a file called `Pages.roc` which exposes a roc function for each `.rtl` file. Each function accepts a single argument called `model` which can be any type, but will normally be a record.

RTL supports inserting values, conditionally including content, expanding over lists, and pattern matching with when expressions. These constructs all accept normal Roc expressions so there is no need to learn a different set of primitives.

The generated file, `Pages.roc`, becomes a normal part of your Roc project, so you get type checking right out of the box, for free.

### Inserting Values

To interpolate a value into the document, use double curly brackets:
```
{{ model.firstName }}
```
The value between the brackets must be a `Str`, so conversions may be necessary:
```
{{ 2 |> Num.toStr }}
```
HTML in the interpolated string will be escaped to prevent security issues like XSS.

### Lists
Generate a list of values by specifying a pattern for a list element and the list to be expanded over.
```
{|list paragraph : model.paragraphs |}
<p>{{ paragraph }}</p>
{|endlist|}
```

The pattern can be any normal Roc pattern so things like this are also valid:
```
{|list (x,y) : [(1,2),(3,4)] |}
<p>X: {{ x |> Num.toStr }}, Y: {{ y |> Num.toStr }}</p>
{|endlist|}
```

### When-Is
Use when is expressions like this:
```
{|when x |}
{|is Ok y |} The result was ok!
{|is Err _ |} The result was an error!
{|endwhen|}
```

### Conditionals
Conditionally include content like this:
```
{|if model.x < model.y |}
Conditional content here
{|endif|}
```
Or with an else block:
```
{|if model.x < model.y |}
Conditional content here
{|else|}
Other content
{|endif|}
```

### Raw Interpolation
If it is necessary to insert content into the document without escaping HTML, use triple brackets.
```
{{{ model.dynamicHtml }}}
```

This can be useful for combining multiple templates into one final HTML output.

## Tips

You can achieve a pretty decent "hot reloading" experience with a command like this:
```bash
fswatch -o . -e ".*" -i "\\.rtl$" | xargs -n1 -I{} sh -c 'lsof -ti tcp:8000 | xargs kill -9 && rtl && roc server.roc &'
```

## Todo
- [ ] Properly handle whitespace around rtl expressions.
- [ ] Allow RTL expressions to be escaped.
- [ ] Look into real hot code reloading.
- [ ] Potentially update the generated code to use buffer passing style to avoid unnecessary copies.
- [ ] Benchmark runtime performance against other template languages.
- [ ] Potentially add error messages for incomplete directives.
