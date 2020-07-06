defmodule RedisClient do
  use GenServer

  defstruct [:socket, :queue]

  def start_link(opts) when is_list(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def command(pid, commands) when is_list(commands) do
    GenServer.call(pid, {:command, commands})
  end

  @impl true
  def init(opts) do
    host = Keyword.fetch!(opts, :host)
    port = Keyword.fetch!(opts, :port)

    {:ok, socket} = :gen_tcp.connect(to_charlist(host), port, [:binary, active: true])

    {:ok, %__MODULE__{socket: socket, queue: :queue.new()}}
  end

  @impl true
  def handle_call({:command, commands}, from, state) do
    encoded = RedisClient.Protocol.pack(commands)
    :ok = :gen_tcp.send(state.socket, encoded)

    state = %{state | queue: :queue.in(from, state.queue)}
    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp, socket, data}, %__MODULE__{socket: socket} = state) do
    {:ok, respose, ""} = RedisClient.Protocol.parse(data)
    {{:value, from}, new_queue} = :queue.out(state.queue)

    GenServer.reply(from, respose)

    state = %{state | queue: new_queue}

    {:noreply, state}
  end
end
