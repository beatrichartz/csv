# CSV [![Build Status](https://travis-ci.org/beatrichartz/csv.svg?branch=master)](https://travis-ci.org/beatrichartz/csv) [![Inline docs](http://inch-ci.org/github/beatrichartz/csv.svg?branch=master)](http://inch-ci.org/github/beatrichartz/csv)
[RFC 4180](http://tools.ietf.org/html/rfc4180) compliant CSV parsing and encoding for Elixir. Allows to specify other separators, so it could also be named: TSV. Why it is not idk, because of defaults I think.

## Why do we want it?

It parses files which contain rows (in utf-8) separated by either commas or other separators.

If that's not enough reason to absolutely :heart: :green_heart: :two_hearts: :heart: :revolving_hearts: :sparkling_heart: it, it also parses a CSV file in order about 2x times as fast as an unparallelized stream implementation, and if you don't care about the order of rows in your stream, it can deliver about 3x - 4x the speeds depending on your hardware. :rocket:

`CSV` does not care about order by default, which makes it blazing fast while hogging down your CPU. Pass `num_pipes: 1` to make it process rows in order they're given in the file, and make it use less of your available processing power.

## When do we want it?

Now.

## How do I get it?
Add
```elixir
{:csv, "~> 1.1.0"}
```
to your deps in `mix.exs` like so:

```elixir
defp deps do
  [
    {:csv, "~> 1.1.0"}
  ]
end
```
## Great! How do I use it right now?

Do this to decode:

````elixir
File.stream!("data.csv") |> CSV.decode
````

And you'll get a stream of rows. So, this is upcasing the text in each cell of a tab separated file because someone is angry:

````elixir
File.stream!("data.csv") |>
CSV.decode(separator: ?\t) |>
Enum.map fn row ->
  Enum.each(row, &String.upcase/1)
end
````

Do this to encode a table (two-dimensional array):

````elixir
table_data |> CSV.encode
````

And you'll get a stream of lines ready to be written to an IO.
So, this is writing to a file:

````elixir
file = File.open!("test.csv")
table_data |> CSV.encode |> Enum.each(&IO.write(file, &1))
````

## I have this file, but it's tab-separated :interrobang:

Pass in another separator to the decoder:

````elixir
File.stream!("data.csv") |> CSV.decode(separator: ?\t)
````

If you want to take revenge on whoever did this to you, encode with semicolons like this:

````elixir
your_data |> CSV.encode(separator: ?;)
````

## Polymorphic encoding

Make sure your data gets encoded the way you want - implement the `CSV.Encode` protocol for whatever strange you wish to encode:

````elixir
defimpl CSV.Encode for: MyData do
  def encode(%MyData{has: fun}, env \\ [])
	"so much #{fun}" |> CSV.Encode.encode(env)
  end
end
````

Or similar.

## Ensure performant encoding

The encoding protocol implements a fallback to Any for types where a simple call to `to_string` will provide
unambiguous results. Protocol dispatch for the fallback to Any is *very* slow when protocols are not consolidated,
so make sure you [have `consolidate_protocols: true`](http://blog.plataformatec.com.br/2015/04/build-embedded-and-start-permanent-in-elixir-1-0-4/)
in your `mix.exs` or you consolidate protocols manually for production in order to get good performance.

There is more to know about everything :tm: - [Check the doc](http://hexdocs.pm/csv/)

## License

MIT

## Weather

Sunny

## Mood

Good

## Contributions & Bugfixes are most welcome!
