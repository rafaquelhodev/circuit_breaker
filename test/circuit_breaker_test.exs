defmodule CircuitBreakerTest do
  use ExUnit.Case, async: true

  use CircuitBreaker, funs: [hello: [arity: 1, errors: [{:error}]]]

  describe "with_breaker/2" do
    test "should open the circuit when the thereshold is reached" do
      func_test = fn input ->
        CircuitBreaker.with_breaker errors: [:error],
                                    name: "http_client",
                                    config: %{
                                      threshold_number: 5,
                                      threshold_seconds: 10,
                                      timeout: 3000,
                                      half_open_number: 10
                                    } do
          input
        end
      end

      Enum.each(1..5, fn _ ->
        assert :error == func_test.(:error)
      end)

      assert {:error, :open_circuit_breaker} == func_test.(:error)
    end

    test "should change to half_open when the timeout is reached" do
      func_test = fn input ->
        CircuitBreaker.with_breaker errors: [:error],
                                    name: "half_open_test",
                                    config: %{
                                      threshold_number: 5,
                                      threshold_seconds: 10,
                                      timeout: 2000,
                                      half_open_number: 10
                                    } do
          input
        end
      end

      Enum.each(1..5, fn _ ->
        assert :error == func_test.(:error)
      end)

      assert {:error, :open_circuit_breaker} == func_test.(:error)

      Process.sleep(2000)
      assert :ok == func_test.(:ok)
    end

    test "should close if the half_open_number limit is reached" do
      func_test = fn input ->
        CircuitBreaker.with_breaker errors: [:error],
                                    name: "half_open_to_closed_test",
                                    config: %{
                                      threshold_number: 5,
                                      threshold_seconds: 10,
                                      timeout: 2000,
                                      half_open_number: 10
                                    } do
          input
        end
      end

      Enum.each(1..5, fn _ ->
        assert :error == func_test.(:error)
      end)

      assert {:error, :open_circuit_breaker} == func_test.(:error)

      Process.sleep(2000)
      assert :ok == func_test.(:ok)

      Enum.each(1..10, fn _ ->
        assert :ok == func_test.(:ok)
      end)

      assert :ok == func_test.(:ok)
    end

    test "should open if there is an error when half_open" do
      func_test = fn input ->
        CircuitBreaker.with_breaker errors: [:error],
                                    name: "half_open_to_open_test",
                                    config: %{
                                      threshold_number: 5,
                                      threshold_seconds: 10,
                                      timeout: 2000,
                                      half_open_number: 10
                                    } do
          input
        end
      end

      Enum.each(1..5, fn _ ->
        assert :error == func_test.(:error)
      end)

      assert {:error, :open_circuit_breaker} == func_test.(:error)

      Process.sleep(2000)
      assert :ok == func_test.(:ok)
      assert :error == func_test.(:error)
      assert {:error, :open_circuit_breaker} == func_test.(:error)
    end
  end
end
