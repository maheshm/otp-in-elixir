defmodule RedisClientGenStatem do
  @behaviour :gen_statem

  require Logger

  defstruct [:host, :port, :socket, :requests]

  @spec start_link(keyword()) :: :gen_statem.start_ret()
  def start_link(opts) when is_list(opts) do
    :gen_statem.start_link(__MODULE__, opts, [])
  end

  @spec command(pid(), [String.t()]) :: {:ok, term()} | {:error, term()}
  def command(pid, commands) when is_list(commands) do
    :gen_statem.call(pid, {:command, commands})
  end

  @impl true
  def callback_mode, do: :state_functions

  ## States

  @impl true
  def init(opts) do
    data = %__MODULE__{
      host: Keyword.fetch!(opts, :host),
      port: Keyword.fetch!(opts, :port),
      requests: :queue.new()
    }

    actions = [{:next_event, :internal, :connect}]
    {:ok, :disconnected, data, actions}
  end

  def disconnected(:internal, :connect, data) do
    {:ok, socket} = :gen_tcp.connect(to_charlist(data.host), data.port, [:binary, active: true])

    data = %{data | socket: socket}
    {:next_state, :connected, data}
  end

  def disconnected({:call, from}, {:command, _commands}, data) do
    :gen_statem.reply(from, {:error, :disconnected})
    {:keep_state, data}
  end

  def connected({:call, from}, {:command, commands}, data) do
    encoded = RedisClient.Protocol.pack(commands)
    :ok = :gen_tcp.send(data.socket, encoded)

    data = %{data | requests: :queue.in(from, data.requests)}

    {:keep_state, data}
  end

  def connected(:info, {:tcp, socket, payload}, %__MODULE__{socket: socket} = data) do
    {:ok, respose, ""} = RedisClient.Protocol.parse(payload)
    {{:value, from}, new_queue} = :queue.out(data.requests)

    :gen_statem.reply(from, {:ok, respose})

    data = %{data | requests: new_queue}
    {:keep_state, data}
  end

  def connected(:info, {:tcp_closed, socket}, %__MODULE__{socket: socket} = data) do
    IO.puts("Disconnected from socket")

    data = %{data | socket: nil}

    Process.sleep(10000)
    actions = [{:next_event, :internal, :connect}]
    {:next_state, :disconnected, data, actions}
  end
end
