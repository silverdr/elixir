# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2021 The Elixir Team
# SPDX-FileCopyrightText: 2012 Plataformatec

defmodule Node do
  @moduledoc """
  Functions related to VM nodes.

  Some of the functions in this module are inlined by the compiler,
  similar to functions in the `Kernel` module and they are explicitly
  marked in their docs as "inlined by the compiler". For more information
  about inlined functions, check out the `Kernel` module.
  """

  @type t :: node

  @doc """
  Turns a non-distributed node into a distributed node.

  This functionality starts the `:net_kernel` and other related
  processes.

  This function is rarely invoked in practice. Instead, nodes are
  named and started via the command line by using the `--sname` and
  `--name` flags. If you need to use this function to dynamically
  name a node, please make sure the `epmd` operating system process
  is running by calling `epmd -daemon`, such as `System.cmd("epmd", ["-daemon"])`.

  Invoking this function when the distribution has already been started,
  either via the command line interface or dynamically, will return an
  error.

  ## Examples

      {:ok, pid} = Node.start(:example, name_domain: :shortnames, hidden: true)

  ## Options

  Currently supported options are:

  * `:name_domain` - determines the host name part of the node name. If `:longnames`,
    fully qualified domain names will be   used which also is the default.
    If `:shortnames`, only the short name of the host will be used.

  * `:net_ticktime` - The tick time to use in seconds. Defaults to the value of the
    `net_ticktime` configuration under Erlang's `kernel` application.
    See [the `kernel` documentation](https://www.erlang.org/doc/apps/kernel/kernel_app.html)
    for more information.

  * `net_tickintensity` - The tick intensity to use. Defaults to the value of the
    `net_tickintensity` configuration under Erlang's `kernel` application.
    See [the `kernel` documentation](https://www.erlang.org/doc/apps/kernel/kernel_app.html)
    for more information.

  * `:dist_listen` - Enable or disable listening for incoming connections.
    Defaults to the value given to the `--erl` flag, otherwise it defaults to `true`.
    Note that `dist_listen: false` implies `hidden: true`.

  * `:hidden` - Enable or disable hidden node. Defaults to `true` if the `--hidden`
    flag is given to `elixir`'s CLI (or via the `--erl` flag), otherwise it
    defaults to `false`.

  If `name` is set to `:undefined`, the distribution will be started to request a
  dynamic node name from the first node it connects to. Setting `name` to
  `:undefined` also implies options `dist_listen: false, hidden: true`.
  """
  @spec start(node,
          name_domain: :shortnames | :longnames,
          net_ticktime: pos_integer(),
          net_tickintensity: 4..1000,
          dist_listen: boolean(),
          hidden: boolean()
        ) :: {:ok, pid} | {:error, term}
  def start(name, opts \\ [])

  def start(name, opts) when is_list(opts) do
    :net_kernel.start(name, Map.new(opts))
  end

  # TODO: Deprecate me on Elixir v1.23
  def start(name, type) when is_atom(type) do
    :net_kernel.start([name, type, 15_000])
  end

  # TODO: Deprecate me on Elixir v1.23
  @doc false
  def start(name, type, tick_time) do
    :net_kernel.start([name, type, tick_time])
  end

  @doc """
  Turns a distributed node into a non-distributed node.

  For other nodes in the network, this is the same as the node going down.
  Only possible when the node was started with `Node.start/2`, otherwise
  returns `{:error, :not_allowed}`. Returns `{:error, :not_found}` if the
  local node is not alive.
  """
  @spec stop() :: :ok | {:error, :not_allowed | :not_found}
  def stop() do
    :net_kernel.stop()
  end

  @doc """
  Returns the current node.

  It returns the same as the built-in `node()`.
  """
  @spec self :: t
  def self do
    :erlang.node()
  end

  @doc """
  Returns `true` if the local node is alive.

  That is, if the node can be part of a distributed system.
  """
  @spec alive? :: boolean
  def alive? do
    :erlang.is_alive()
  end

  @doc """
  Returns a list of all visible nodes in the system, excluding
  the local node.

  Same as `list(:visible)`.

  Inlined by the compiler.
  """
  @spec list :: [t]
  def list do
    :erlang.nodes()
  end

  @doc """
  Returns a list of nodes according to argument given.

  The result returned when the argument is a list, is the list of nodes
  satisfying the disjunction(s) of the list elements.

  For more information, see `:erlang.nodes/1`.

  Inlined by the compiler.
  """
  @type state :: :visible | :hidden | :connected | :this | :known
  @spec list(state | [state]) :: [t]
  def list(args) do
    :erlang.nodes(args)
  end

  @doc """
  Monitors the status of the node.

  If `flag` is `true`, monitoring is turned on.
  If `flag` is `false`, monitoring is turned off.

  For more information, see `:erlang.monitor_node/2`.

  For monitoring status changes of all nodes, see `:net_kernel.monitor_nodes/2`.
  """
  @spec monitor(t, boolean) :: true
  def monitor(node, flag) do
    :erlang.monitor_node(node, flag)
  end

  @doc """
  Behaves as `monitor/2` except that it allows an extra
  option to be given, namely `:allow_passive_connect`.

  For more information, see `:erlang.monitor_node/3`.

  For monitoring status changes of all nodes, see `:net_kernel.monitor_nodes/2`.
  """
  @spec monitor(t, boolean, [:allow_passive_connect]) :: true
  def monitor(node, flag, options) do
    :erlang.monitor_node(node, flag, options)
  end

  @doc """
  Tries to set up a connection to node.

  Returns `:pang` if it fails, or `:pong` if it is successful.

  ## Examples

      iex> Node.ping(:unknown_node)
      :pang

  """
  @spec ping(t) :: :pong | :pang
  def ping(node) do
    :net_adm.ping(node)
  end

  @doc """
  Forces the disconnection of a node.

  This will appear to the `node` as if the local node has crashed.
  This function is mainly used in the Erlang network authentication
  protocols. Returns `true` if disconnection succeeds, otherwise `false`.
  If the local node is not alive, the function returns `:ignored`.

  For more information, see `:erlang.disconnect_node/1`.
  """
  @spec disconnect(t) :: boolean | :ignored
  def disconnect(node) do
    :erlang.disconnect_node(node)
  end

  @doc """
  Establishes a connection to `node`.

  Returns `true` if successful, `false` if not, and the atom
  `:ignored` if the local node is not alive.

  For more information, see `:net_kernel.connect_node/1`.
  """
  @spec connect(t) :: boolean | :ignored
  def connect(node) do
    :net_kernel.connect_node(node)
  end

  @doc """
  Returns the PID of a new process started by the application of `fun`
  on `node`. If `node` does not exist, a useless PID is returned.

  For the list of available options, see `:erlang.spawn/2`.

  Inlined by the compiler.
  """
  @spec spawn(t, (-> any)) :: pid
  def spawn(node, fun) do
    :erlang.spawn(node, fun)
  end

  @doc """
  Returns the PID of a new process started by the application of `fun`
  on `node`.

  If `node` does not exist, a useless PID is returned.

  For the list of available options, see `:erlang.spawn_opt/3`.

  Inlined by the compiler.
  """
  @spec spawn(t, (-> any), Process.spawn_opts()) :: pid | {pid, reference}
  def spawn(node, fun, opts) do
    :erlang.spawn_opt(node, fun, opts)
  end

  @doc """
  Returns the PID of a new process started by the application of
  `module.function(args)` on `node`.

  If `node` does not exist, a useless PID is returned.

  For the list of available options, see `:erlang.spawn/4`.

  Inlined by the compiler.
  """
  @spec spawn(t, module, atom, [any]) :: pid
  def spawn(node, module, fun, args) do
    :erlang.spawn(node, module, fun, args)
  end

  @doc """
  Returns the PID of a new process started by the application of
  `module.function(args)` on `node`.

  If `node` does not exist, a useless PID is returned.

  For the list of available options, see `:erlang.spawn_opt/5`.

  Inlined by the compiler.
  """
  @spec spawn(t, module, atom, [any], Process.spawn_opts()) :: pid | {pid, reference}
  def spawn(node, module, fun, args, opts) do
    :erlang.spawn_opt(node, module, fun, args, opts)
  end

  @doc """
  Returns the PID of a new linked process started by the application of `fun` on `node`.

  A link is created between the calling process and the new process, atomically.
  If `node` does not exist, a useless PID is returned (and due to the link, an exit
  signal with exit reason `:noconnection` will be received).

  Inlined by the compiler.
  """
  @spec spawn_link(t, (-> any)) :: pid
  def spawn_link(node, fun) do
    :erlang.spawn_link(node, fun)
  end

  @doc """
  Returns the PID of a new linked process started by the application of
  `module.function(args)` on `node`.

  A link is created between the calling process and the new process, atomically.
  If `node` does not exist, a useless PID is returned (and due to the link, an exit
  signal with exit reason `:noconnection` will be received).

  Inlined by the compiler.
  """
  @spec spawn_link(t, module, atom, [any]) :: pid
  def spawn_link(node, module, fun, args) do
    :erlang.spawn_link(node, module, fun, args)
  end

  @doc """
  Spawns the given function on a node, monitors it and returns its PID
  and monitoring reference.

  Inlined by the compiler.
  """
  @doc since: "1.14.0"
  @spec spawn_monitor(t, (-> any)) :: {pid, reference}
  def spawn_monitor(node, fun) do
    :erlang.spawn_monitor(node, fun)
  end

  @doc """
  Spawns the given module and function passing the given args on a node,
  monitors it and returns its PID and monitoring reference.

  Inlined by the compiler.
  """
  @doc since: "1.14.0"
  @spec spawn_monitor(t, module, atom, [any]) :: {pid, reference}
  def spawn_monitor(node, module, fun, args) do
    :erlang.spawn_monitor(node, module, fun, args)
  end

  @doc """
  Sets the magic cookie of `node` to the atom `cookie`.

  The default node is `Node.self/0`, the local node. If `node` is the local node,
  the function also sets the cookie of all other unknown nodes to `cookie`.

  This function will raise `FunctionClauseError` if the given `node` is not alive.
  """
  @spec set_cookie(t, atom) :: true
  def set_cookie(node \\ Node.self(), cookie) when is_atom(cookie) do
    :erlang.set_cookie(node, cookie)
  end

  @doc """
  Returns the magic cookie of the local node.

  Returns the cookie if the node is alive, otherwise `:nocookie`.
  """
  @spec get_cookie() :: atom
  def get_cookie() do
    :erlang.get_cookie()
  end
end
