defmodule SharedState do
  ## Public API

  @spec start(term()) :: pid()
  def start(initial_state) do
    spawn(fn ->
      loop(initial_state)
    end)
  end

  @spec get(pid()) :: term()
  def get(pid) do
    ref = make_ref()
    send(pid, {:get_state, self(), ref})

    receive do
      {^ref, respose} -> respose
    end
  end

  @spec update(pid(), (term() -> term())) :: :ok
  def update(pid, update_fun) when is_function(update_fun, 1) do
    send(pid, {:update_state, update_fun})
    :ok
  end

  ## Process loop
  defp loop(state) do
    receive do
      {:get_state, caller_pid, ref} ->
        send(caller_pid, state)
        loop(state)

      {:update_state, update_fun} ->
        new_state = update_fun.(state)
        loop(new_state)

      _other ->
        loop(state)
    end
  end

end
