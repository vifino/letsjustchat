#############################
# Lets just chat Dockerfile #
#############################

FROM carbonsrv/carbon

MAINTAINER Adrian "vifino" Pistol

# Make /pwd a volume, so you can bind it
VOLUME ["/pwd"]
WORKDIR /pwd

# Put the source in that directory.
COPY . /letsjustchat

# Run cobalt
ENTRYPOINT ["/usr/bin/carbon", "-root=/letsjustchat", "-config=/letsjustchat/letsjustchat.conf", "/letsjustchat/letsjustchat.lua"]
CMD ["settings.lua"]
