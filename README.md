# CSV [![Build Status](https://github.com/beatrichartz/csv/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/beatrichartz/csv) [![Coverage Status](https://coveralls.io/repos/github/beatrichartz/csv/badge.svg?branch=main)](https://coveralls.io/github/beatrichartz/csv?branch=main) [![Inline docs](http://inch-ci.org/github/beatrichartz/csv.svg?branch=main)](http://inch-ci.org/github/beatrichartz/csv) [![Hex pm](http://img.shields.io/hexpm/v/csv.svg?style=flat)](https://hex.pm/packages/csv) [![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/csv/) [![License](https://img.shields.io/hexpm/l/csv.svg)](https://github.com/beatrichartz/csv/blob/main/LICENSE) [![Downloads](https://img.shields.io/hexpm/dw/csv.svg?style=flat)](https://hex.pm/packages/csv)

[RFC 4180](http://tools.ietf.org/html/rfc4180) compliant CSV parsing and encoding for Elixir. Allows to specify other separators, so it could also be named: TSV. Why it is not idk, because of defaults I think.

## Why do we want it?

It parses files which contain rows (in UTF-8) separated by either commas or other separators.

If that's not enough reason to absolutely :heart: it, it also parses a CSV file in order about 2x times as fast as an unparallelized stream implementation :rocket:

## When do we want it?

Now.

## How do I get it?

Add
```elixir
{:csv, "~> 2.5"}
```
to your deps in `mix.exs` like so:

```elixir
defp deps do
  [
    {:csv, "~> 2.5"}
  ]
end
```

### Elixir version requirements
* Elixir `1.5.0` is required for all versions above `2.5.0`.
* Elixir `1.1.0` is required for all versions above `1.1.5`.

## Great! How do I use it right now?

There are two interesting things you want to do regarding CSV - encoding end decoding.

### Decoding

Do this to decode:

````elixir
File.stream!("data.csv") |> CSV.decode
````

And you'll get a stream of row tuples:
````elixir
[ok: ["a", "b"], ok: ["c", "d"]]
````

And, potentially error tuples:
````elixir
[error: "Row has length 3 - expected length 2 on line 1", ok: ["c", "d"]]
````

Use the bang to decode! into a two-dimensional list, raising errors as they
occur:
````elixir
File.stream!("data.csv") |> CSV.decode!
````

Be sure to [read more about `decode`](https://hexdocs.pm/csv/CSV.html#decode/2)
and [its angry sibling `decode!`](https://hexdocs.pm/csv/CSV.html#decode!/2)

### Encoding

Do this to encode a table (two-dimensional list):

````elixir
table_data |> CSV.encode
````

And you'll get a stream of lines ready to be written to an IO.
So, this is writing to a file:

````elixir
file = File.open!("test.csv", [:write, :utf8])
table_data |> CSV.encode |> Enum.each(&IO.write(file, &1))
````

## I have this file, but it's tab-separated :interrobang:

Pass in another separator to the decoder:

````elixir
File.stream!("data.csv") |> CSV.decode(separator: ?\t)
````

If you want to take revenge on whoever did this to you, encode with semicolons
like this:

````elixir
your_data |> CSV.encode(separator: ?;)
````

You can also specify headers when encoding, which will encode map values into
the right place:

````elixir
[%{"a" => "value!"}] |> CSV.encode(headers: ["z", "a"])
# ["z,a\\r\\n", ",value!\\r\\n"]
````

You can also specify a keyword list, the keys of the list will be used as the keys for the rows, 
but the values will be the value used for the header row name in CSV output

````elixir
[%{a: "value!"}] |> CSV.encode(headers: [a: "x", b: "y"])
# ["x,y\\r\\n", "value!,\\r\\n"]
````

You'll surely appreciate some [more info on `encode`](https://hexdocs.pm/csv/CSV.html#encode/2).

## Polymorphic encoding

Make sure your data gets encoded the way you want - implement the `CSV.Encode`
protocol for whatever strange you wish to encode:

````elixir
defimpl CSV.Encode, for: MyData do
  def encode(%MyData{has: fun}, env \\ []) do
    "so much #{fun}" |> CSV.Encode.encode(env)
  end
end
````

Or similar.

## Ensure performant encoding

The encoding protocol implements a fallback to Any for types where a simple call
o `to_string` will provide unambiguous results. Protocol dispatch for the
fallback to Any is *very* slow when protocols are not consolidated, so make sure
you [have `consolidate_protocols: true`](http://blog.plataformatec.com.br/2015/04/build-embedded-and-start-permanent-in-elixir-1-0-4/)
in your `mix.exs` or you consolidate protocols manually for production in order
to get good performance.

There is more to know about everything :tm: - [Check the doc](http://hexdocs.pm/csv/)

## Contributions & Bugfixes are most welcome!

Please make sure to add tests. I will not look at PRs that are
either failing or lowering coverage. Also, solve one problem at
a time.

## Copyright and License

Copyright (c) 2022 Beat Richartz

CSV source code is licensed under the [MIT License](https://github.com/beatrichartz/csv/blob/main/LICENSE).
