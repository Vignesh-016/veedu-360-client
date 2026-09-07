export type RazorpayCredentials = { keyId: string | undefined; keySecret: string | undefined; mode: 'live' | 'test' };

export const getRazorpayCredentials = (): RazorpayCredentials => {
  const mode = Deno.env.get('RAZORPAY_MODE')?.toLowerCase() === 'test' ? 'test' : 'live';
  return mode === 'test'
    ? { mode, keyId: Deno.env.get('RAZORPAY_TESTKEY_ID') ?? Deno.env.get('RAZORPAY_TEST_KEY_ID'), keySecret: Deno.env.get('RAZORPAY_TESTKEY_SECRET') ?? Deno.env.get('RAZORPAY_TEST_KEY_SECRET') }
    : { mode, keyId: Deno.env.get('RAZORPAY_KEY_ID'), keySecret: Deno.env.get('RAZORPAY_KEY_SECRET') };
};
