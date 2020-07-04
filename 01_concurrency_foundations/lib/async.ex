defmodule Async do
  def execute_async(fun) do
    caller_pid = self()
    ref = make_ref()

    task_pid =
      spawn(fn ->
        result = fun.()
        send(caller_pid, {ref, result})
      end)

    {task_pid, ref}
  end

  def await_result({_task_pid, ref}, timeout \\ :infinity) do
    receive do
      {^ref, message} -> message
    after
      timeout -> :timeout
    end
  end

  def await_or_kill({task_pid, ref}, timeout) do
    receive do
      {^ref, message} -> message
    after
      timeout ->
        Process.exit(task_pid, :kill)
        :killed
    end

  end

  def execute_async_with_monitor(fun) do
    caller_pid = self()
    ref = make_ref()

    task_pid =
      spawn(fn ->
        result = fun.()
        send(caller_pid, {ref, result})
      end)

    monitor_ref = Process.monitor(task_pid)

    {task_pid, ref, monitor_ref}
  end

  def await_or_kill_with_monitor({task_pid, ref, monitor_ref}, timeout) do
    receive do
      {^ref, result} ->
        Process.demonitor(monitor_ref, [:flush])
        {:ok, result}

      {:DOWN, ^monitor_ref, _, _, reason} ->
        {:error, reason}

    after
        timeout ->
        Process.demonitor(monitor_ref, [:flush])
        Process.exit(task_pid, :kill)
        :killed
    end
  end
end
