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
Clone and set up the Janus WebRTC Gateway. You only need the video room plugin. Follow their documentation for detailed instructions and options. Here is what I did on Fedora:

Download required packages:
```bash
sudo dnf -y install libmicrohttpd-devel jansson-devel libnice-devel \
   openssl-devel libsrtp-devel sofia-sip-devel glib-devel \
   opus-devel libogg-devel pkgconfig gengetopt libtool autoconf automake

git clone https://github.com/sctplab/usrsctp
cd usrsctp
./bootstrap
./configure --prefix=/usr && make && sudo make install
cd ..
```

Download and compile Janus
```bash
git clone git@github.com:meetecho/janus-gateway.git
cd janus-gateway
sh autogen.sh
./configure --prefix=/opt/janus --disable-websockets --disable-rabbitmq
make
sudo make install
sudo make configs
```

Configure Janus for https -- edit `/opt/janus/etc/janus/janus.transport.http.cfg`:
* Under [general] set `http` to `no`
* Set `https` to yes
* Change the `secure_port` to `8089`
* Under [certificates] set your public and private keys

Configure Janus videoroom plugin -- edit `/opt/janus/etc/janus/janus.plugin.videoroom.cfg`
* Set `max_publishers` to some large number--this controls how many people can be in tawk at once

Run the Janus gateway (you might want to do this in `screen`):
```bash
sudo /opt/janus/bin/janus --interface=45.33.55.128 --cert-pem=/path/to/public.certificate --cert-key=/path/to/private.key --stun-server=stun.l.google.com:19302
```

In the same directory that you cloned janus-gateway, clone tawk.space and install dependencies
```bash
git@github.com:invisible-college/tawk.space.git
cd tawk.space
npm install
```

You must set up certs for https in a folder called `certs/` in the tawk.space repo. This will be used by both tawk.space and statebus. Put the public key in `certs/certificate` and private key in `certs/private-key`.

Note: If you want the tawk.space logo, download it at https://tawk.space/favicon.ico and put it in the tawk.space folder as `favicon.ico`. This avoids having to put images in the repository.

Finally, run it! Again, you might want to use `screen`.

```bash
sudo node index
```

Your tawk instance is running at https://your-domain

## Contributing
PR's and issues are very welcome!
