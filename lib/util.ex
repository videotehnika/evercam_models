defmodule Util do
  def deep_get(map, keys, default \\ nil), do: do_deep_get(map, keys, default)

  defp do_deep_get(nil, _, default), do: default
  defp do_deep_get(%{} = map, [], default) when map_size(map) == 0, do: default
  defp do_deep_get(value, [], _default), do: value
  defp do_deep_get(map, [key|rest], default) do
    map
    |> Map.get(key, %{})
    |> do_deep_get(rest, default)
  end

  def parse_changeset(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn
      {msg, opts} -> String.replace(msg, "%{count}", to_string(opts[:count]))
      msg -> msg
    end)
  end

  def slugify(string) do
    string |> String.normalize(:nfd) |> String.replace(~r/[^A-z0-9-\s]/u, "")
  end
end
