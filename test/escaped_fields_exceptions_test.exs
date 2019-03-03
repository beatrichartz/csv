defmodule DecodingTests.EscapedFieldsExceptionsTest do
  use ExUnit.Case
  import TestSupport.StreamHelpers

  test "parses strings unless they contain unfinished escape sequences" do
    stream = ["a,be", "\"c,d", "u,z"] |> to_stream
    result = CSV.decode(stream, headers: [:a, :b]) |> Enum.to_list()

    assert result == [
             ok: %{a: "a", b: "be"},
             error:
               "Escape sequence started on line 2 near \"c,d\" did not terminate.\n\n" <>
                 "Escape sequences are allowed to span up to 1000 lines. " <>
                 "This threshold avoids collecting the whole file into memory " <>
                 "when an escape sequence does not terminate. " <>
                 "You can change it using the escape_max_lines option: https://hexdocs.pm/csv/CSV.html#decode/2",
             ok: %{a: "u", b: "z"}
           ]
  end

  test "raises errors for unfinished escape sequences spanning multiple lines" do
    stream = [",ci,\"\"\"", ",c,d"] |> to_stream
    result = stream |> CSV.decode() |> Enum.to_list()

    assert result == [
             error:
               "Escape sequence started on line 1 near \"\"\" did not terminate.\n\n" <>
                 "Escape sequences are allowed to span up to 1000 lines. " <>
                 "This threshold avoids collecting the whole file into memory " <>
                 "when an escape sequence does not terminate. " <>
                 "You can change it using the escape_max_lines option: https://hexdocs.pm/csv/CSV.html#decode/2",
             ok: ["", "c", "d"]
           ]
  end

  test "raises errors for unfinished escape sequences in strict mode" do
    stream = [",ci,\"\"\"", ",c,d"] |> to_stream

    assert_raise CSV.EscapeSequenceError, fn ->
      CSV.decode!(stream) |> Stream.run()
    end
  end
end
