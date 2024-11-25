# Off Broadway Memory

A Broadway producer for an in-memory buffer.

## Installation

The package can be installed by adding `off_broadway_memory` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:off_broadway_memory, "~> 1.1"}
  ]
end
```

## Basic Usage ([full documentation](https://hexdocs.pm/off_broadway_memory))

Start Broadway:

```elixir
Broadway.start_link(MyBroadway,
  name: MyBroadway,
  producer: [
    module: {OffBroadwayMemory.Producer, buffer: :example_buffer},
    concurrency: 1
  ],
  processors: [default: [concurrency: 50]]
)
```

Push data to be processed:

```elixir
OffBroadwayMemory.Buffer.push(:example_buffer, ["example", "data", "set"])
```

## License

`OffBroadwayMemory` is released under the [`Apache License 2.0`](https://github.com/elliotekj/off_broadway_memory/blob/main/LICENSE).

## About

This package was written by [Elliot Jackson](https://elliotekj.com).

- Blog: [https://elliotekj.com](https://elliotekj.com)
- Email: elliot@elliotekj.com
