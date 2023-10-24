defmodule CircuitBreaker.Manager.Worker do
  use GenServer, restart: :temporary

  alias CircuitBreaker.State

  require Logger

  @registry CircuitBreaker.Manager.Registry

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts,
      name: {:via, Registry, {@registry, Keyword.get(opts, :name)}}
    )
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)
    {:ok, %State{state: :closed, errors: [], config: Keyword.get(opts, :config)}}
  end

  @impl true
  def handle_cast(:bump, state = %State{}) do
    old_state = state.state

    state =
      state
      |> State.add_error()
      |> State.maybe_update_circuit_status()

    if old_state == :closed and state.state == :open do
      Process.send_after(self(), :change_half_open, state.config.timeout)
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:report_half_open_call, job_id, has_errors?}, state) do
    old_state = state.state

    state =
      state
      |> State.report_half_open_call(job_id, has_errors?)
      |> State.maybe_update_circuit_status()

    if old_state == :half_open and state.state == :open do
      Process.send_after(self(), :change_half_open, state.config.timeout)
    end

    state =
      if old_state == :half_open and state.state == :closed do
        State.clear_errors(state)
      else
        state
      end

    {:noreply, state}
  end

  @impl true
  def handle_info(:change_half_open, state) do
    Logger.debug("Changing to :half_open")

    state = State.change_half_open(state)
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:book_half_open_call, _from, state) do
    case State.book_half_open_call(state) do
      {:error, _} = error -> {:reply, error, state}
      {state, job_id} -> {:reply, {state, job_id}, state}
    end
  end
end
