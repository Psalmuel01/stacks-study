import express, { type Request, type Response } from 'express';
import bodyParser from 'body-parser';
import type { ChainhookPayload } from './types.js';

const app = express();
const port = 3000;

app.use(bodyParser.json());

// Middleware to log all requests
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
  next();
});

app.post('/api/webhook', (req: Request, res: Response) => {
  const authHeader = req.headers['authorization'];

  // // Basic security check (match the token in chainhook.json)
  // if (authHeader !== 'Bearer secret-token') {
  //   console.warn('Unauthorized webhook attempt');
  //   res.status(401).send('Unauthorized');
  //   return;
  // }

  const payload = req.body as ChainhookPayload;

  // Handle Apply events (new blocks)
  if (payload.apply && payload.apply.length > 0) {
    payload.apply.forEach((block) => {
      console.log(`\nProcessing block #${block.block_identifier.index} (${block.block_identifier.hash})`);
      console.log(`Timestamp: ${new Date(block.timestamp * 1000).toISOString()}`);

      if (block.transactions && block.transactions.length > 0) {
        console.log(`Found ${block.transactions.length} relevant transactions:`);
        block.transactions.forEach((tx) => {
          console.log(` - TxID: ${tx.transaction_identifier.hash}`);
          console.log(`   Sender: ${tx.metadata.sender}`);
          console.log(`   Status: ${tx.metadata.success ? 'Success' : 'Failed'}`);
          console.log(`   Description: ${tx.metadata.description}`);
        });
      } else {
        console.log('No relevant transactions in this block.');
      }
    });
  }

  // Handle Rollback events (reorgs)
  if (payload.rollback && payload.rollback.length > 0) {
    console.warn('\nWARNING: Chain reorg detected!');
    payload.rollback.forEach((block) => {
      console.log(`Rolling back block #${block.block_identifier.index} (${block.block_identifier.hash})`);
    });
  }

  res.status(200).send({ status: 'centrifuge-active' });
});

app.listen(port, () => {
  console.log(`Centrifuge app listening at http://localhost:${port}`);
  console.log('Ready to receive Chainhook events at /api/webhook');
});