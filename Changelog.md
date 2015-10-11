## 1.2.0

- Use `Stream.transform/4` - incompatible with Elixir < `1.1.0`

## 1.1.5

- Decoder refactor from `Stream.resource/3` to `Stream.transform/3` in order to
  get more predictable stream behaviour
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
