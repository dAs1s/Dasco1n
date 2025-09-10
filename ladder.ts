import type { Command } from './index';

const PAGE_SIZE = 200; // bump if your API allows larger pages

async function fetchAllLadder(helpers: any): Promise<any[]> {
  const all: any[] = [];
  let url = `/api/ladder?limit=${PAGE_SIZE}`;
  let guard = 100; // safety to prevent infinite loops

  while (guard-- > 0) {
    const data = await helpers.getJSON(url);
    const items: any[] = data?.items ?? (Array.isArray(data) ? data : []);
    if (!items.length) break;

    all.push(...items);

    // --- Detect the next page across common API patterns ---
    if (data?.nextCursor) {
      // cursor-based
      url = `/api/ladder?limit=${PAGE_SIZE}&cursor=${encodeURIComponent(data.nextCursor)}`;
    } else if (data?.cursorNext) {
      url = `/api/ladder?limit=${PAGE_SIZE}&cursor=${encodeURIComponent(data.cursorNext)}`;
    } else if (typeof data?.page === 'number' && typeof data?.pageSize === 'number' && typeof data?.total === 'number') {
      // page/pageSize/total
      const nextPage = data.page + 1;
      if (nextPage * data.pageSize < data.total) {
        url = `/api/ladder?page=${nextPage}&pageSize=${data.pageSize}`;
      } else break;
    } else if (typeof data?.offset === 'number' && typeof data?.limit === 'number') {
      // offset/limit
      const nextOffset = data.offset + data.limit;
      if (items.length === data.limit) {
        url = `/api/ladder?offset=${nextOffset}&limit=${data.limit}`;
      } else break;
    } else if (typeof data?.hasMore === 'boolean' && data.hasMore && data?.lastId) {
      // hasMore + lastId (another cursor shape)
      url = `/api/ladder?limit=${PAGE_SIZE}&after=${encodeURIComponent(data.lastId)}`;
    } else if (data?.next) {
      // "next" link (absolute or relative)
      url = data.next;
    } else {
      // no sign of more pages
      break;
    }
  }

  return all;
}

const ladder: Command = async ({ msg, helpers }) => {
  try {
    const items = await fetchAllLadder(helpers);

    if (!items.length) {
      await msg.reply('No ladder data yet.');
      return;
    }

    const lines = items.map((u: any) => {
      const wl = `W:${u.wins ?? 0} L:${u.losses ?? 0}`;
      const rank = u.rank ?? '';
      return `${rank ? `${rank}. ` : ''}${u.username} — ELO ${u.elo} (${wl})`;
    });

    // Discord messages max out at 2000 chars; keep headroom
    const chunks = chunkLines(lines, 1950);

    for (const chunk of chunks) {
      // eslint-disable-next-line no-await-in-loop
      await msg.reply(chunk);
      // If you have *lots* of players and hit rate limits, add a tiny delay:
      // await sleep(350);
    }
  } catch (e: any) {
    const m = (e?.message ?? '').toString();
    await msg.reply(`❌ ${m || 'fetch failed'}`);
  }
};

function chunkLines(lines: string[], maxLen = 1950): string[] {
  const chunks: string[] = [];
  let buf: string[] = [];
  let curLen = 0;

  for (const line of lines) {
    const addLen = (buf.length ? 1 : 0) + line.length; // +1 for newline
    if (curLen + addLen > maxLen) {
      chunks.push(buf.join('\n'));
      buf = [line];
      curLen = line.length;
    } else {
      buf.push(line);
      curLen += addLen;
    }
  }
  if (buf.length) chunks.push(buf.join('\n'));
  return chunks;
}

// Optional helper if you need throttling to avoid rate limits
function sleep(ms: number) {
  return new Promise((res) => setTimeout(res, ms));
}

export default ladder;
