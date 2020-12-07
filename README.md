# tawk.space
Social video chats

Website: https://tawk.space/

## The concept

Tawk is built around the idea of a **salon**. No, not those places you get haircuts, but 18th century French Enlightenment salons. Aristocratic men and women gathered to discuss politics, art, literature, and more during this "age of conversation".

Now, in the 21st century, the internet can bring us to a new "digital age of conversation". While text chats are often plagued with anonymous *trolling*, forcing users to face their peers produces deeper, more satisfying conversations.

Tawk is meant to be simple and flexible to use.
* There is **no login**--simply share a link to your space (https://tawk.space/your-space).
* Each space can have **multiple chat groups**. Drag your video to create one or mouseover another group to hear what they're saying. This is an excellent way to create "breakout" groups.

## Obligatory thanks
Tawk was made possible through several helpful projects:

* [Statebus](https://github.com/invisible-college/statebus), a realtime database
* [Agora.io](https://agora.io), the video backend
* [DesignEvo free logo designer](https://www.designevo.com/logo-maker/)

## Embed in your website

Insert this code into your html somewhere:

```html
<script src="https://download.agora.io/sdk/web/AgoraRTC_N-4.1.0.js"></script>
<script src='https://tawk.space/hark.js'></script>
<script src="https://invisible-college.github.io/diffsync/diffsync.js"></script>
<script src="https://tawk.space/client/shared.coffee"></script>
<script src="https://tawk.space/client/tawk.coffee"></script>
```

And if you aren't using statebus already, include this too:
```html
<script src="https://stateb.us/client6.js"></script>
```

Now you can place a TAWK widget anywhere on a [statebus page](https://wiki.invisible.college/statebus) like this:
```javascript
TAWK({name: 'username', space: '/', height: 500, width: 500})
```

## Set up your own tawk instance

Clone tawk.space and install dependencies:

```bash
git@github.com:invisible-college/tawk.space.git
cd tawk.space
npm install
```

You must set up certs for https in a folder called `certs/` in the tawk.space repo. This will be used by both tawk.space and statebus. Put the public key in `certs/certificate` and private key in `certs/private-key`.

```
sudo ln -s /etc/letsencrypt/live/<your-domain>/fullchain.pem certs/certificate
sudo ln -s /etc/letsencrypt/live/<your-domain>/privkey.pem certs/private-key
```

Finally, run it! Again, you might want to use `screen`.

```bash
sudo node index
```

Your tawk instance is running at https://your-domain

## Contributing
PR's and issues are very welcome!
