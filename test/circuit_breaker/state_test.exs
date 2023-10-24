defmodule CircuitBreaker.StateTest do
  use ExUnit.Case, async: true

  alias CircuitBreaker.State

  describe "get_number_errors/2" do
    test "gets the number of errors" do
      time_now = DateTime.utc_now()

      from = DateTime.add(time_now, -10, :minute)

      state = %State{
        state: :closed,
        errors: [
          DateTime.add(time_now, -5, :minute),
          DateTime.add(time_now, -7, :minute),
          DateTime.add(time_now, -15, :minute)
        ]
      }

      assert State.get_number_errors(state, from) == 2
    end
  end
end
