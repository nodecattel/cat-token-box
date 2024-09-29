require('dotenv').config();

export const appConfig = () => ({
  rpcHost: process.env.RPC_HOST,
  rpcPort: process.env.RPC_PORT,
  rpcUser: process.env.RPC_USER,
  rpcPassword: process.env.RPC_PASSWORD,
  genesisBlockHeight: Math.max(
    parseInt(process.env.GENESIS_BLOCK_HEIGHT || '2'),
    2,
  ),
  workerConcurrency: parseInt(process.env.WORKER_CONCURRENCY || '48'),
  batchSize: parseInt(process.env.BATCH_SIZE || '1000'),
  syncInterval: parseInt(process.env.SYNC_INTERVAL || '10000'),
});
