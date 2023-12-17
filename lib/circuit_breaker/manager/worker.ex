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
    initial_state = %State{state: :closed, errors: [], config: Keyword.get(opts, :config)}

    name = Keyword.get(opts, :name)

    :ets.insert(:circuit_breaker, {name, initial_state})

    Process.flag(:trap_exit, true)

    {:ok, %{name: name, state: initial_state}}
  end

  @impl true
  def handle_call(:bump, _from, %{name: name} = gen_state) do
    [{name, state}] = :ets.lookup(:circuit_breaker, name)

    old_state = state.state

    state =
      state
      |> State.add_error()
      |> State.maybe_update_circuit_status()

    :ets.insert(:circuit_breaker, {name, state})

    if old_state == :closed and state.state == :open do
      Logger.debug("Scheduling half open")
      Process.send_after(self(), :change_half_open, state.config.timeout_milliseconds)
    end

    {:reply, gen_state, gen_state}
  end

  @impl true
  def handle_call({:report_half_open_call, job_id, has_errors?}, _from, %{name: name} = gen_state) do
    [{name, state}] = :ets.lookup(:circuit_breaker, name)

    old_state = state.state

    state =
      state
      |> State.report_half_open_call(job_id, has_errors?)
      |> State.maybe_update_circuit_status()

    if old_state == :half_open and state.state == :open do
      Process.send_after(self(), :change_half_open, state.config.timeout_milliseconds)
    end

    state =
      if old_state == :half_open and state.state == :closed do
        State.clear_errors(state)
      else
        state
      end

    :ets.insert(:circuit_breaker, {name, state})

    {:reply, gen_state, gen_state}
  end

  @impl true
  def handle_call(:book_half_open_call, _from, %{name: name} = gen_state) do
    [{name, state}] = :ets.lookup(:circuit_breaker, name)

    case State.book_half_open_call(state) do
      {:error, _} = error ->
        {:reply, error, gen_state}

      {state, job_id} ->
        :ets.insert(:circuit_breaker, {name, state})
        {:reply, {state, job_id}, gen_state}
    end
  end

  @impl true
  def handle_info(:change_half_open, %{name: name} = gen_state) do
    Logger.debug("Changing to :half_open")

    [{name, state}] = :ets.lookup(:circuit_breaker, name)

    state = State.change_half_open(state)

    :ets.insert(:circuit_breaker, {name, state})

    Logger.debug("Changed to :half_open")

    {:noreply, gen_state}
  end
end
