# Explanation

In many scenarios it is desirable to share the same outer template for many pages on a website with elements like a nav bar, footer, etc, while letting the content from page to page change. Duplicating the outer portion is certainly undesirable here becuase it would mean that any time we wanted to change something about (for exampole) the footer we would, we would have to change it on all pages.

We can accomplish this in RTL with the existing primitives by rendering the inner content of a page, and then passing that to the function for the outer template. On the outer template, the content from the inner template can then be included using a raw interpolation `{{{ ... }}}` to treat the string as HTML.

This example shows this pattern.
