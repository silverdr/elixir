# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2021 The Elixir Team
# SPDX-FileCopyrightText: 2012 Plataformatec

defmodule IEx.Config do
  @moduledoc false
  use Agent

  @table __MODULE__
  @agent __MODULE__
  @keys [
    :colors,
    :inspect,
    :history_size,
    :default_prompt,
    :alive_prompt,
    :width,
    :parser,
    :dot_iex,
    :auto_reload
  ]

  # Generate a continuation prompt based on IEx prompt.
  # This is set as global configuration on app start.
  def prompt(prompt) do
    case Enum.split_while(prompt, &(&1 != ?()) do
      # It is not the default Elixir shell, so we use the default prompt
      {_, []} ->
        List.duplicate(?\s, max(0, prompt_width(prompt) - 3)) ++ ~c".. "

      {left, right} ->
        List.duplicate(?., prompt_width(left)) ++ right
    end
  end

  # TODO: Remove this when we require Erlang/OTP 27+
  @compile {:no_warn_undefined, :prim_tty}
  @compile {:no_warn_undefined, :shell}
  defp prompt_width(prompt) do
    if function_exported?(:prim_tty, :npwcwidthstring, 1) do
      :prim_tty.npwcwidthstring(prompt)
    else
      :shell.prompt_width(prompt)
    end
  end

  # Read API

  def configuration() do
    Application.get_all_env(:iex) |> Keyword.take(@keys)
  end

  def width() do
    columns = columns()
    value = Application.get_env(:iex, :width) || 80
    min(value, columns)
  end

  defp columns() do
    case :io.columns() do
      {:ok, width} -> width
      {:error, _} -> 80
    end
  end

  def started?() do
    Process.whereis(@agent) != nil
  end

  def history_size() do
    Application.fetch_env!(:iex, :history_size)
  end

  def default_prompt() do
    Application.fetch_env!(:iex, :default_prompt)
  end

  def alive_prompt() do
    Application.fetch_env!(:iex, :alive_prompt)
  end

  def parser() do
    Application.fetch_env!(:iex, :parser)
  end

  def color(color) do
    color(color, Application.get_env(:iex, :colors, []))
  end

  defp color(color, colors) do
    if colors_enabled?(colors) do
      case Keyword.fetch(colors, color) do
        {:ok, value} -> value
        :error -> default_color(color)
      end
    else
      nil
    end
  end

  defp colors_enabled?(colors) do
    Keyword.get_lazy(colors, :enabled, &IO.ANSI.enabled?/0)
  end

  def dot_iex() do
    Application.get_env(:iex, :dot_iex)
  end

  def auto_reload?() do
    Application.fetch_env!(:iex, :auto_reload)
  end

  # Used by default on evaluation cycle
  defp default_color(:eval_interrupt), do: [:yellow]
  defp default_color(:eval_result), do: [:yellow]
  defp default_color(:eval_error), do: [:red]
  defp default_color(:eval_info), do: [:normal]
  defp default_color(:stack_info), do: [:red]
  defp default_color(:blame_diff), do: [:red]

  # Used by ls
  defp default_color(:ls_directory), do: [:blue]
  defp default_color(:ls_device), do: [:green]

  # Used by inspect
  defp default_color(:syntax_colors) do
    IO.ANSI.syntax_colors()
  end

  # Used by ansi docs
  defp default_color(doc_color) do
    IO.ANSI.Docs.default_options() |> Keyword.fetch!(doc_color)
  end

  def ansi_docs() do
    colors = Application.get_env(:iex, :colors, [])
    enabled = colors_enabled?(colors)
    [width: width(), enabled: enabled] ++ colors
  end

  def inspect_opts() do
    Application.get_env(:iex, :inspect, [])
    |> Keyword.put_new_lazy(:width, &width/0)
    |> update_syntax_colors()
  end

  defp update_syntax_colors(opts) do
    colors = Application.get_env(:iex, :colors, [])

    if syntax_colors = color(:syntax_colors, colors) do
      reset = [:reset | List.wrap(color(:eval_result, colors))]
      syntax_colors = [reset: reset] ++ syntax_colors
      Keyword.update(opts, :syntax_colors, syntax_colors, &Keyword.merge(syntax_colors, &1))
    else
      opts
    end
  end

  # Agent API

  def start_link(_) do
    Agent.start_link(__MODULE__, :handle_init, [], name: @agent)
  end

  def after_spawn(fun) do
    Agent.update(@agent, __MODULE__, :handle_after_spawn, [fun])
  end

  def after_spawn() do
    :ets.lookup_element(@table, :after_spawn, 2)
  end

  def configure(options) do
    Agent.update(@agent, __MODULE__, :handle_configure, [options])
  end

  # Agent callbacks

  def handle_init do
    :ets.new(@table, [:named_table, :public])
    true = :ets.insert_new(@table, after_spawn: [])
    @table
  end

  def handle_after_spawn(tab, fun) do
    :ets.update_element(tab, :after_spawn, {2, [fun | after_spawn()]})
  end

  def handle_configure(tab, options) do
    Enum.each(options, &validate_option/1)

    configuration()
    |> Keyword.merge(options, &merge_option/3)
    |> update_configuration()

    tab
  end

  defp update_configuration(config) do
    Enum.each(config, fn {key, value} when key in @keys ->
      Application.put_env(:iex, key, value)
    end)
  end

  defp merge_option(:colors, old, new) when is_list(new), do: Keyword.merge(old, new)
  defp merge_option(:inspect, old, new) when is_list(new), do: Keyword.merge(old, new)
  defp merge_option(_key, _old, new), do: new

  defp validate_option({:colors, new}) when is_list(new), do: :ok
  defp validate_option({:inspect, new}) when is_list(new), do: :ok
  defp validate_option({:history_size, new}) when is_integer(new), do: :ok
  defp validate_option({:default_prompt, new}) when is_binary(new), do: :ok
  defp validate_option({:alive_prompt, new}) when is_binary(new), do: :ok
  defp validate_option({:width, new}) when is_integer(new), do: :ok
  defp validate_option({:parser, tuple}) when tuple_size(tuple) == 3, do: :ok
  defp validate_option({:dot_iex, path}) when is_binary(path), do: :ok
  defp validate_option({:auto_reload, enabled}) when is_boolean(enabled), do: :ok

  defp validate_option(option) do
    raise ArgumentError, "invalid configuration #{inspect(option)}"
  end
end
