defmodule CircuitBreaker.State do
  defstruct state: :closed,
            errors: [],
            config: %{},
            half_open_calls: %{},
            last_half_open_call_id: 0

  defmodule CircuitBreaker.State.Config do
    @type t() :: %__MODULE__{
            threshold_number: pos_integer(),
            threshold_seconds: pos_integer(),
            timeout: float(),
            half_open_number: pos_integer()
          }

    defstruct [:threshold_number, :threshold_seconds, :timeout, :half_open_number]
  end

  @type t() :: %__MODULE__{
          state: :closed | :open | :half_open,
          errors: list(DateTime.t()),
          half_open_calls: map(),
          config: CircuitBreaker.State.Config.t()
        }

  def add_error(state = %__MODULE__{}) do
    {_, state} =
      Map.get_and_update(state, :errors, fn value ->
        {value, [DateTime.utc_now() | value]}
      end)

    state
  end

  def clear_errors(state = %__MODULE__{}) do
    Map.put(state, :errors, [])
  end

  def change_half_open(state = %__MODULE__{}) do
    state
    |> Map.put(:state, :half_open)
    |> Map.put(:half_open_calls, %{})
    |> Map.put(:last_half_open_call_id, 0)
  end

  def report_half_open_call(state = %__MODULE__{}, call_id, has_error?) do
    {_, state} =
      Map.get_and_update(state, :half_open_calls, fn value ->
        result = if has_error? == true, do: :fail, else: :success
        {value, Map.put(value, call_id, result)}
      end)

    state
  end

  def book_half_open_call(state = %__MODULE__{}) do
    number_jobs = Map.keys(state.half_open_calls)

    if length(number_jobs) < state.config.half_open_number do
      new_id = state.last_half_open_call_id + 1

      {_, state} =
        Map.get_and_update(state, :half_open_calls, fn value ->
          new_id = state.last_half_open_call_id + 1
          {value, Map.put(value, new_id, :running)}
        end)

      {Map.put(state, :last_half_open_call_id, new_id), new_id}
    else
      {:error, :exceeded_half_open_calls}
    end
  end

  def maybe_update_circuit_status(state = %__MODULE__{state: :half_open}) do
    half_open_calls = state.half_open_calls

    calls =
      Enum.reduce_while(half_open_calls, %{number_success: 0, number_failed: 0}, fn {_id, result},
                                                                                    acc ->
        if result == :success do
          acc = Map.put(acc, :number_success, acc.number_success + 1)
          {:cont, acc}
        else
          acc = Map.put(acc, :number_failed, acc.number_failed + 1)
          {:halt, acc}
        end
      end)

    cond do
      calls.number_failed >= 1 -> Map.put(state, :state, :open)
      calls.number_success == state.config.half_open_number -> Map.put(state, :state, :closed)
      true -> state
    end
  end

  def maybe_update_circuit_status(state = %__MODULE__{state: :closed}) do
    config = state.config

    error_number =
      get_number_errors(
        state,
        DateTime.add(DateTime.utc_now(), -config.threshold_seconds, :second)
      )

    if error_number >= config.threshold_number do
      Map.put(state, :state, :open)
    else
      state
    end
  end

  @spec get_number_errors(t(), DateTime.t()) :: pos_integer()
  def get_number_errors(state = %__MODULE__{}, from) do
    state
    |> Map.get(:errors)
    |> Enum.filter(fn error_datetime ->
      DateTime.compare(error_datetime, from) == :gt
    end)
    |> length()
  end
end
