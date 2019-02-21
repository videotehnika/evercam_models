defmodule EctoFields.IPv4 do
  @behaviour Ecto.Type
  def type, do: :string

  def cast(ip) when is_binary(ip) and byte_size(ip) > 0 do
    case ip |> String.to_charlist |> :inet_parse.ipv4strict_address do
      {:ok, _} -> {:ok, ip}
      {:error, _} -> :error
    end
  end

  def cast(nil), do: {:ok, nil}

  def cast(_), do: :error

  # converts a string to our ecto type
  def load(ip), do: {:ok, ip}

  # converts our ecto type to a string
  def dump(ip), do: {:ok, ip}
end