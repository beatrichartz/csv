# CSV [![Build Status](https://github.com/beatrichartz/csv/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/beatrichartz/csv) [![Coverage Status](https://coveralls.io/repos/github/beatrichartz/csv/badge.svg?branch=main)](https://coveralls.io/github/beatrichartz/csv?branch=main) [![Inline docs](http://inch-ci.org/github/beatrichartz/csv.svg?branch=main)](http://inch-ci.org/github/beatrichartz/csv) [![Hex pm](http://img.shields.io/hexpm/v/csv.svg?style=flat)](https://hex.pm/packages/csv) [![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/csv/) [![License](https://img.shields.io/hexpm/l/csv.svg)](https://github.com/beatrichartz/csv/blob/main/LICENSE) [![Downloads](https://img.shields.io/hexpm/dw/csv.svg?style=flat)](https://hex.pm/packages/csv)

[RFC 4180](http://tools.ietf.org/html/rfc4180) compliant CSV parsing and encoding for Elixir.

## Installation

Add
```elixir
{:csv, "~> 3.0"}
```
to your deps in `mix.exs` like so:

```elixir
defp deps do
  [{:csv, "~> 3.0"}]
end
```

## Getting all correctly formatted rows
CSV is a notoriously fickle format, with many implementations and files interpreting it differently.

For that reason, `CSV` implements a normal mode `CSV.decode` that will return a stream of `ok: ["field1", "field2"]`
and `err: "Message"` tuples. 

This allows to extract all correctly formatted rows, while displaying descriptive errors for all incorrectly formatted ones.

In strict mode using `CSV.decode!` the library will raise an exception when it encounters the first error, aborting the
operation.

## Performance
Parallelism has been replaced by a single process binary matching parser with better performance in version 3.x. 
This library is able to parse about half a million rows of a moderately complex CSV file per second in a single process, 
ensuring that parsing will unlikely become a bottleneck.

If you are reading from a large file, `CSV` will perform best when streaming with `:read_ahead` in byte mode:

```elixir
File.stream!("data.csv", [read_ahead: 100_000], 1000) |> CSV.decode()
```

While `1000` is usually a good default number of bytes to stream, you should measure performance and fine-tune
byte size according to your environment.

## Upgrading from 2.x
The main goal for 3.x has been to streamline the library API and leverage binary matching. 

#### Upgrading should require few to no changes in most cases:

- **Parallelism has been removed**, alongside its options `:num_workers` and `:worker_work_ratio`. You can safely remove them.
- **`StrayQuoteError` is now `StrayEscapeCharacterError`**. If you catch this error in your code, you need to rename it.
- **The `:trim_fields` option needs to be replaced** with the `:field_transform` option:
  ```elixir
  File.stream!("data.csv") |> CSV.decode(field_transform: &String.trim/1)
  ```
- **`:validate_row_length` now defaults to `false`**. This option produces an error for rows with different length. Set it
  to `true` to get the same behaviour as in 2.x
- **`:escape_formulas` is now `:unescape_formulas` for `decode` and `decode!`.** It is still `:escape_formulas` for
  `encode`. Change `:escape_formulas` to `:unescape_formulas` in `decode` calls to get the same behaviour as in 2.x
- **`:escape_max_lines` now defaults to `10`** instead of `1000`. To get the same behaviour as in 2.x, use:
  ```elixir
  File.stream!("data.csv") |> CSV.decode(escape_max_lines: 1000)
  ```
- **`:replace` has been removed**. `CSV` will now return fields with incorrect encoding as-is. 
  You can use the new `:field_transform` option to provide a function transforming fields while they are being parsed. 
  This allows to e.g. replace incorrect encoding:
  ```elixir
  defp replace_bad_encoding(field) do
    if String.valid?(field) do
      field
    else
      field
      |> String.codepoints()
      |> Enum.map(fn codepoint -> if String.valid?(codepoint), do: codepoint, else: "?" end)
      |> Enum.join()
    end
  end

  File.stream!("data.csv") |> CSV.decode(field_transform: &replace_bad_encoding/1)
  ```

**That's it!** Please open an issue if you see any other non-backward compatible behaviour so it can be documented.

### Elixir version requirements
* Elixir `1.5.0` is required for all versions above `2.5.0`.
* Elixir `1.1.0` is required for all versions above `1.1.5`.

## Usage
`CSV` can decode and encode from and to a stream of bytes or lines.

### Decoding

Do this to decode data:

````elixir
# Decode file line by line
File.stream!("data.csv")
|> CSV.decode()

# Decode file in chunks of 1000 bytes
File.stream!("data.csv", [], 1000) 
  |> CSV.decode()

# Decode a csv formatted string
["long,csv,string\\nwith,multiple,lines"] 
  |> Stream.map(&(&1)) 
  |> CSV.decode()

# Decode a list of arbitrarily chunked csv data
["list,", "of,arbitrarily", "\\nchun", "ked,csv,data\\n"] 
  |> Stream.map(&(&1)) 
  |> CSV.decode()
````

And you'll get a stream of row tuples:
````elixir
[ok: ["a", "b"], ok: ["c", "d"]]
````

And, potentially error tuples:
````elixir
[error: "", ok: ["c", "d"]]
````

Use strict mode `decode!` to get a two-dimensional list, raising errors as they
occur, aborting the operation:
````elixir
File.stream!("data.csv") |> CSV.decode!
````

#### Options

For all available options [check the docs on `decode`](https://hexdocs.pm/csv/CSV.html#decode/2)
[and `decode!`](https://hexdocs.pm/csv/CSV.html#decode!/2)

Specify a semicolon separator:

````elixir
stream |> CSV.decode(separator: ?;)
````

Specify a custom escape character:

````elixir
stream |> CSV.decode(escape_character: ?@)
````

Apply a transformation to a field when parsed, e.g. trimming the field:

````elixir
stream |> CSV.decode(field_transform: &String.trim/1)
````

Unescape formulas that have been escaped:

````elixir
stream |> CSV.decode(unescape_formulas: true)
````


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

#### Options

Use a semicolon separator:

````elixir
your_data |> CSV.encode(separator: ?;)
````

Use a specific escape character:

````elixir
your_data |> CSV.encode(escape_character: ?@)
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

#### Polymorphic encoding

Make sure your data gets encoded the way you want - implement the `CSV.Encode`
protocol for whatever you wish to encode:

````elixir
defimpl CSV.Encode, for: MyData do
  def encode(%MyData{has: fun}, env \\ []) do
    "so much #{fun}" |> CSV.Encode.encode(env)
  end
end
````

Or similar.

#### Ensure performant encoding

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
