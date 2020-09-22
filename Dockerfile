FROM phusion/baseimage:18.04-1.0.0

RUN apt update
RUN apt install -yy gnupg1 apt-transport-https dirmngr ruby

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 379CE192D401AB61
RUN echo "deb https://ookla.bintray.com/debian $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/speedtest.list
RUN apt update
RUN apt install -yy speedtest

WORKDIR /src
COPY ./Gemfile .

RUN gem install bundler:2.1.4
RUN bundle install --path=vendor

COPY ./speedtest.rb .

CMD ["bundle", "exec", "ruby", "speedtest.rb"]
