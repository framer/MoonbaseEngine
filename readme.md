This is the Framer website. We love pull requests, from typos to docs to random ideas.

To run it you will need Cactus at http://cactusformac.com

#### Hosting

This website is ran on a small vps at digital ocean. The basic setup is an nginx install with virtual domains at public.framerjs.com. So the real website endpoint for this site is framerjs.com.public.framerjs.com. The site is cached through cloudflare for performance and uptime reasons.

#### Deploying

- First type “make bootstrap” in the Terminal to start the set-up
- Commit all your changes and make sure you are on the master branch
- Open a terminal window and type `make upload`
- [Purge the cache](https://www.cloudflare.com/a/caching/framerjs.com) at cloudflare, or if you are planning on more changes, enable development mode