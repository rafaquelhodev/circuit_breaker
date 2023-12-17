defmodule CircuitBreaker.Manager do
  alias CircuitBreaker.Manager.Supervisor
  alias CircuitBreaker.State

  def get_state(component_name) do
    case :ets.lookup(:circuit_breaker, component_name) do
      [] -> %State{state: :closed, errors: []}
      [{_name, state}] -> state
    end
  end

  def bump(component_name, config) do
    pid = Supervisor.get_worker_pid(component_name, config)
    GenServer.call(pid, :bump)
  end

  def book_half_open_call(component_name) do
    pid = Supervisor.get_worker_pid(component_name, nil)
    GenServer.call(pid, :book_half_open_call)
  end

  def report_half_open_call(component_name, job_id, has_errors?) do
    pid = Supervisor.get_worker_pid(component_name, nil)
    GenServer.call(pid, {:report_half_open_call, job_id, has_errors?})
  end
end
