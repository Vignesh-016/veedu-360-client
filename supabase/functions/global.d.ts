// ---------------------------------------------------------------------------
// Deno Edge Runtime ambient declarations for VS Code TypeScript IntelliSense
// These are not shipped to Deno; they only tell VS Code what types exist.
// ---------------------------------------------------------------------------

declare namespace Deno {
  // Environment variables
  interface Env {
    get(key: string): string | undefined;
    set(key: string, value: string): void;
    delete(key: string): void;
    toObject(): Record<string, string>;
  }
  const env: Env;

  // HTTP server
  interface ServeOptions {
    port?: number;
    hostname?: string;
    signal?: AbortSignal;
    reusePort?: boolean;
    onListen?: (params: { hostname: string; port: number }) => void;
    onError?: (error: unknown) => Response | Promise<Response>;
  }

  interface HttpServer {
    readonly finished: Promise<void>;
    shutdown(): Promise<void>;
    ref(): void;
    unref(): void;
  }

  type ServeHandler = (request: Request) => Response | Promise<Response>;

  function serve(
    handler: ServeHandler,
    options?: ServeOptions,
  ): HttpServer;

  // Misc utilities
  function exit(code?: number): never;
}

// ---------------------------------------------------------------------------
// Razorpay – bare specifier used in import_map / deno.json
// ---------------------------------------------------------------------------
declare module "razorpay" {
  interface OrderCreateOptions {
    amount: number;
    currency: string;
    receipt?: string;
    notes?: Record<string, string>;
    [key: string]: unknown;
  }

  interface Order {
    id: string;
    amount: number;
    currency: string;
    receipt?: string;
    status: string;
    [key: string]: unknown;
  }

  export default class Razorpay {
    constructor(options: { key_id: string; key_secret: string });
    orders: {
      create(options: OrderCreateOptions): Promise<Order>;
    };
  }
}

// npm: specifier alias used when calling Deno directly
declare module "npm:razorpay@2.9.6" {
  export { default } from "razorpay";
}

// @supabase/supabase-js – both specifier forms point to the same node_modules types
declare module "npm:@supabase/supabase-js@2" {
  export * from "@supabase/supabase-js";
  export { createClient } from "@supabase/supabase-js";
}

declare module "jsr:@supabase/supabase-js@2" {
  export * from "@supabase/supabase-js";
  export { createClient } from "@supabase/supabase-js";
}

// ---------------------------------------------------------------------------
// node:crypto – subset used by these Edge Functions
// ---------------------------------------------------------------------------
declare module "node:crypto" {
  interface Hmac {
    update(data: string | Buffer): Hmac;
    digest(encoding: "hex" | "base64"): string;
  }

  function createHmac(algorithm: string, key: string | Buffer): Hmac;
  function timingSafeEqual(a: Uint8Array, b: Uint8Array): boolean;

  const crypto: {
    createHmac: typeof createHmac;
    timingSafeEqual: typeof timingSafeEqual;
  };

  export { createHmac, timingSafeEqual };
  export default crypto;
}
