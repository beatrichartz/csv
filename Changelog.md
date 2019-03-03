## 2.2.0
- Make syntax compatible with latest Elixir releases
- Add [`validate_row_length:` option](https://hexdocs.pm/csv/CSV.html#decode/2-options) defaulting to true to allow disabling validation of row length.
## 2.0.0
- Make [`decode`](https://hexdocs.pm/csv/CSV.html#decode/2) return row and
  error tuples instead of raising errors directly
- Make old behaviour of raising errors directly available
  via [`decode!`](https://hexdocs.pm/csv/CSV.html#decode!/2)
- Improve error messages for escape sequences
- Rewrite parts of the pipeline to be more modular

## 1.4.4
- Load [`parallel_stream`](https://github.com/beatrichartz/parallel_stream)
  as an app dependency to avoid load level errors.
  See [issue #56](https://github.com/beatrichartz/csv/issues/56) reported
  by [@luk3thomas](https://github.com/luk3thomas)

## 1.4.3
- Fix a case where lines would not be aggregated correctly
  [see #52](https://github.com/beatrichartz/csv/issues/52) reported by 
  [@yury-dimov](https://github.com/yury-dymov)

## 1.4.2
- Update dependency on [`parallel_stream`](https://github.com/beatrichartz/parallel_stream)

## 1.4.1
- Fix condition where rows would be dropped when decoding from stateful streams.
  [See #39](https://github.com/beatrichartz/csv/issues/39) reported by
  [@moxley](https://github.com/moxley)

## 1.4.0

- add option to specify headers in encode - added [in #34](https://github.com/beatrichartz/csv/issues/34)
  by [@barruumrex](https://github.com/barruumrex)

## 1.3.3

- Fix empty streams raising a lexer error - raised [in #28](https://github.com/beatrichartz/csv/issues/28)
  by [@kiliancs](https://github.com/kiliancs)

## 1.3.2

- Cleanup, removing some unused defaults in function headers to remove compile
  time warnings

## 1.3.1

- Fix `:strip_cells` not stripping cells when multible options are specified - #29 by [@tomjoro](https://github.com/tomjoro)

## 1.3.0

- Now supports linebreaks inside escaped fields (#13)
- Raises an error when row length mismatches accross rows
- Uses [parallel_stream](https://github.com/beatrichartz/parallel_stream) for parallelism

## 1.2.4

- Fix encoding of double quotes

## 1.2.3

- Fix a condition where headers: true would enumerate the whole file once before parsing

## 1.2.2

- Fix default num_pipes argument to evaluate num_pipes dependent on scheduler at runtime
- Test utf-8 files with BOM
- Syntax and mix updates for elixir 1.2

## 1.2.1

- Decoder performance optimisations

## 1.2.0

- Use `Stream.transform/4` - incompatible with Elixir < `1.1.0`

## 1.1.5

- Decoder refactor from `Stream.resource/3` to `Stream.transform/3` in order to
  get more predictable stream behaviour
- Rows now get processed in order
- Fix a bug where stream would get evaluated before being decoded

## 1.1.4

- Fix a bug where headers could be out of order

## 1.1.3

- Fix a bug where headers could get parsed as the first row

## 1.1.2

- Fix a bug where calls to decode with num_pipes: 1 would yield varying
  results due to leftover state in decoder message queue

## 1.1.1

- Rescue from errors in stream producer to get more predictable behaviour
  in case of failure

## 1.1.0

- Better error messages when encountering invalid encodings

## 1.0.1

- Indicate `consolidate_protocols` for better encoding performance

## 1.0.0

- Use bytes as separators

## 0.2.3

- Add benchmarking

## 0.2.2

- Use utf-8 bytes instead of codepoints for multi-byte parsing

## 0.2.1

- Fix handling of multi-byte utf-8 characters

## 0.2.0

- Implement encoder protocol
