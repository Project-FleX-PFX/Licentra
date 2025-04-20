FROM ruby:3.4.2-alpine

WORKDIR /app

RUN apk add --no-cache build-base postgresql-dev sqlite-dev netcat-openbsd

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

RUN chmod +x /app/entrypoint.sh

EXPOSE 4567

ENTRYPOINT ["/app/entrypoint.sh"]
