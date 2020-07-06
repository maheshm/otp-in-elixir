defmodule Playground.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      Supervisor.child_spec({Playground.Worker,name: MyWorker1}, id: :worker1),
      Supervisor.child_spec({Playground.Worker,name: MyWorker2}, id: :worker2),
      Supervisor.child_spec({Playground.Worker,name: MyWorker3}, id: :worker3),
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_all, name: Playground.Supervisor]
    # other options are :one_for_all
    Supervisor.start_link(children, opts)
  end
end
