# CSV [![Build Status](https://travis-ci.org/beatrichartz/csv.svg?branch=master)](https://travis-ci.org/beatrichartz/csv) [![Inline docs](http://inch-ci.org/github/beatrichartz/csv.svg?branch=master)](http://inch-ci.org/github/beatrichartz/csv)
[RFC 4180](http://tools.ietf.org/html/rfc4180) compliant CSV parsing and encoding for Elixir. Allows to specify other separators, so it could also be named: TSV. Why it is not idk, because of defaults I think.

## Why do we want it?

It parses files which contain lines separated by either commas or other separators.

If that's not enough reason to absolutely :heart: :green_heart: :two_hearts: :heart: :revolving_hearts: :sparkling_heart: it, it also parses a CSV file in order about 1.3x times as fast as a normal stream based implementation, and if you don't care about the order of rows in your stream, it can deliver about 3x - 4x the speeds depending on your hardware. :rocket:

`CSV` does not care about order by default, which makes it blazing fast while hogging down your CPU. Pass `num_pipes: 1` to make it process rows in order they're given in the file, and make it use less of your available processing power.

## When do we want it?

Now.

## Great! How do I use it right now?

Do this to decode:

	File.stream!("data.csv") |> CSV.decode

And you'll get a stream of rows. So, this is upcasing the text in each cell of a tab separated file because someone is angry:

	File.stream!("data.csv") |>
	CSV.decode(separator: "\t") |>
	Enum.map fn row ->
	  Enum.each(row, &String.upcase/1)
	end

Do this to encode a table (two-dimensional array):

	table_data |> CSV.encode

And you'll get a stream of lines ready to be written to an IO.
So, this is writing to a file:

	file = File.open!("test.csv")
	table_data |> CSV.encode |> Enum.each(&IO.write(file, &1))

## I have this file, but it's tab-separated :interrobang:

Pass in another separator to the decoder:

	File.stream!("data.csv") |> CSV.decode(separator: "\t")

If you want to take revenge on whoever did this to you, encode with semicolons like this:

	your_data |> CSV.encode(separator: ";")

There are more options - [Check the doc](http://hexdocs.pm/csv/0.1.0/)

## License

MIT

## Weather

Sunny

## Mood

Good

## Contributions & Bugfixes are most welcome!
