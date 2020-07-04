defmodule TermsCache do
  use GenServer

  @name __MODULE__
  @evict_interval 5_000

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link([] = _opts) do
    GenServer.start_link(__MODULE__, nil, name: @name)
  end

  @spec put(term(), term(), non_neg_integer()) :: :ok
  def put(key, value, ttl \\ :infinity) do
    if ttl == :infinity do
      GenServer.cast(@name, {:put, key, value, ttl})
    else
      expires_at = System.system_time(:millisecond) + ttl
      GenServer.cast(@name, {:put, key, value, expires_at})
    end
  end

  @spec get(term()) :: term()
  def get(key) do
    GenServer.call(@name, {:get, key})
  end

  @impl true
  def init(nil) do
    # Amazing stuff here!
    :timer.send_interval(@evict_interval, self(), :evict)
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:put, key, value, expires_at}, state) do
    new_state = Map.put(state, key, {value, expires_at})
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    case Map.fetch(state, key) do
      {:ok, {value, _expires_at}} -> {:reply, value, state}
      :error -> {:reply, nil, state}
    end
  end

  @impl true
  def handle_info(:evict, state) do
    now = System.system_time(:millisecond)

    new_state =
      state
      |> Enum.filter(fn {_key, {_value, expires_at}} -> expires_at >= now end)
    |> Enum.into(%{})

    {:noreply, new_state}
  end

end
