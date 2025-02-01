# Roc Template Language (RTL)

A template language for Roc with compile time validation and tag unions. RTL can be used with HTML or any other textual content type.

First write a template like `hello.rtl`:

```html
<p>Hello, {{model.name}}!</p>

<ul>
  {|list number : model.numbers |}
  <li>{{ Num.to_str(number) }}</li>
  {|endlist|}
</ul>

{|if model.is_subscribed |}
<a href="/subscription">Subscription</a>
{|else|}
<a href="/signup">Sign up</a>
{|endif|}
```

Then run `rtl` in the directory containing `hello.rtl` to generate `Pages.roc`.

Now you can call the generated function

```roc
Pages.hello({
        name: "World",
        numbers: [1, 2, 3],
        isSubscribed: Bool.true,
    })
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

Right now RTL must be built from source:

```bash
git clone https://github.com/isaacvando/rtl.git
cd rtl
roc build rtl.roc --optimize
sudo mv rtl /usr/local/bin
```

Note that building with `--optimize` may take more than 30s (unoptimized builds are fast).

## How It Works

Running `rtl` in a directory containing `.rtl` templates generates a file called `Pages.roc` which exposes a roc function for each `.rtl` file. Each function accepts a single argument called `model` which can be any type, but will normally be a record.

RTL supports inserting values, conditionally including content, expanding over lists, and pattern matching with when expressions. These constructs all accept normal Roc expressions so there is no need to learn a different set of primitives.

The generated file, `Pages.roc`, becomes a normal part of your Roc project, so you get type checking right out of the box, for free.

### Inserting Values

To interpolate a value into the document, use double curly brackets:

```
{{ model.first_name }}
```

The value between the brackets must be a `Str`, so conversions may be necessary:

```
{{ Num.to_str(2) }}
```

HTML in the interpolated string will be escaped to prevent security issues like XSS.

### Lists

Generate a list of values by specifying a pattern for a list element and the list to be expanded over.

```html
{|list paragraph : model.paragraphs |}
<p>{{ paragraph }}</p>
{|endlist|}
```

The pattern can be any normal Roc pattern so things like this are also valid:

```html
{|list (x,y) : [(1,2),(3,4)] |}
<p>X: {{ Num.to_str(x) }}, Y: {{ Num.to_str(y) }}</p>
{|endlist|}
```

### When-Is

Use when is expressions like this:

```
{|when x |}
    {|is Ok(y) |} The result was ok!
    {|is Err(_)|} The result was an error!
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

If it is necessary to insert content without escaping HTML, use triple brackets.

```
{{{ model.dynamic_html }}}
```

This is useful for generating content types other than HTML or combining multiple templates into one final HTML output.

### Imports

You can import a module into the template like this.

```
{|import MyModule |}
```

## Tips

### Hot Reloading

You can achieve a pretty decent "hot reloading" experience with a command like this:

```bash
fswatch -o . -e ".*" -i "\\.rtl$" | xargs -n1 -I{} sh -c 'lsof -ti tcp:8000 | xargs kill -9 && rtl && roc server.roc &'
```

### Syntax Highlighting

If you want to get the syntax highlighting for the ambient content type in all of your `.rtl` files in VS Code, you can create a file association like this in `settings.json`:

```json
"files.associations": {
  "*.rtl": "html"
}
```

## Talk

I gave a talk about RTL at LambdaConf 2024 called [_Writing a Type-Safe HTML Template Language for Roc_](https://youtu.be/VXQub6U_BUM?si=8rzBNBRZHo0i5X1O) which explains how RTL takes advantages of Roc features like structural typing and type inference.

## Todo

- [ ] Allow more control for whitespace around RTL tags.
- [ ] Allow RTL tags to be escaped.
- [ ] Look into real hot code reloading.
- [ ] Potentially update the generated code to use buffer passing style to avoid unnecessary copies.
- [ ] Benchmark runtime performance against other template languages.
- [ ] Potentially add error messages for incomplete tags.
