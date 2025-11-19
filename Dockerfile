FROM debian:latest

ENV DEBIAN_FRONTEND="noninteractive" TZ="Europe/Paris" 

RUN apt-get update -qq && \
    apt-get install -qy x11vnc xvfb xterm openbox locales auto-multiple-choice

RUN sed -i -e 's/# \(fr_FR\.UTF-8 .*\)/\1/' /etc/locale.gen && \
sed -i -e 's/# \(en_US\.UTF-8 .*\)/\1/' /etc/locale.gen && \
locale-gen && \
echo "export LC_ALL=fr_FR.UTF-8 LANG=fr_FR.UTF-8 LANGUAGE=fr_FR.UTF-8" >> ~/.bashrc

ENV LC_ALL="fr_FR.UTF-8" LANG="fr_FR.UTF-8" LANGUAGE="fr_FR.UTF-8" 

EXPOSE 5900

CMD x11vnc -passwd monpasswordsecret -create -bg -reopen -forever -env FD_PROG='/usr/bin/openbox' -afteraccept 'uxterm -hold -e auto-multiple-choice & uxterm &' && tail -f /dev/null