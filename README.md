# tawk.space
Simple, flexible video chats

Website: https://tawk.space/

## The concept

Tawk is built around the idea of a **salon**. No, not those places you get haircuts, but 18th century French Enlightenment salons. Aristocratic men and women gathered to discuss politics, art, literature, and more during this "age of conversation".

Now, in the 21st century, the internet can bring us to a new "digital age of conversation". While text chats are often plagued with anonymous *trolling*, forcing users to face their peers produces deeper, more satisfying conversations.

Tawk is meant to be simple and flexible to use.
* There is **no login**--simply share a link to your space (https://tawk.space/your-space).
* Each space can have **multiple chat groups**. Drag your video to create one or mouseover another group to hear what they're saying. This is an excellent way to create "breakout" groups.

## Obligatory thanks
Tawk is mainly powered by two libraries:

* Statebus: https://github.com/invisible-college/statebus
* Janus WebRTC Gateway: https://github.com/meetecho/janus-gateway

## Set up your own tawk instance
Clone and set up the Janus WebRTC Gateway. You only need the video room plugin. Follow their documentation for detailed instructions and options. Here is what I use:
```bash
git clone git@github.com:meetecho/janus-gateway.git
cd janus-gateway
./configure --prefix=/opt/janus --disable-websockets --disable-rabbitmq
make
sudo make install
```

Follow the Janus documentation on setting up the https server (the default is http). At a minimum you will need to edit `/opt/janus/etc/janus/janus.transport.http.cfg`.

In the same directory that you cloned janus-gateway, clone tawk.space and install dependencies
```bash
git@github.com:invisible-college/tawk.space.git
cd tawk.space
npm install
```

You must set up certs for https in a folder called `certs/` in the tawk.space repo. This will be used by both tawk.space and statebus. Put the public key in `certs/certificate` and private key in `certs/private-key`.

Note: If you want the tawk.space logo, download it at https://tawk.space/favicon.ico and put it in the tawk.space folder as `favicon.ico`. This avoids having to put images in the repository.

Finally, run it!

```bash
sudo node index
```

Your tawk instance is running at https://your-domain

## Contributing
PR's and issues are very welcome!
