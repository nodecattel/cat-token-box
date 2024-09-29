import { NestFactory } from '@nestjs/core';
import { AppWorkerModule } from './app-worker.module';
import * as ecc from '@bitcoin-js/tiny-secp256k1-asmjs';
import { initEccLib } from 'bitcoinjs-lib';
import * as childProcess from 'child_process';
import * as os from 'os';

async function bootstrap() {
  initEccLib(ecc);

  const numCPUs = os.cpus().length;
  const workerCount = Math.min(numCPUs, parseInt(process.env.WORKER_CONCURRENCY || '4', 10));

  if (process.env.WORKER_ID === undefined) {
    console.log(`Primary ${process.pid} is running`);

    // Fork workers
    for (let i = 0; i < workerCount; i++) {
      const worker = childProcess.fork(__filename, [], {
        env: { ...process.env, WORKER_ID: i.toString() }
      });

      worker.on('exit', (code, signal) => {
        console.log(`Worker ${worker.pid} died`);
        // Replace the dead worker
        childProcess.fork(__filename, [], {
          env: { ...process.env, WORKER_ID: i.toString() }
        });
      });
    }
  } else {
    try {
      const app = await NestFactory.create(AppWorkerModule);
      await app.listen(0); // Use port 0 to automatically assign a free port
      console.log(`Worker ${process.pid} started`);
    } catch (error) {
      console.error('Error starting worker:', error);
      process.exit(1);
    }
  }
}

bootstrap().catch(error => {
  console.error('Unhandled error in bootstrap:', error);
  process.exit(1);
});
