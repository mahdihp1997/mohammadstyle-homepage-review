import { NextRequest, NextResponse } from 'next/server';
export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
const routes = new Set(['read/catalog', 'read/history', 'read/booking', 'read/events', 'read/cancellation-preview', 'commands/availability', 'commands/quote', 'commands/draft', 'commands/hold', 'commands/confirm', 'commands/cancel', 'commands/reschedule']);
export async function POST(req: NextRequest, { params }: {
    params: Promise<{
        path: string[];
    }>;
}) {
    const route = (await params).path.join('/');
    const closed = () => NextResponse.json({ code: 'SERVER_MODE_DISABLED' }, { status: 404, headers: { 'Cache-Control': 'no-store' } });
    // No configurable upstream URL, production credential path, login or forwarded identity headers.
    // Next15 normalizes nextUrl.hostname to localhost even for a 127.0.0.1 request.
    // Validate the original exact Host and Origin; never trust forwarded host headers.
    if (process.env.MS_BOOKING_SERVER_ENABLED !== '1' || process.env.NODE_ENV === 'production' || !routes.has(route) || req.headers.get('host') !== '127.0.0.1:3000')
        return closed();
    if (req.headers.get('origin') !== 'http://127.0.0.1:3000' || (req.headers.get('sec-fetch-site') && req.headers.get('sec-fetch-site') !== 'same-origin') || !/^application\/json(?:;\s*charset=utf-8)?$/i.test(req.headers.get('content-type') ?? ''))
        return NextResponse.json({ code: 'FORBIDDEN' }, { status: 403 });
    const body = await req.text();
    if (Buffer.byteLength(body) > 32768)
        return NextResponse.json({ code: 'INVALID_REQUEST' }, { status: 413 });
    const cookie = req.cookies.getAll('ms_session');
    if (cookie.length !== 1 || !/^[A-Za-z0-9_-]{43}$/.test(cookie[0].value))
        return NextResponse.json({ code: 'UNAUTHENTICATED' }, { status: 401 });
    try {
        const upstream = await fetch('http://127.0.0.1:3110/api/v1/booking/' + route, { method: 'POST', cache: 'no-store', signal: AbortSignal.timeout(35000), headers: { 'content-type': 'application/json', origin: 'http://127.0.0.1:3110', 'sec-fetch-site': 'same-origin', cookie: 'ms_session=' + cookie[0].value, 'x-csrf-token': req.headers.get('x-csrf-token') ?? '', 'idempotency-key': req.headers.get('idempotency-key') ?? '' }, body });
        const json = await upstream.json();
        return NextResponse.json(json, { status: upstream.status, headers: { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' } });
    }
    catch {
        return NextResponse.json({ code: 'UNAVAILABLE', retryable: true }, { status: 503, headers: { 'Cache-Control': 'no-store' } });
    }
}
