# Instrumentation

Simple instrumentation framework inspired by ActiveSupport::Notifications.

## Installation

```elixir
def deps do
  [
    {:instrumentation, ">= 0.1.0"}
  ]
end
```

## Quickstart

```elixir
import Instrumentation

subscribe "foo", fn payload ->
  IO.puts "foo took #{payload[:duration]} ms and said #{payload[:said]}!"
end

result = instrument "foo", fn ->
  {some_function(), [said: "hiiii"]}
end
```

## Documentation

[https://hexdocs.pm/instrumentation](https://hexdocs.pm/instrumentation)
