# where

Share location with people, simple and free.

<img width="200" alt="where-sharing" src="https://github.com/user-attachments/assets/345c179f-d1ca-49e9-8dcf-94ab32f4a045" />

<img width="200" alt="where-permissions" src="https://github.com/user-attachments/assets/7c811e04-0004-487b-bac3-18694eda70fe" />

<img width="200" alt="where-map" src="https://github.com/user-attachments/assets/43659945-2da8-4f19-97dc-37896054396b" />

## Getting Started

This application has a few workflows:

- Getting stuff ready for background location sharing (permissions, etc)
- Actually sharing it (with a github token to upload location to secret gists)
- Seeing others on a map

### Getting a token

The app needs a token - this is a github personal access token with Gist permissions. To get one:

- https://github.com/settings/personal-access-tokens/new?name=Where%20location%20sharing%20token&description=A%20personal%20access%20token%20for%20the%20where%20app,%20which%20grants%20only%20gist%20permissions&expires_in=none&gists=write

Here's the config to use when creating it - it only needs Gist access:

<img width="2000" alt="token" src="https://github.com/user-attachments/assets/1a7664e6-aa89-461a-9377-8511b95a84af" />

Copy the token from the page after you create it, and paste it into the app. Multiple people can use the same token.

### Sharing with friends

After you paste your token and save your settings, you'll get an ID. Send that ID to friends to share location with them. Do not send your access token to friends.
