FROM node:20-alpine

# bash: the scripts under bin/ and lib/ require it (arrays, [[ ]], etc.)
# jq: state.sh / claude_invoke.sh JSON handling
# util-linux: flock, used by common.sh's run lock
# coreutils, findutils: GNU sha256sum/timeout/date and find -print0/xargs -0r
#   (busybox's built-ins are close enough to bite you only occasionally —
#   install the real things instead)
RUN apk add --no-cache bash jq util-linux coreutils findutils tzdata ca-certificates

RUN npm install -g @anthropic-ai/claude-code

WORKDIR /app
COPY . .
RUN chmod +x bin/*.sh lib/*.sh test/*.sh docker/entrypoint.sh \
	&& mkdir -p /etc/crontabs

ENTRYPOINT ["docker/entrypoint.sh"]
