defmodule CircuitBreaker do
  alias CircuitBreaker.Manager.Supervisor
  alias CircuitBreaker.State

  defmacro __using__(opts) do
    quote location: :keep do
      def __opts__ do
        Keyword.put(unquote(opts), :worker, to_string(__MODULE__))
      end
    end
  end

  defmacro with_breaker(config, do: clause) do
    quote do
      config = unquote(config)

      errors = Keyword.get(config, :errors)
      name = Keyword.get(config, :name)
      config = Keyword.get(config, :config)

      state = %State{} = Supervisor.get_state(name, config)

      current_status = state.state

      cond do
        current_status == :open ->
          {:error, :open_circuit_breaker}

        current_status == :closed ->
          resp = unquote(clause)

          if resp in errors do
            Supervisor.bump(name, config)
          end

          resp

        current_status == :half_open ->
          case Supervisor.book_half_open_call(name) do
            {state = %State{}, job_id} ->
              resp = unquote(clause)

              has_errors? = resp in errors

              Supervisor.report_half_open_call(name, job_id, has_errors?)

              resp

            error ->
              error
          end
      end
    end
  end
end
