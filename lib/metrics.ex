defmodule Metrics do
  use Supervisor

  @worker Metrics.Worker
  @registry Metrics.Registry
  @supervisor Metrics.WorkerSupervisor

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    children = [
      {Registry, keys: :unique, name: @registry},
      {DynamicSupervisor, name: @supervisor, strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  def bump(fn_name) do
    pid = get_worker_pid(fn_name)

    send(pid, :bump)
  end

  def get_failures(fn_name) do
    pid = get_worker_pid(fn_name)

    GenServer.call(pid, :get_count)
  end

  defp get_worker_pid(fn_name) do
    case Registry.lookup(@registry, fn_name) do
      [{pid, _}] ->
        pid

      [] ->
        case DynamicSupervisor.start_child(@supervisor, {@worker, fn_name}) do
          {:ok, pid} -> pid
          {:error, {:already_started, pid}} -> pid
        end
    end
  end
end
