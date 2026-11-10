import {
  SummaryCache,
  interpretSteamInput,
  parsePlayerSummaries,
  presenceKind,
  resolveToSteamId,
  summariesUrl,
} from "./steam.ts";

function assertEqual(actual: unknown, expected: unknown): void {
  const left = JSON.stringify(actual);
  const right = JSON.stringify(expected);
  if (left !== right) throw new Error(`${left} != ${right}`);
}

const steamId = "76561198000000001";

Deno.test("a profile url, a vanity, and a SteamID64 are told apart", () => {
  assertEqual(interpretSteamInput(` https://steamcommunity.com/profiles/${steamId} `), {
    kind: "id",
    steamId,
  });
  assertEqual(interpretSteamInput("https://steamcommunity.com/id/Example_Name"), {
    kind: "vanity",
    vanity: "Example_Name",
  });
  assertEqual(interpretSteamInput(steamId), { kind: "id", steamId });
  assertEqual(interpretSteamInput("example"), { kind: "vanity", vanity: "example" });
  assertEqual(interpretSteamInput(""), { kind: "invalid" });
  assertEqual(interpretSteamInput("not a steam id"), { kind: "invalid" });
  assertEqual(interpretSteamInput("12345"), { kind: "invalid" });
});

Deno.test("vanity resolution uses ResolveVanityURL and keeps a direct id local", async () => {
  const calls: string[] = [];
  const fetchImpl = (url: string) => {
    calls.push(url);
    return Promise.resolve({
      ok: true,
      json: () =>
        Promise.resolve({
          response: { success: 1, steamid: steamId },
        }),
    });
  };
  const resolved = await resolveToSteamId(
    "https://steamcommunity.com/id/Example",
    "test-key",
    fetchImpl,
  );
  assertEqual(resolved, { steamId });
  if (calls.length !== 1) throw new Error(`expected one fetch, got ${calls.length}`);
  if (!calls[0].includes("/ISteamUser/ResolveVanityURL/")) {
    throw new Error(calls[0]);
  }
  if (!calls[0].includes("vanityurl=Example")) throw new Error(calls[0]);
  if (!calls[0].includes("key=test-key")) throw new Error("key missing");

  const direct = await resolveToSteamId(steamId, "test-key", () => {
    throw new Error("a SteamID64 must not call the network");
  });
  assertEqual(direct, { steamId });

  const missing = await resolveToSteamId("nobody", "test-key", () =>
    Promise.resolve({
      ok: true,
      json: () => Promise.resolve({ response: { success: 42 } }),
    })
  );
  assertEqual(missing, { error: "not_found" });
});

Deno.test("summaries parse in one batch and a private profile hides the game", () => {
  const url = summariesUrl([steamId, "76561198000000002"], "test-key");
  if (!url.includes("/ISteamUser/GetPlayerSummaries/v0002/")) {
    throw new Error(url);
  }
  if (!url.includes("steamids=76561198000000001%2C76561198000000002") &&
    !url.includes("steamids=76561198000000001,76561198000000002")) {
    throw new Error(url);
  }
  const players = parsePlayerSummaries({
    response: {
      players: [
        {
          steamid: steamId,
          communityvisibilitystate: 3,
          personastate: 1,
          gameextrainfo: "Halo Infinite",
        },
        {
          steamid: "76561198000000002",
          communityvisibilitystate: 1,
          personastate: 1,
          gameextrainfo: "Halo Infinite",
        },
        {
          steamid: "76561198000000003",
          communityvisibilitystate: 3,
          personastate: 1,
        },
      ],
    },
  });
  assertEqual(presenceKind(players[0]), "playing");
  assertEqual(players[0].game, "Halo Infinite");
  assertEqual(presenceKind(players[1]), "private");
  assertEqual(presenceKind(players[2]), "not_in_game");
  assertEqual(presenceKind(undefined), "private");
  assertEqual(parsePlayerSummaries({}), []);
});

Deno.test("the summary cache lasts about a minute", () => {
  const cache = new SummaryCache(60_000);
  const ids = [steamId];
  const players = [{
    steamId,
    isPublic: true,
    game: "Halo Infinite",
    personaState: 1,
  }];
  assertEqual(cache.get(ids, 1_000), null);
  cache.set(ids, players, 1_000);
  assertEqual(cache.get(ids, 60_999), players);
  assertEqual(cache.get(ids, 61_000), null);
});
