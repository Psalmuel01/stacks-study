import { useState, useEffect } from "react";
import { useCounterContract } from "./hooks/useCounterContract";
import { isConnected } from "@stacks/connect";

const CounterWidget = () => {
  const [counter, setCounter] = useState(0);
  const [isLoading, setIsLoading] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const { readContract, callContract } = useCounterContract();
  const authenticated = isConnected();

  // --------------------
  // Read counter value
  // --------------------
  const fetchCounter = async () => {
    setIsLoading(true);
    try {
      const result = await readContract("get-counter");
      // @ts-expect-error clarity value
      setCounter(Number(result.value));
    } catch (err) {
      console.error("Failed to fetch counter:", err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchCounter();
  }, [readContract]);

  // --------------------
  // Write helpers
  // --------------------
  const handleTx = async (fn: "increment" | "decrement" | "reset-counter") => {
    if (!authenticated || isSubmitting) return;

    setIsSubmitting(true);
    try {
      await callContract({
        functionName: fn,
        functionArgs: [],
      });

      // re-sync after tx
      await fetchCounter();
    } catch (err) {
      console.error(`Failed to ${fn}:`, err);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="mt-16 bg-white/15 backdrop-blur-lg rounded-3xl p-8 border border-white/20 text-center">
      <h2 className="text-2xl font-bold text-white mb-6">Counter</h2>

      <div className="text-6xl font-extrabold text-yellow-400 mb-8">
        {isLoading ? "…" : counter}
      </div>

      <div className="flex justify-center gap-4 flex-wrap">
        <button
          onClick={() => handleTx("increment")}
          disabled={!authenticated || isSubmitting}
          className="bg-green-500 hover:bg-green-600 disabled:opacity-50
                     text-white px-6 py-3 rounded-full font-semibold transition"
        >
          Increment
        </button>

        <button
          onClick={() => handleTx("decrement")}
          disabled={!authenticated || isSubmitting}
          className="bg-red-500 hover:bg-red-600 disabled:opacity-50
                     text-white px-6 py-3 rounded-full font-semibold transition"
        >
          Decrement
        </button>

        <button
          onClick={() => handleTx("reset-counter")}
          disabled={!authenticated || isSubmitting}
          className="bg-gray-500 hover:bg-gray-600 disabled:opacity-50
                     text-white px-6 py-3 rounded-full font-semibold transition"
        >
          Reset
        </button>
      </div>
    </div>
  );
};

export default CounterWidget;
