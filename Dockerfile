# Pull official base image from DockerHub
FROM alpine:3.17

# Requirements:
# bash for our entrypoint script
# openssh-client for sftp
# lftp obviously
RUN apk --no-cache add bash openssh-client lftp

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY entrypoint.sh "/entrypoint.sh"

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/entrypoint.sh"]
