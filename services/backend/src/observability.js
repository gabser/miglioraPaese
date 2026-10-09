import metadata from '../package.json' with { type: 'json' };
import { randomUUID } from 'node:crypto';

const requestIdPattern = /^[A-Za-z0-9._:-]{1,128}$/;

export function createObservability({
  clock = Date.now,
  generateRequestId = randomUUID,
  logger = null,
  version = metadata.version,
} = {}) {
  const processStartedAt = clock();
  const requests = new Map();

  function begin(req) {
    const incoming = headerValue(req, 'x-request-id');
    return {
      requestId:
        typeof incoming === 'string' && requestIdPattern.test(incoming)
          ? incoming
          : generateRequestId(),
      startedAt: clock(),
    };
  }

  function complete({ context, method, route, statusCode }) {
    const durationMs = Math.max(0, clock() - context.startedAt);
    const labels = {
      method: normalizedLabel(method, 'UNKNOWN'),
      route: normalizedLabel(route, 'unmatched'),
      status: String(statusCode),
    };
    const key = JSON.stringify(labels);
    const current = requests.get(key) ?? {
      labels,
      count: 0,
      durationMs: 0,
    };
    current.count += 1;
    current.durationMs += durationMs;
    requests.set(key, current);

    if (typeof logger === 'function') {
      try {
        logger(
          JSON.stringify({
            timestamp: new Date(clock()).toISOString(),
            level: statusCode >= 500 ? 'error' : 'info',
            event: 'http_request',
            requestId: context.requestId,
            method: labels.method,
            route: labels.route,
            statusCode,
            durationMs,
          }),
        );
      } catch {
        // Logging failures must not change the HTTP response.
      }
    }
  }

  function metrics() {
    const lines = [
      '# HELP migliorapaese_build_info Build information for the backend.',
      '# TYPE migliorapaese_build_info gauge',
      `migliorapaese_build_info{version="${escapeLabel(version)}"} 1`,
      '# HELP migliorapaese_process_uptime_seconds Process uptime in seconds.',
      '# TYPE migliorapaese_process_uptime_seconds gauge',
      `migliorapaese_process_uptime_seconds ${Math.max(0, clock() - processStartedAt) / 1000}`,
      '# HELP migliorapaese_http_requests_total Completed HTTP requests.',
      '# TYPE migliorapaese_http_requests_total counter',
    ];
    for (const entry of sortedEntries(requests)) {
      lines.push(
        `migliorapaese_http_requests_total${formatLabels(entry.labels)} ${entry.count}`,
      );
    }
    lines.push(
      '# HELP migliorapaese_http_request_duration_milliseconds_sum Total request duration in milliseconds.',
      '# TYPE migliorapaese_http_request_duration_milliseconds_sum counter',
    );
    for (const entry of sortedEntries(requests)) {
      lines.push(
        `migliorapaese_http_request_duration_milliseconds_sum${formatLabels(entry.labels)} ${entry.durationMs}`,
      );
    }
    return lines.join('\n') + '\n';
  }

  return { begin, complete, metrics };
}

export function instrumentResponse({
  req,
  res,
  observability,
  routeName,
}) {
  const context = observability.begin(req);
  const originalWriteHead = res.writeHead.bind(res);
  let completed = false;
  res.writeHead = (statusCode, headers = {}) => {
    if (!completed) {
      completed = true;
      observability.complete({
        context,
        method: req.method,
        route: routeName(),
        statusCode,
      });
    }
    return originalWriteHead(statusCode, {
      'x-request-id': context.requestId,
      ...headers,
    });
  };
  return context;
}

function headerValue(req, name) {
  const value = req.headers?.[name];
  return Array.isArray(value) ? value[0] : value ?? null;
}

function normalizedLabel(value, fallback) {
  return typeof value === 'string' && value.length > 0 ? value : fallback;
}

function sortedEntries(entries) {
  return [...entries.values()].sort((a, b) => {
    return JSON.stringify(a.labels).localeCompare(JSON.stringify(b.labels));
  });
}

function formatLabels(labels) {
  return (
    '{' +
    Object.entries(labels)
      .map(([key, value]) => `${key}="${escapeLabel(value)}"`)
      .join(',') +
    '}'
  );
}

function escapeLabel(value) {
  return String(value)
    .replaceAll('\\', '\\\\')
    .replaceAll('\n', '\\n')
    .replaceAll('"', '\\"');
}
