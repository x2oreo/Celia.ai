import { rcp } from '@kit.RemoteCommunicationKit';
import { BusinessError } from '@kit.BasicServicesKit';

/** HTTP status and body; status 0 = no response (network error, timeout), `body` then holds the error code. */
export interface RestResponse {
  status: number;
  body: string;
}

function response(status: number, body: string): RestResponse {
  const r: RestResponse = { status: status, body: body };
  return r;
}

const TIMEOUT_MS = 5000;

/**
 * One HTTP client for every Supabase call on the watch (energy). A Remote Communication Kit session is meant to be
 * reused: requests share its connection pool and TLS sessions, so the radio does fewer handshakes. (A Network Kit
 * `HttpRequest` is single-use: "Each httpRequest corresponds to an HTTP request task and cannot be reused.")
 * The session is created on first use, lives as long as the app process and adds the `apikey` / `Authorization`
 * headers to every request.
 */
export class RestClient {
  private baseUrl: string;
  private anonKey: string;
  private session: rcp.Session | undefined = undefined;
  // This watch's secret from pairing_start (backend migration 20261004100300). Sent as `x-watch-secret` so the
  // server lets this watch, and only this watch, read its context and upload once it has paired.
  private watchSecret: string = '';

  constructor(supabaseUrl: string, anonKey: string) {
    this.baseUrl = supabaseUrl;
    this.anonKey = anonKey;
  }

  setWatchSecret(secret: string): void {
    this.watchSecret = secret;
  }

  hasWatchSecret(): boolean {
    return this.watchSecret.length > 0;
  }

  /** `path` starts with "/", e.g. "/rest/v1/watch_metrics". `prefer` sets the PostgREST Prefer header. */
  async post(path: string, json: string, prefer: string): Promise<RestResponse> {
    const headers: rcp.RequestHeaders = this.headers();
    headers['content-type'] = 'application/json';
    if (prefer.length > 0) {
      headers['prefer'] = prefer;
    }
    return this.send(new rcp.Request(this.baseUrl + path, 'POST', headers, json));
  }

  async get(path: string): Promise<RestResponse> {
    return this.send(new rcp.Request(this.baseUrl + path, 'GET', this.headers()));
  }

  private headers(): rcp.RequestHeaders {
    const h: rcp.RequestHeaders = {};
    if (this.watchSecret.length > 0) {
      h['x-watch-secret'] = this.watchSecret;
    }
    return h;
  }

  private open(): rcp.Session {
    if (this.session === undefined) {
      const timeout: rcp.Timeout = { connectMs: TIMEOUT_MS, transferMs: TIMEOUT_MS };
      const headers: rcp.RequestHeaders = {
        'apikey': this.anonKey,
        'authorization': `Bearer ${this.anonKey}`
      };
      const cfg: rcp.SessionConfiguration = {
        headers: headers,
        requestConfiguration: { transfer: { timeout: timeout } }
      };
      this.session = rcp.createSession(cfg);
    }
    return this.session;
  }

  private async send(req: rcp.Request): Promise<RestResponse> {
    try {
      const resp = await this.open().fetch(req);
      const text = resp.toString();
      return response(resp.statusCode, text !== null ? text : '');
    } catch (e) {
      const err = e as BusinessError;
      return response(0, `${err.code}`);
    }
  }
}
