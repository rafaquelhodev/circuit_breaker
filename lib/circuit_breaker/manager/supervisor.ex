defmodule CircuitBreaker.Manager.Supervisor do
  use Supervisor

  @worker CircuitBreaker.Manager.Worker
  @registry CircuitBreaker.Manager.Registry
  @supervisor CircuitBreaker.Manager.WorkerSupervisor

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    children = [
      {Registry, keys: :unique, name: @registry},
      {DynamicSupervisor, name: @supervisor, strategy: :one_for_one}
    ]

    :ets.new(:circuit_breaker, [:set, :public, :named_table])

    Supervisor.init(children, strategy: :one_for_all)
  end

  def get_worker_pid(component_name, config) do
    case Registry.lookup(@registry, component_name) do
      [{pid, _}] ->
        pid

      [] ->
        case DynamicSupervisor.start_child(
               @supervisor,
               {@worker, [name: component_name, config: config]}
             ) do
          {:ok, pid} -> pid
          {:error, {:already_started, pid}} -> pid
        end
    end
  end
end
