import { createApp } from './app.js';
import { event } from './observability.js';

try {
  const { app, config } = await createApp();
  await app.listen(config.port, config.host);
  event('b0.started', { port: config.port, environment: 'b0-local' });
} catch {
  event('b0.start_failed');
  process.exitCode = 1;
}
