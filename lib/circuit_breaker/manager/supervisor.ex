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

    Supervisor.init(children, strategy: :one_for_all)
  end

  def bump(component_name, config) do
    pid = get_worker_pid(component_name, config)

    GenServer.cast(pid, :bump)
  end

  def get_state(component_name, config) do
    pid = get_worker_pid(component_name, config)

    GenServer.call(pid, :get_state)
  end

  def book_half_open_call(component_name) do
    pid = get_worker_pid(component_name, nil)

    GenServer.call(pid, :book_half_open_call)
  end

  def report_half_open_call(component_name, job_id, has_errors?) do
    pid = get_worker_pid(component_name, nil)

    GenServer.cast(pid, {:report_half_open_call, job_id, has_errors?})
  end

  defp get_worker_pid(component_name, config) do
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
