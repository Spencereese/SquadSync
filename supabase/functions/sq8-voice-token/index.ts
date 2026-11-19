// NOT DEPLOYED. Deploying this function needs Spencer's yes (see README.md).
import { handle } from "./voice.ts";

Deno.serve((request) =>
  handle(request, {
    env: (name) => Deno.env.get(name),
    fetch: (input, init) => fetch(input, init),
    now: () => Date.now() / 1000,
  })
);
