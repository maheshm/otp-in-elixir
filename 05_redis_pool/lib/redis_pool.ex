defmodule RedisPool do
  use Supervisor

  @spec start_link(keyword()) :: {:ok, tuple()}
  def start_link(opts) do
    pool_name = Keyword.fetch!(opts, :name)
    connections = Keyword.get(opts, :connections, 5)
    connection_options = Keyword.get(opts, :connection_options, [])

    Supervisor.start_link(__MODULE__, {pool_name, connections, connection_options}, name: pool_name)
  end

  @spec command(atom(), Redix.command()) :: {:ok, term()} | {:error, term()}
  def command(pool_name, command) when is_list(command) do
    connections = :persistent_term.get({pool_name, :connections})
    random_index = Enum.random(1..connections)
    connection = Module.concat(pool_name, "Conn#{random_index}")
    Redix.command(connection, command)
  end

  @impl true
  def init({pool_name, connections, _connection_options}) do
    children = for index <- 1..connections do
      name = Module.concat(pool_name, :"Conn#{index}")
      child_spec = {Redix, name: name}
      Supervisor.child_spec(child_spec, id: {Redix, index})
    end

    :persistent_term.put({pool_name, :connections}, connections)
    Supervisor.init(children, strategy: :one_for_one)
  end
end
