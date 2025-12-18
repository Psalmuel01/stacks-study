import express from 'express';

const app = express();
app.use(express.json());

app.post("/counter-event", (req, res) => {
    console.log("Full payload received:", req.body);  // Log this first to inspect real structure!

    const apply = req.body.apply || req.body.event?.apply || [];  // Fallback for safety

    if (apply.length === 0) {
        return res.sendStatus(200);
    }

    apply.forEach((item) => {
        const tx = item.transaction;
        if (!tx) return;

        // Print events are usually in metadata.print_events (array)
        const printEvents = tx.metadata?.print_events || tx.metadata?.print_event || [];

        printEvents.forEach((printEvent) => {
            if (printEvent) {
                console.log("Counter update:", printEvent.value);  // Or printEvent for full object
                // Further processing: e.g., update a DB with the new counter value
            }
        });

        // Optional: Handle contract_call details if needed (e.g., function name)
        if (tx.contract_call) {
            console.log("Function called:", tx.contract_call.function_name);
        }
    });

    res.sendStatus(200);  // Always acknowledge quickly!
});

app.listen(3000, () => console.log('Backend listening on port 3000'));
