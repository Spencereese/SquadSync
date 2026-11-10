# Xbox presence, research only

No Xbox code is in this repo. This note is the choice to make before any of it is built.

## Official Microsoft and Xbox APIs

Xbox Live presence for another person is not a public web API the way Steam's GetPlayerSummaries is.

What Microsoft documents for games and partners:

- Microsoft identity (OAuth 2 / Microsoft Entra) plus Xbox Live user tokens (XSTS). A title or an authorized service signs the user in and receives an XToken. That token is for that user, and it expires.
- Presence for a signed-in Xbox user is a partner API (`userpresence.xboxlive.com` and the related Xbox Live REST services). Access is through the Xbox Live developer program: ID@Xbox, or a managed-partner agreement. A store title that is not in that program does not get a key that can ask "what is this gamertag playing?"
- The terms that come with that access forbid scraping the Xbox app, Xbox.com, or the console, and they forbid sharing Xbox Live data outside the permissions Microsoft granted. A private squad app would need its own partner enrollment. Enrollment is for shipping an Xbox title or a Microsoft-approved service, not for reading eight friends' current game from a phone.

There is no supported "paste a gamertag, get the current game" call for an ordinary developer account.

## Third-party: OpenXBL and similar

OpenXBL (xbl.io) and similar proxies wrap Xbox Live with their own API key. The person links an Xbox account through that service, and the service returns presence, screenshots, and other Xbox Live fields.

That is not a Microsoft API. The Xbox Live Terms of Use do not allow a third party to operate an unofficial client or to share Xbox Live account data through a proxy. Those services break when Microsoft changes tokens, and a store app that depends on one can be rejected or shut off without notice. Using one would also put the squad's Xbox sign-in in a service Spencer does not operate.

## Recommendation

Do not build Xbox presence now.

Steam stays the PC source because the person creates their own Web API key and the profile is theirs to share. Xbox should wait until Spencer has an Xbox Live partner agreement that explicitly includes presence for this app. Until that exists, the board must not guess that a PC game name means an Xbox or any other console.

OpenXBL is not the path.
