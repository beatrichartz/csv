# Changelog

## 2.5.0 (2022-09-17)
- Optional parameter `escape_formulas` to prevent CSV injection. [Fixes #103](https://github.com/beatrichartz/csv/issues/103) reported by [@maennchen](https://github.com/maennchen). Contributed by [@maennchen](https://github.com/maennchen) in [PR #104](https://github.com/beatrichartz/csv/pull/104).
- Optional parameter `force_quotes` to force quotes when encoding contributed by [@stuart](https://github.com/stuart)
- Bugfix to pass non UTF-8 lines through in normal mode so other lines can be processed, [Fixes #107](https://github.com/beatrichartz/csv/pull/107). Contributed by [@al2o3cr](https://github.com/al2o3cr).
- Allow to encode keyword lists specifying headers as values, contributed by [@michaelchu](https://github.com/michaelchu)
- Better docs thanks to [@kianmeng](https://github.com/kianmeng)

## 2.4.1 (2020-09-12)

- Fix unnecessary escaping of delimiters when encoding [Fixes #70](https://github.com/beatrichartz/csv/issues/70)
  reported by [@karmajunkie](https://github.com/karmajunkie)

## 2.4.0 (2020-09-12)

- Fix [StrayQuoteError](https://hexdocs.pm/csv/CSV.StrayQuoteError.html) not getting
  passed the correct arguments in strict mode. [Fixes #96](https://github.com/beatrichartz/csv/issues/96).
- When headers are present multiple times and the `:headers` option is set to `true`, parse the values into a list.
  Contributed by [@MrAlexLau](https://github.com/MrAlexLau) in [PR #97](https://github.com/beatrichartz/csv/pull/97).

## 2.3.1 (2019-03-30)

- Fix [StrayQuoteError](https://hexdocs.pm/csv/CSV.StrayQuoteError.html) incorrectly
  getting raised when escape sequences end in new lines. [Fixes #89](https://github.com/beatrichartz/csv/issues/89).
  Raised by [@rockwood](https://github.com/rockwood) in [Issue #96](https://github.com/beatrichartz/csv/issues/96).

## 2.3.0 (2019-03-17)

- Add [StrayQuoteError](https://hexdocs.pm/csv/CSV.StrayQuoteError.html) which gets
  raised when a row has stray quotes rather than [EscapeSequenceError](https://hexdocs.pm/csv/CSV.EscapeSequenceError.html#content)
  to help with common encoding errors.

## 2.2.0 (2019-03-03)

- Make syntax compatible with latest Elixir releases
- Add [`validate_row_length:` option](https://hexdocs.pm/csv/CSV.html#decode/2-options) defaulting to true to allow
  disabling validation of row length.

## 2.0.0 (2017-05-29)

- Make [`decode`](https://hexdocs.pm/csv/CSV.html#decode/2) return row and
  error tuples instead of raising errors directly
- Make old behaviour of raising errors directly available
  via [`decode!`](https://hexdocs.pm/csv/CSV.html#decode!/2)
- Improve error messages for escape sequences
- Rewrite parts of the pipeline to be more modular

## 1.4.4 (2016-11-12)

- Load [`parallel_stream`](https://github.com/beatrichartz/parallel_stream)
  as an app dependency to avoid load level errors.
  See [issue #56](https://github.com/beatrichartz/csv/issues/56) reported
  by [@luk3thomas](https://github.com/luk3thomas)

## 1.4.3 (2016-08-27)

- Fix a case where lines would not be aggregated correctly
  [see #52](https://github.com/beatrichartz/csv/issues/52) reported by
  [@yury-dimov](https://github.com/yury-dymov)

## 1.4.2 (2016-06-20)

- Update dependency on [`parallel_stream`](https://github.com/beatrichartz/parallel_stream)

## 1.4.1 (2016-05-21)

- Fix condition where rows would be dropped when decoding from stateful streams.
  [See #39](https://github.com/beatrichartz/csv/issues/39) reported by
  [@moxley](https://github.com/moxley)

## 1.4.0 (2016-04-03)

- add option to specify headers in encode - added [in #34](https://github.com/beatrichartz/csv/issues/34)
  by [@barruumrex](https://github.com/barruumrex)

## 1.3.3 (2016-03-25)

- Fix empty streams raising a lexer error - raised [in #28](https://github.com/beatrichartz/csv/issues/28)
  by [@kiliancs](https://github.com/kiliancs)

## 1.3.2 (2016-03-08)

- Cleanup, removing some unused defaults in function headers to remove compile
  time warnings

## 1.3.1 (2016-03-08)

- Fix `:strip_cells` not stripping cells when multiple options are specified - #29 by [@tomjoro](https://github.com/tomjoro)

## 1.3.0 (2016-03-01)

- Now supports linebreaks inside escaped fields (#13)
- Raises an error when row length mismatches across rows
- Uses [parallel_stream](https://github.com/beatrichartz/parallel_stream) for parallelism

## 1.2.4 (2016-02-06)

- Fix encoding of double quotes

## 1.2.3 (2016-01-19)

- Fix a condition where headers: true would enumerate the whole file once before parsing

## 1.2.2 (2016-01-02)

- Fix default num_pipes argument to evaluate num_pipes dependent on scheduler at runtime
- Test utf-8 files with BOM
- Syntax and mix updates for elixir 1.2

## 1.2.1 (2015-10-17)

- Decoder performance optimisations

## 1.2.0 (2015-10-11)

- Use `Stream.transform/4` - incompatible with Elixir < `1.1.0`

## 1.1.5 (2015-10-11)

- Decoder refactor from `Stream.resource/3` to `Stream.transform/3` in order to
  get more predictable stream behaviour
- Rows now get processed in order
- Fix a bug where stream would get evaluated before being decoded

## 1.1.4 (2015-09-13)

- Fix a bug where headers could be out of order

## 1.1.3 (2015-09-12)

- Fix a bug where headers could get parsed as the first row

## 1.1.2 (2015-09-05)

- Fix a bug where calls to decode with num_pipes: 1 would yield varying
  results due to leftover state in decoder message queue

## 1.1.1 (2015-07-14)

- Rescue from errors in stream producer to get more predictable behaviour
  in case of failure

## 1.1.0 (2015-07-12)

- Better error messages when encountering invalid encodings

## 1.0.1 (2015-07-11)

- Indicate `consolidate_protocols` for better encoding performance

## 1.0.0 (2015-05-24)

- Use bytes as separators

## 0.2.3 (2015-05-24)

- Add benchmarking

## 0.2.2 (2015-05-20)

- Use utf-8 bytes instead of codepoints for multi-byte parsing

## 0.2.1 (2015-05-20)

- Fix handling of multi-byte utf-8 characters

## 0.2.0 (2015-03-25)

- Implement encoder protocol
