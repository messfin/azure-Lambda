
default: test-serverless

HOST_HOME := $(or $(USERPROFILE),$(HOME))
HOST_HOME_POSIX := $(subst \,/,$(HOST_HOME))
HOST_AWS_DIR := $(HOST_HOME_POSIX)/.aws

deploy:
	@serverless deploy --verbose

AWS_PROFILE ?= default

test-serverless:
	@docker run -t --rm \
		-v $(CURDIR):/app \
		-v $(HOST_AWS_DIR):/root/.aws:ro \
		-w /app/serverless-runner \
		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_PROFILE=$(AWS_PROFILE) \
		-e AWS_SDK_LOAD_CONFIG=1 \
		node:16-alpine3.16@sha256:2c405ed42fc0fd6aacbe5730042640450e5ec030bada7617beac88f742b6997b \
		sh -c "npm ci && npm start"
